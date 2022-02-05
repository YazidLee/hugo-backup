---
title: "Spring 循环依赖"
slug: "spring-circular-dependency"
summary: "Spring 中解决循环依赖问题的源码剖析。"
author: ["SadBird"]
date: 2022-01-27T16:50:18+08:00
cover:
    image: "https://spring.io/images/spring-logo-9146a4d3298760c2e7e49595184e1975.svg"
    alt: "Spring 循环依赖"
categories: [Java, Spring]
tags: [Java, Spring, 循环依赖]
katex: false
mermaid: false
---

## 什么是循环依赖

国际惯例，还是直接先上一段官方的原文描述：

{{< admonition type=quote title="Circular dependencies" open=true >}}

If you use predominantly constructor injection, it is possible to create an unresolvable circular dependency scenario.

For example: Class A requires an instance of class B through constructor injection, and class B requires an instance of class A through constructor injection. If you configure beans for classes A and B to be injected into each other, the Spring IoC container detects this circular reference at runtime, and throws a BeanCurrentlyInCreationException.

One possible solution is to edit the source code of some classes to be configured by setters rather than constructors. Alternatively, avoid constructor injection and use setter injection only. In other words, although it is not recommended, you can configure circular dependencies with setter injection.

Unlike the typical case (with no circular dependencies), a circular dependency between bean A and bean B forces one of the beans to be injected into the other prior to being fully initialized itself (a classic chicken-and-egg scenario).

{{< /admonition >}}

Spring 中如果使用构造器的方式进行注入，那么有可能出现无法解决的循环依赖问题，举例来说：A 类中使用构造器的方式注入 B，B 类同样使用构造器方式注入 A，那么当 Spring IoC 容器检测到这种循环相互引用关系时，就会抛出运行时异常 `BeanCurrentlyInCreationException`。

![](https://s2.loli.net/2022/01/27/BfkyoIDxXdYth49.png)

解决方式也比较简单，使用 setter 方式替代构造器方式进行依赖注入。这种方式区别于构造器注入，A 和 B 之间的循环依赖迫使 A、B 之中的某一个对象在被「完全初始化之前」（已经完成「实例化」，内存中存在已经存在该对象及其引用）被注入到另一个对象中，从而不会由于这种特殊关系导致运行时异常。这里的描述可能有点绕，什么叫「完全初始化之前」，什么又是「实例化」，接下来将用一个简单的示例进行解释。

![](https://s2.loli.net/2022/01/27/PgahynDtbUiOZX4.png)

---

## 简单示例及源码剖析

### 构造器注入方式

示例包结构如下：

```shell
circular
├─A.java 
├─B.java 
└─CircularReferenceDemo.java 
```
A 和 B 代码如下：

```java
@Component
public class A {
    public A(B b) {}
}


@Component
public class B {
    public B(A a) {}
}

```
主程序 `CircularReferenceDemo` 代码如下：

```java {hl_lines=[11]}
@ComponentScan
public class CircularReferenceDemo {
    public static void main(String[] args) {
        // 注解方式进行测试，需要使用 AnnotationConfigApplicationContext
        AnnotationConfigApplicationContext context = new AnnotationConfigApplicationContext();

        // 注册当前 CircularReferenceDemo，以触发 @ComponentScan 扫描当前包下的 A 类和 B 类
        context.register(CircularReferenceDemo.class);

        // 启动容器
        context.refresh();

        // 获取 bean 实例
        A a = context.getBean(A.class);
        B b = context.getBean(B.class);
    }
}
```
运行程序后，代码高亮部分抛出异常如下：

{{< admonition type=bug title="循环依赖异常" open=true >}}

Caused by: org.springframework.beans.factory.UnsatisfiedDependencyException: Error creating bean with name 'b' defined in file [B.class]: Unsatisfied dependency expressed through constructor parameter 0; nested exception is org.springframework.beans.factory.BeanCurrentlyInCreationException: Error creating bean with name 'a': Requested bean is currently in creation: Is there an unresolvable circular reference?

{{< /admonition >}}

英语不好的同学直接看最后一句话，`Is there an unresolvable circular reference?`，Spring 提示您：是否存在未解决的循环依赖？Of course！

那么，接下来就要进入源码进行分析了。

还是再来一段 Spring 官方文档的描述：

{{< admonition type=quote title="正常 setter 依赖注入的过程" open=true >}}

If no circular dependencies exist, when one or more collaborating beans are being injected into a dependent bean, each collaborating bean is totally configured prior to being injected into the dependent bean. This means that, if bean A has a dependency on bean B, the Spring IoC container completely configures bean B prior to invoking the setter method on bean A. In other words, the bean is instantiated (if it is not a pre-instantiated singleton), its dependencies are set, and the relevant lifecycle methods (such as a configured init method or the InitializingBean callback method) are invoked.

{{< /admonition >}}

可以看到，在 setter 依赖且无循环依赖的情况下，如果 A 依赖于 B，那么 Spring 容器默认会率先完成 B 的所有创建和初始化过程，随后再进行 A 中 setter 方法的调用。同理，使用构造器进行依赖注入时，也会先触发 B 的创建和初始化，再将已经完成所有过程的 B 对象注入到 A 中，完成 A 的创建工作。

因此，这里将循环依赖分为三个过程：

1. A 对象开始获取 `getBean(A)`，容器标记 A 对象正在创建中，准备构造器，发现构造器中有对于 B 的依赖，于是转向 B 的获取。
2. B 对象开始获取 `getBean(B)`，容器标记 B 对象正在创建中，准备构造器，发现构造器中有对于 A 的依赖，于是又准备开始 A 的获取。
3. 再次进行 A 对象获取 `getBean(A)`，但发现 A 被标记为正在创建中，冲突，抛出异常。

下图为上述过程的整个调用栈，从下到上分别对应上面的步骤：

![](https://s2.loli.net/2022/01/27/wc76bNGPEzYieH9.png)

将上图进行简化，提取一下其中的关键步骤，绘制流程图如下：

![](https://s2.loli.net/2022/01/27/BUGgvVM9WERaqTb.png)

最后来看一下标记某对象正在创建中的代码，`getSingleton(beanName, singletonFactory)` 方法中调用了 `beforeSingletonCreation(beanName)` 方法，该方法也比较简单，直接使用 Set 进行重复 Bean 创建的判断，如下:

```java
/** Names of beans that are currently in creation. */
private final Set<String> singletonsCurrentlyInCreation =
        Collections.newSetFromMap(new ConcurrentHashMap<>(16));

    /** Names of beans currently excluded from in creation checks. */
private final Set<String> inCreationCheckExclusions =
        Collections.newSetFromMap(new ConcurrentHashMap<>(16));

// ...

/**
* Callback before singleton creation.
* <p>The default implementation register the singleton as currently in creation.
* @param beanName the name of the singleton about to be created
* @see #isSingletonCurrentlyInCreation
*/
protected void beforeSingletonCreation(String beanName) {
    if (!this.inCreationCheckExclusions.contains(beanName) && !this.singletonsCurrentlyInCreation.add(beanName)) {
        throw new BeanCurrentlyInCreationException(beanName);
    }
}
```

---

### setter 注入方式

主程序 `CircularReferenceDemo` 保持不变，将 A、B 修改如下：

```java
@Component
public class A {
    private B b;

    @Autowired
    public void setB(B b) {
        this.b = b;
    }
}

@Component
public class B {
    private A a;

    @Autowired
    public void setA(A a) {
        this.a = a;
    }
}
```

发现可以正常通过运行而没有异常，说明循环依赖得到了解决，下面结合源码进行分析。

复习一下上面提到过的一个基本思路：在 setter 依赖且无循环依赖的情况下，如果 A 依赖于 B，那么 Spring 容器默认会率先完成 B 的所有创建和初始化过程，随后再进行 A 中 setter 方法的调用。

因此，先仿照构造器注入的方式给出一个猜测性的粗略流程：

1. A 对象开始获取 `getBean(A)`，容器标记 A 对象正在创建中，使用默认构造器创建 A 对象（半成品 A'），创建完成后开始填充属性（setter 方法），发现有 B 的依赖，转向 B 的获取。
2. B 对象开始获取 `getBean(B)`，容器标记 B 对象正在创建中，使用默认构造器创建 B 对象（半成品 B'），创建完成后开始填充属性（setter 方法），发现有 A 的依赖，转向 A 的获取。
3. 再次进行 A 对象获取 `getBean(A)`，**在某个缓存中发现了 A 的半成品实例 A'（注意这里的 A' 与最终要返回的 A 在不考虑代理的情况下是同一个对象，只是它当前处于一种中间的临时状态，还没有完成 B 属性填充，且其自身初始化方法还未调用），直接使用这个半成品 A' 完成 B 的属性填充，最终完成 A 的属性填充**。

![](https://s2.loli.net/2022/01/28/bRctG2NovwJCKPj.png)

关键的地方就是在 A 还未完全初始化完成时，提前「暴露」一个临时的半成品 A' 给 B 进行依赖注入。暂时不太理解也没关系，后面会详细介绍这个缓存机制。

惯例先来一段相关调用栈：

![](https://s2.loli.net/2022/01/28/VuBS8IJsvqL16dA.png)

同样可以发现分成了三个部分，其中很多方法与构造器方式一致，但它却解决了循环依赖的问题，因此需要更加细致地分析。

现在来详细地介绍一下 Spring 容器启动时，预创建非懒加载 Bean 的具体流程及 Spring 容器的几个重要缓存，涉及到的类较多（画过一个时序图，Mermaid 格式，比较完整，放到 [gist](https://gist.github.com/YazidLee/f5af97d997d7319103ee1051041acc6a) 上了）。

下图是当前示例的 A、B 对象创建过程（看不清建议右键访问原图）：

![](https://s2.loli.net/2022/01/28/bKtIhXqUzr2LcPn.png)

其中，A 和 B 对象的创建流程基本一致，思路都是先尝试从缓存中获取，若缓存中不存在，则进行创建。创建的核心步骤在 `doCreateBean` 方法中，主要包括四个过程：

- 创建对象实例 `createBeanInstance`：工厂方法、实例工厂方法、`Supplier` 或构造器等，本例中为默认构造器。这个方法调用之后，其实内存中已经创建好了一个 Bean 的实例对象，只不过是半成品，还没有调用 `populateBean` 完成属性填充，也未调用 `initializeBean` 完成初始化工作，这个状态的对象就是前文提到的「实例化」完成，但未进行初始化。
- 提前暴露半成品 `addSingletonFactory`：将上个步骤的半成品通过特殊包装放入缓存中，以解决循环依赖问题。
- 填充属性 `populateBean`：主要完成完成属性的填充、 `@Autowired` 的注入工作，从上一个调用栈图能看出调用的是 `AutowiredAnnotationBeanPostProcessor` 中的 `postProcessProperties` 方法完成注入。提前暴露方法 `addSingletonFactory` 在本方法之前调用也正是因为在 `populate` 过程中会触发依赖对象的获取过程，要在该过程前把当前的半成品放入缓存中。完成这个步骤的对象暂且称之为「属性填充完成」，但依然还未进行初始化。
- 自定义初始化 `initializeBean`：包括了 `Aware` 接口处理、`BeanPostPostProcessor` 的 before 和 after 逻辑、`@PostConstruct` 注解处理、`init-method` 处理、`InitializingBean` 处理等，注意在创建 A 的过程中，这个方法由于 `populate` 触发了依赖处理，因此将在 B 创建完成后才会被调用。这个方法执行完成后，我们才能把最终返回的对象称为「完全初始化」的对象，也就是所谓的成品。

Spring 容器中的缓存位于 `DefaultSingletonBeanRegistry` 类中，具体定义如下：

```java
/** Cache of singleton objects: bean name to bean instance. */
private final Map<String, Object> singletonObjects = new ConcurrentHashMap<>(256);

/** Cache of singleton factories: bean name to ObjectFactory. */
private final Map<String, ObjectFactory<?>> singletonFactories = new HashMap<>(16);

/** Cache of early singleton objects: bean name to bean instance. */
private final Map<String, Object> earlySingletonObjects = new ConcurrentHashMap<>(16);
```

从名称及注释中能够获知它们分别的作用：

- `singletonObjects`：保存已经完成所有创建过程（包括所有初始化过程）的单例 Bean，即所有的成品 Bean 都会被放到这个缓存中。
- `singletonFactories`：保存创建所有单例 Bean 的 `ObjectFactory` 对象，与代理有关，后续会详细介绍。
- `earlySingletonObjects`：保存实例化完成，但未进行 `populate` 和 `initializeBean` 的半成品 Bean。

再回到创建流程图，橙色编号部分为缓存相关的方法，下面按编号顺序进行解析。

1. A 对象获取过程的第一个 `getSingleton` 方法源码如下：
   ```java
   protected Object getSingleton(String beanName, boolean allowEarlyReference) {
        // Quick check for existing instance without full singleton lock
        Object singletonObject = this.singletonObjects.get(beanName);
        if (singletonObject == null && isSingletonCurrentlyInCreation(beanName)) {
            singletonObject = this.earlySingletonObjects.get(beanName);
            if (singletonObject == null && allowEarlyReference) {
                synchronized (this.singletonObjects) {
                    // Consistent creation of early reference within full singleton lock
                    singletonObject = this.singletonObjects.get(beanName);
                    if (singletonObject == null) {
                        singletonObject = this.earlySingletonObjects.get(beanName);
                        if (singletonObject == null) {
                            ObjectFactory<?> singletonFactory = this.singletonFactories.get(beanName);
                            if (singletonFactory != null) {
                                singletonObject = singletonFactory.getObject();
                                this.earlySingletonObjects.put(beanName, singletonObject);
                                this.singletonFactories.remove(beanName);
                            }
                        }
                    }
                }
            }
        }
        return singletonObject;
    }
   ```
   首先从 `singletonObjects` 缓存中获取，没有获取到，且此时的 `isSingletonCurrentlyInCreation` 方法返回为 `false`（还没有对 A 进行标记），会直接返回 `null`。
   
   假定 `isSingletonCurrentlyInCreation` 为 `true`，再从 `earlySingletonObjects` 中尝试获取，若仍为空且 `allowEarlyReference` 为 `true`（默认值），则加锁以保证后续操作的强一致性。对单例设计模式有了解的朋友这里肯定很熟悉，类似于 [DCL](https://en.wikipedia.org/wiki/Double-checked_locking) 的操作。最后，尝试从 `singletonFactories` 中获取对象，因为我们这里是第一次进入，因此所有缓存都为空，最终返回 `null`。

2. 缓存中不存在任何 A 对象，因此进入编号为 2 的方法 `getSingleton()`（注意区别上面那个 `getSingleton` 方法），这个方法有两个参数，第一个参数为 `beanName`，第二个参数为 `ObjectFactory`，Spring 源码中给出的调用参数如下：
   ```java
   sharedInstance = getSingleton(beanName, () -> {
        try {
            return createBean(beanName, mbd, args);
        }
        catch (BeansException ex) {
            // Explicitly remove instance from singleton cache: It might have been put there
            // eagerly by the creation process, to allow for circular reference resolution.
            // Also remove any beans that received a temporary reference to the bean.
            destroySingleton(beanName);
            throw ex;
        }
    });
   ```
   第二个参数使用了 lambda 表达式，类型推断为 `ObjectFactory`，因此，在 `getSingleton` 这个方法中一定会调用 `ObjectFactory` 的 `getObject` 方法，如下：

   ```java {hl_lines=[14, 21, 44, 47]}
   public Object getSingleton(String beanName, ObjectFactory<?> singletonFactory) {
        Assert.notNull(beanName, "Bean name must not be null");
        synchronized (this.singletonObjects) {
            Object singletonObject = this.singletonObjects.get(beanName);
            if (singletonObject == null) {
                if (this.singletonsCurrentlyInDestruction) {
                    throw new BeanCreationNotAllowedException(beanName,
                            "Singleton bean creation not allowed while singletons of this factory are in destruction " +
                            "(Do not request a bean from a BeanFactory in a destroy method implementation!)");
                }
                if (logger.isDebugEnabled()) {
                    logger.debug("Creating shared instance of singleton bean '" + beanName + "'");
                }
                beforeSingletonCreation(beanName);
                boolean newSingleton = false;
                boolean recordSuppressedExceptions = (this.suppressedExceptions == null);
                if (recordSuppressedExceptions) {
                    this.suppressedExceptions = new LinkedHashSet<>();
                }
                try {
                    singletonObject = singletonFactory.getObject();
                    newSingleton = true;
                }
                catch (IllegalStateException ex) {
                    // Has the singleton object implicitly appeared in the meantime ->
                    // if yes, proceed with it since the exception indicates that state.
                    singletonObject = this.singletonObjects.get(beanName);
                    if (singletonObject == null) {
                        throw ex;
                    }
                }
                catch (BeanCreationException ex) {
                    if (recordSuppressedExceptions) {
                        for (Exception suppressedException : this.suppressedExceptions) {
                            ex.addRelatedCause(suppressedException);
                        }
                    }
                    throw ex;
                }
                finally {
                    if (recordSuppressedExceptions) {
                        this.suppressedExceptions = null;
                    }
                    afterSingletonCreation(beanName);
                }
                if (newSingleton) {
                    addSingleton(beanName, singletonObject);
                }
            }
            return singletonObject;
        }
    }
   ```
   重点关注高亮几行：

   - `beforeSingletonCreation` 在构造器方式中以及介绍过了，通过 Set 对正在创建的 Bean 进行标记。
   - `singletonObject = singletonFactory.getObject();` 果然调用了 `ObjectFactory` 的 `getObject` 方法，因此会进入 `createBean` 方法，稍后介绍。
   - `afterSingletonCreation` 方法作用与 `beforeSingletonCreation` 类似，在上一步 `createBean` 创建完成后，将正在创建的标记清除。
   - `addSingleton` 这个方法是一个重要方法，它将创建完成的 Bean 放入 `singletonObjects` 缓存中，并从 `earlySingletonObjects` 和 `singletonFactories` 中移除相应的同名临时对象。稍后在 8、9 中会详细介绍。

3. 到目前为止，缓存中的仍然没有任何对象。进入到 `addSingletonFactory` 之前，在 `doCreateBean` 中会先调用在构造器方式中介绍过的 `createBeanInstance` 方法，该方法会选择适当的方式（本例中是默认构造器）将目标对象进行实例化（具体定位到 `SimpleInstantiationStrategy` 中的 `instantiate` 方法，再调用`BeanUtils.instantiateClass(constructorToUse)`，继续跟进，会找到 `ctor.newInstance(argsWithDefaultValues)`，即反射方式创建实例）。
   
    此时，本例中的 A 对象已经创建，但没有进行属性填充、初始化，是半成品对象，接下来就将这个半成品对象通过下面代码放入缓存中：

    ```java {hl_lines=[10]}
    // Eagerly cache singletons to be able to resolve circular references
    // even when triggered by lifecycle interfaces like BeanFactoryAware.
    boolean earlySingletonExposure = (mbd.isSingleton() && this.allowCircularReferences &&
            isSingletonCurrentlyInCreation(beanName));
    if (earlySingletonExposure) {
        if (logger.isTraceEnabled()) {
            logger.trace("Eagerly caching bean '" + beanName +
                    "' to allow for resolving potential circular references");
        }
        addSingletonFactory(beanName, () -> getEarlyBeanReference(beanName, mbd, bean));
    }
    ```

    `addSingletonFactory` 方法第二个参数同样为 `ObjectFactory`，具体内容也比较简单：

    ```java
    protected void addSingletonFactory(String beanName, ObjectFactory<?> singletonFactory) {
        Assert.notNull(singletonFactory, "Singleton factory must not be null");
        synchronized (this.singletonObjects) {
            if (!this.singletonObjects.containsKey(beanName)) {
                this.singletonFactories.put(beanName, singletonFactory);
                this.earlySingletonObjects.remove(beanName);
                this.registeredSingletons.add(beanName);
            }
        }
    }
    ```

    几个简单的操作相信都能看懂，该方法执行完成后，`singletonFactories` 缓存中出现了数据，三个 Map 的状态如下：

    ![](https://s2.loli.net/2022/01/28/3xzXa7W48QYBlcM.png)

    A 对象暂时还没创建完成，接下来进入 `populateBean` 方法进行属性填充，该方法会触发 B 对象的获取，因此，会再次进入 `getSingleton` 方法以获取 B。

4. 此次进入 `getSingleton` 目的是获取 B 对象，由于 B 对象在 `singletonObjects` 中不存在，且 `isSingletonCurrentlyInCreation` 返回为 `false`，因此直接返回 `null`。
5. 参考 2 过程。
6. 参考 3 过程，完成后，此时三个 Map 的状态更新为：

   ![](https://s2.loli.net/2022/01/28/wN5fJIR4Y2FkLot.png)

   同样,这里由于 B 的 `@Autowired` 依赖了 A，因此，会进入 `getSingleton` 再次获取 A。
7. 注意，本次的 `getSingleton` 方法调用将与第一次有所不同，此时，虽然 `singletonObjects` 仍然没有对象，但 `isSingletonCurrentlyInCreation` 的返回值为 `true`。因此会进入到加锁块中：
   
   ```java {hl_lines=[3]}
    ObjectFactory<?> singletonFactory = this.singletonFactories.get(beanName);
    if (singletonFactory != null) {
        singletonObject = singletonFactory.getObject();
        this.earlySingletonObjects.put(beanName, singletonObject);
        this.singletonFactories.remove(beanName);
    }
   ```

   表面意思也比较简单，调用 `singletonFactories` 中 a 对应的 `ObjectFactory` 的 `getObject` 方法，获取半成品对象，并将该对象放入到 `earlySingletonObjects` 中，最后将该 `ObjectFactory` 从 `singletonFactories` 中移除。此时，三个 Map 的状态为：

   ![](https://s2.loli.net/2022/01/28/KBfoG5lrnwOPZsg.png)

   还需要关注这里高亮行的代码，还记得这里的 `singletonFactory` 是什么东西吗？在 3 过程中，`addSingletonFactory(beanName, () -> getEarlyBeanReference(beanName, mbd, bean));` 将 lambda 表达式存入了 `singletonFactories`，因此这里调用的 `getObject` 实际上就是调用 ` getEarlyBeanReference(beanName, mbd, bean))`，它的代码如下：

   ```java
   protected Object getEarlyBeanReference(String beanName, RootBeanDefinition mbd, Object bean) {
        Object exposedObject = bean;
        if (!mbd.isSynthetic() && hasInstantiationAwareBeanPostProcessors()) {
            for (SmartInstantiationAwareBeanPostProcessor bp : getBeanPostProcessorCache().smartInstantiationAware) {
                exposedObject = bp.getEarlyBeanReference(exposedObject, beanName);
            }
        }
        return exposedObject;
    }
   ```
   
   这里的过程是要调用 `SmartInstantiationAwareBeanPostProcessor` 中的 `getEarlyBeanReference` 方法，将原始的半成品实例进行包装，典型的应用就是在这里给 AOP 提供一个包装的机会，试想如果我们示例中的 A 对象需要被代理，那么在这里就会给 A 对象的半成品 A' 进行包装，让等待依赖注入的 B 最终能够得到的是 AOP 包装后的 A，而不是原始的 A 对象。但本例中的 A 不需要代理，因此直接返回 A' 对象即可。

   既然已经有了一个 A' 对象，那么就满足了 B 的需求，随后返回到 B 的 `populateBean` 方法，直接将 A' 注入到 B 对象中，完成 B 的属性填充，并调用 `initializeBean` 对 B 进行初始化。

8. 这时 B 对象已经走完了整个创建的过程，是一个成品对象，要将它放入到成品缓存 `singletonObjects` 中。代码将返回到 5 过程，具体代码位置参考 2 过程中的 `getSingleton` 第 21 行高亮处。接下来将要调用 `afterSingletonCreation` 完成清理工作，将 B 对象的正在创建状态移除。但更重要的是 `addSingleton(beanName, singletonObject)` 方法：

   ```java
   protected void addSingleton(String beanName, Object singletonObject) {
        synchronized (this.singletonObjects) {
            this.singletonObjects.put(beanName, singletonObject);
            this.singletonFactories.remove(beanName);
            this.earlySingletonObjects.remove(beanName);
            this.registeredSingletons.add(beanName);
        }
    }
   ```

   它将创建完成的 B 对象放入 `singletonObjects` 中，并从 `singletonFactories` 和 `earlySingletonObjects` 中移除同名的临时对象。至此，B 对象创建完成。

   ![](https://s2.loli.net/2022/01/28/uiMEAZF2CcV7ze1.png)

   同样道理，既然 B 已经完成了创建，就会返回到 A 的 `populateBean` 方法，将 B 属性注入 A，并调用 `initializeBean` 对 A 进行初始化。

9. 同过程 8，此时要将完成创建工作的 A 对象放入 `singletonObjects`。至此，A 对象也创建完成，循环依赖得到了解决。

   ![](https://s2.loli.net/2022/01/28/YMyO8r416T9XAsC.png)

---

## AOP 和循环依赖

AOP 是 Spring 的核心功能之一，而 Spring 中的 AOP 实现手段主要是「动态代理」，无论是 JDK 亦或是 CGLIB，都是针对**方法**层面进行增强。本节将首先介绍 AOP 的核心概念及部分 API，然后再对 AOP 代理对象间的循环依赖进行分析。

### AOP 介绍

简单来说，Spring 中的 AOP 就是向外提供一个「代理对象」，该对象中封装了所有适配的拦截器和原始对象的目标方法，成为一个调用链，在调用代理对象的方法时处理调用链中的所有逻辑（包括目标方法本身），以达到动态增强的效果，顺带一提，Spring 中「代理对象」主要有两种实现：`JdkDynamicAopProxy` 和 `CglibAopProxy`，它们的 `getProxy` 方法可以返回我们所需的「代理对象」，感兴趣的可以大致浏览下源码，核心部分都是拦截器链的封装和调用。

这里普及一下 AOP 中一些 API，涉及了部分源码。实际工作中，我们通常都是使用 `@Aspect` 注解的方式来声明切面类（包含 `@Pointcut` 切点描述及 `@Before`、`@After` 等通知），但实际上 Spring 提供了一套清晰可用的编程接口，可以灵活地进行定制实现。下面先介绍一些基本的接口：

- `JoinPoint`：AOP 中的**连接点**，在 Spring 只支持方法层面的增强，这点从它的唯一子接口 `MethodInvacation` 中也可以看出，因此直接理解为方法即可。
- `Pointcut`：AOP 中的**切点**，作用是从所有的**连接点**中进行筛选操作，它不具备任何的具体业务逻辑，仅仅是选出我们所需要增强的方法。
- `Advice`：AOP 中的**通知**，它是具体增强业务的实现，Spring 中支持 `before`、`after`、`afterReturning`、`afterThrows` 和 `around` 这几个类型的通知，它协同 `Pointcut` 在特定的方法上在特定「位置」实现增强操作。
- `Advisor`：Spring 中的一个中间接口，主要使用其子接口 `PointcutAdivsor`，它将 `Pointcut` 和 `Advice` 进行组合，放在一个 `Advisor` 类中，方便使用。
- `MethodInterceptor`：字面意思是**方法拦截器**，它是 `Advice` 的子接口，Spirng 中的 `Around` 通知就是使用它来实现的，且所有的其他通知都会交由相应适配器处理，最终都转换为 `MethodInterceptor` 放入「代理对象」的拦截器链中。
- `ProxyFactory`：创建「代理对象」的工厂类，它是 `AdvisedSupport` 的子类，提供了一系列配置的方法，内部使用 `DefaultAopProxyFactory` 创建具体的「代理对象」，`DefaultAopProxyFactory` 核心代码如下：
  
  ```java {hl_lines=[12, 15]}
  @Override
  public AopProxy createAopProxy(AdvisedSupport config) throws AopConfigException {
      if (!NativeDetector.inNativeImage() &&
              (config.isOptimize() || config.isProxyTargetClass() || hasNoUserSuppliedProxyInterfaces(config))) {
          Class<?> targetClass = config.getTargetClass();
          if (targetClass == null) {
              throw new AopConfigException("TargetSource cannot determine target class: " +
                      "Either an interface or a target is required for proxy creation.");
          }
          if (targetClass.isInterface() || Proxy.isProxyClass(targetClass)) {
              // JDK 动态代理
              return new JdkDynamicAopProxy(config);
          }
          // CGLIB 动态代理，ObjenesisCglibAopProxy 是 CglibAopProxy 的子类
          return new ObjenesisCglibAopProxy(config);
      }
      else {
          return new JdkDynamicAopProxy(config);
      }
  }
  ```
- `AbstractAutoProxyCreator`：与 Spring IOC 结合，实现 Spring 容器 AOP 代理对象的自动创建功能，本质上它是`SmartInstantiationAwareBeanPostProcessor`，实现了以下几个重要的逻辑：
  - `postProcessBeforeInstantiation`：在 Bean 实例化前被调用，调用了 `isInfrustructureClass` 和 `shouldSkip` 来决定当前 Bean 是否应该被代理，其中 `shouldSkip` 会触发 `findEligibleAdvisors` 的逻辑，将容器中所有切面逻辑进行筛选。同时包含了处理自定义 `TargetSource` 的业务（不常用，具体可以查看官方文档，与热替换和池化技术关联较大）。
  - `getEarlyReference`：如果当前 Bean  需要被代理，则在解决循环依赖的过程中，需要提前暴露这个「代理对象」，以替换原对象，成为注入到其他 Bean 中的真正对象。核心方法 `wrapIfNecessary`。
  - `postProcessAfterInitialization`：在初始化后调用，属于 `BeanPostProcessor` 接口中的方法，同样调用了 `wrapIfNecessary` 方法，在对象创建完成且属性填充完成后进行生成代理操作。

有了上述这些基本概念后，下面是两个具体的实例，分别展示了 Spring 手动创建代理和自动创建代理：

- 手动创建
  
  目标类：
  ```java
  public class ManualA {
    public void execute() {
        System.out.println("Executing A...");
    }

    public void other() {
        System.out.println("Other method...");
    }
  }
  ```
  实现手动创建代理：
  ```java
  public class ManualProxyDemo {
    
    static class ManualMethodInterceptor implements MethodInterceptor {
        @Nullable
        @Override
        public Object invoke(@Nonnull MethodInvocation invocation) throws Throwable {
            System.out.println("---------------------");
            System.out.println("Enhancement Before...");
            Object result = invocation.proceed();
            System.out.println("Enhancement After...");
            System.out.println("---------------------");
            return result;
        }
    }

    public Advice methodInterceptor() {
        return new ManualMethodInterceptor();
    }

    public Pointcut manualPointcut() {
        return new StaticMethodMatcherPointcut() {
            @Override
            public boolean matches(Method method, Class<?> targetClass) {
                // 切点，只匹配方法名为 execute 的方法
                return "execute".equals(method.getName());
            }
        };
    }

    public Advisor manualAdvisor(Pointcut pointcut, Advice methodInterceptor) {
        return new DefaultPointcutAdvisor(pointcut, methodInterceptor);
    }

    public static void main(String[] args) {
        ManualProxyDemo config = new ManualProxyDemo();
        // Pointcut、Advice、Advisor 准备
        Pointcut pointcut = config.manualPointcut();
        Advice advice = config.methodInterceptor();
        Advisor advisor = config.manualAdvisor(pointcut, advice);

        // 目标对象
        ManualA target = new ManualA();

        // 代理工厂，设置目标对象
        ProxyFactory proxyFactory = new ProxyFactory(target);
        // 配置
        // 使用 CGLIB 动态代理
        proxyFactory.setProxyTargetClass(true);
        // 将我们准备好的 Advisor 设置到工厂中
        proxyFactory.addAdvisor(advisor);

        // 创建「代理对象」
        ManualA proxy = (ManualA) proxyFactory.getProxy();
        // 使用「代理对象」执行符合 Pointcut 的目标方法
        proxy.execute();
        // 使用「代理对象」执行其他不符合的方法
        proxy.other();
    }
  }
  ```
  手动创建代理的流程也比较简单，准备好 `Pointcut`、`Advice` 对象，并封装为 `Advisor` 添加到 `ProxyFactory`中（也可以直接添加 `Advice`，工厂会自动进行封装），`ProxyFactory` 可在构造函数中指定需要代理的目标对象，且可以设置一些通用属性（如 proxyTargetClass、exposeProxy 等）。最终调用 `getProxy` 方法获取我们所需要的「代理对象」。执行上面代码后，结果如下：符合 `Pointcut` 的方法 `execute` 得到了增强，而 `other` 方法则直接调用原始对象中的同名方法。

  ```shell
  ---------------------
  Enhancement Before...
  Executing A...
  Enhancement After...
  ---------------------
  Other method...
  ```
- 自动创建
  
  目标类中新增一个注解和内部方法调用：

  ```java {hl_lines=[1, 8]}
  @Component
  public class ManualA {
    public void execute() {
        System.out.println("Executing A...");
    }

    public void other() {
        execute();
        System.out.println("Other method...");
    }
  }
  ```

  自动创建代理，新增 `@EnableAspectJAutoProxy` 注解和 `@Bean`、`@Primary`，移除手动创建的代码，取而代之的是使用 Spring IOC 自动创建的方式：

  ```java {hl_lines=[2]}
  @ComponentScan
  @EnableAspectJAutoProxy(proxyTargetClass = true, exposeProxy = true)
  public class ManualProxyDemo {
      static class ManualMethodInterceptor implements MethodInterceptor {
          @Nullable
          @Override
          public Object invoke(@Nonnull MethodInvocation invocation) throws Throwable {
              System.out.println("---------------------");
              System.out.println("Enhancement Before...");
              Object result = invocation.proceed();
              System.out.println("Enhancement After...");
              System.out.println("---------------------");
              return result;
          }
      }

    // @Bean 注解将 MethodInterceptor 交由 Spring 管理，@Primary 防止其他 MethodInterceptor 干扰
    @Bean
    @Primary
    public Advice methodInterceptor() {
        return new ManualMethodInterceptor();
    }

    @Bean
    @Primary
    public Pointcut manualPointcut() {
        return new StaticMethodMatcherPointcut() {
            @Override
            public boolean matches(Method method, Class<?> targetClass) {
                // 切点，只匹配方法名为 execute 的方法
                return "execute".equals(method.getName());
            }
        };
    }

    @Bean
    @Primary
    public Advisor manualAdvisor(Pointcut pointcut, Advice methodInterceptor) {
        return new DefaultPointcutAdvisor(pointcut, methodInterceptor);
    }

    public static void main(String[] args) {
        // 结合 Spring 容器使用
        AnnotationConfigApplicationContext context = new AnnotationConfigApplicationContext();
        context.register(ManualProxyDemo.class);

        // 启动容器，过程中创建 Bean 实例，并完成「代理对象」的自动创建
        context.refresh();

        // 从容器中获取对象，该对象为我们需要的「代理对象」
        ManualA proxy = context.getBean(ManualA.class);
        // 打印 proxy 的类名
        System.out.println(proxy.getClass().getName());
        // 执行结果与手动创建类似
        proxy.execute();
        // 注意这个方法，它内部调用了 execute 方法
        proxy.other();
    }
  }
  ```
  
  与手动创建代理对象相比，首先需要使用 `@EnableAspectJAutoProxy` 将自动创建代理的相关类导入。具体来说，在 `@EnableAspectJAutoProxy` 类上可以找到 `@Import(AspectJAutoProxyRegistrar.class)`。进入 `AspectJAutoProxyRegistrar` 的 `registerBeanDefinitions` 方法及相关 `AopConfigUtils` 配置类，如下：

  ```java {hl_lines=[5, 11, 14, 28, 34, 41]}
  @Override
  public void registerBeanDefinitions(
          AnnotationMetadata importingClassMetadata, BeanDefinitionRegistry registry) {

      AopConfigUtils.registerAspectJAnnotationAutoProxyCreatorIfNecessary(registry);

      AnnotationAttributes enableAspectJAutoProxy =
              AnnotationConfigUtils.attributesFor(importingClassMetadata, EnableAspectJAutoProxy.class);
      if (enableAspectJAutoProxy != null) {
          if (enableAspectJAutoProxy.getBoolean("proxyTargetClass")) {
              AopConfigUtils.forceAutoProxyCreatorToUseClassProxying(registry);
          }
          if (enableAspectJAutoProxy.getBoolean("exposeProxy")) {
              AopConfigUtils.forceAutoProxyCreatorToExposeProxy(registry);
          }
      }
  }

  @Nullable
  public static BeanDefinition registerAspectJAnnotationAutoProxyCreatorIfNecessary(BeanDefinitionRegistry registry) {
      return registerAspectJAnnotationAutoProxyCreatorIfNecessary(registry, null);
  }

  @Nullable
  public static BeanDefinition registerAspectJAnnotationAutoProxyCreatorIfNecessary(
          BeanDefinitionRegistry registry, @Nullable Object source) {

      return registerOrEscalateApcAsRequired(AnnotationAwareAspectJAutoProxyCreator.class, registry, source);
  }

  public static void forceAutoProxyCreatorToUseClassProxying(BeanDefinitionRegistry registry) {
      if (registry.containsBeanDefinition(AUTO_PROXY_CREATOR_BEAN_NAME)) {
          BeanDefinition definition = registry.getBeanDefinition(AUTO_PROXY_CREATOR_BEAN_NAME);
          definition.getPropertyValues().add("proxyTargetClass", Boolean.TRUE);
      }
  }

  public static void forceAutoProxyCreatorToExposeProxy(BeanDefinitionRegistry registry) {
      if (registry.containsBeanDefinition(AUTO_PROXY_CREATOR_BEAN_NAME)) {
          BeanDefinition definition = registry.getBeanDefinition(AUTO_PROXY_CREATOR_BEAN_NAME);
          definition.getPropertyValues().add("exposeProxy", Boolean.TRUE);
      }
  }
  ```
  重点部分已用高亮标出，主要是将 `AnnotationAwareAspectJAutoProxyCreator` 类作为 `BeanDefinition` 加入到容器中，且为其配置了 `proxyTargetClass` 属性和 `exposeProxy` 属性。`proxyTargetClass` 设置为 true，表示强制使用 CGLIB 动态代理；`exposeProxy` 设置为 true，表示需要暴露 `ManualA` 的「代理对象」，可以使用 `AopContext` 获取该对象。

  自动创建的方式将 `Pointcut`、`Advice` 及 `Advisor` 交由 Spring 容器管理，容器启动后，会自动根据我们配置好的 `Advisor` 为我们将原始的 `ManualA` 对象进行增加，创建其「代理对象」，并将该代理对象放入 `singletonObjects` 缓存中。调用 `getBean` 可以从容器的 `singletonObjects` 缓存中获取出 `ManualA` 类型的 Bean，通过 `execute` 和 `other` 的执行结果我们可以发现该对象是「代理对象」而非原始的目标对象。

  ```shell 
  cn.liyangjie.spring.circular.ManualA$$EnhancerBySpringCGLIB$$d4361f08
  ---------------------
  Enhancement Before...
  Executing A...
  Enhancement After...
  ---------------------
  Executing A... in other()
  Executing A...
  Other method...
  ```

  同时需要注意到，上述 `other` 方法内部调用的 `execute` 并没有经过增强，只是简单的调用原始方法，这就是 `exposeProxy` 的作用所在了，为了让 `other` 能够调用到增强的 `execute` 方法，这点也适用于 Spring 事务中，同一个类中的 `@Transactional` 方法间的相互调用。
  
  现在将 `ManualA` 的 `other` 修改如下：

  ```java {hl_lines=[3, 4]}
  public void other() {
      System.out.println("Executing A... in other()");
      ManualA proxy = (ManualA) AopContext.currentProxy();
      proxy.execute();
      System.out.println("Other method...");
  }
  ```
  再执行得到的结果如下：`other` 中成功调用了增强后的 `execute` 方法。

  ```shell
  cn.liyangjie.spring.circular.ManualA$$EnhancerBySpringCGLIB$$d4361f08
  ---------------------
  Enhancement Before...
  Executing A...
  Enhancement After...
  ---------------------
  Executing A... in other()
  ---------------------
  Enhancement Before...
  Executing A...
  Enhancement After...
  ---------------------
  Other method...
  ```

---

### AOP 下的循环依赖

现在我们使用示例代码如下：

```java
@Component
public class ServiceA {
    private ServiceB serviceB;

    @Autowired
    public void setServiceB(ServiceB serviceB) {
        this.serviceB = serviceB;
    }

    public void service() {
        System.out.println("Executing Service A...");
    }
}
```

```java
@Component
public class ServiceB {
    private ServiceA serviceA;

    @Autowired
    public void setServiceA(ServiceA serviceA) {
        this.serviceA = serviceA;
    }

    public void service() {
        System.out.println("Executing ServiceB...");
    }
}
```

```java
@ComponentScan
// 使用 CGLIB 动态代理，并且暴露「代理对象」，可使用 AopContext 访问
@EnableAspectJAutoProxy(proxyTargetClass = true, exposeProxy = true)
public class CircularReferenceDemo {
    static class CircularInterceptor implements MethodInterceptor {
        @Nullable
        @Override
        public Object invoke(@Nonnull MethodInvocation invocation) throws Throwable {
            System.out.println("Enhancement...");
            return null;
        }
    }

    @Bean
    public MethodInterceptor interceptor() {
        return new CircularInterceptor();
    }

    @Bean
    public Pointcut pointcut() {
        return new StaticMethodMatcherPointcut(){
            @Override
            public boolean matches(Method method, Class<?> targetClass) {
                return "service".equals(method.getName());
            }
        };
    }

    @Bean
    public Advisor advisor() {
        return new DefaultPointcutAdvisor(pointcut(), interceptor());
    }

    public static void main(String[] args) {
        // 注解方式进行测试，需要使用 AnnotationConfigApplicationContext
        AnnotationConfigApplicationContext context = new AnnotationConfigApplicationContext();

        // 注册当前 CircularReferenceDemo，以触发 @ComponentScan 扫描当前包
        context.register(CircularReferenceDemo.class);

        // 启动容器
        context.refresh();

        // 获取 bean 实例
        ServiceA a = context.getBean(ServiceA.class);
        ServiceB b = context.getBean(ServiceB.class);
    }
}
```

`ServiceA` 和 `ServiceB` 存在循环依赖关系，且这两个对象都有 `service` 方法，满足 AOP 自动代理的条件，这就是典型的 AOP 场景下的循环依赖。

从之前的 AOP 示例中我们可以了解到，对于「代理对象」和原始目标对象，Spring 容器中对外暴露的是前者，因此，在依赖注入的过程中，循环依赖要注入的也是 `ServiceA` 和 `ServiceB` 的代理对象。

有了上面 setter 方式的分析，这里偷个懒，还是使用上面那张图，图中的 `A` 和 `B` 请读者自动替换为 `ServiceA` 和 `ServiceB`。在图中标出了 3 个紫色的位置，这是接下来要分析的重点。

![](https://s2.loli.net/2022/02/04/AWr2LFYve9l41Ey.png)

流程还是和 setter 方式类似，从 `ServiceA` 进入，再到 `ServiceA` 中的 `populate` 触发 `ServiceB` 的获取。而 `ServiceB` 的 `populate` 中同样又需要 `ServiceA`，因此还是会进入到步骤 7。

如果有些记忆模糊的话，请回头去看看步骤 7 的具体流程，这里重新贴一下这段代码：

```java
protected Object getEarlyBeanReference(String beanName, RootBeanDefinition mbd, Object bean) {
     Object exposedObject = bean;
     if (!mbd.isSynthetic() && hasInstantiationAwareBeanPostProcessors()) {
         for (SmartInstantiationAwareBeanPostProcessor bp : getBeanPostProcessorCache().smartInstantiationAware) {
             exposedObject = bp.getEarlyBeanReference(exposedObject, beanName);
         }
     }
     return exposedObject;
 }
```
刚才介绍过，当我们使用 `@EnableAspectJAutoProxy` 开启 AOP 自动创建模式后，容器中会导入一个 `AbstractAutoProxyCreator` 类，这个类此时满足这里的 `SmartInstantiationAwareBeanPostProcessor` 条件，因此会调用 `exposedObject = bp.getEarlyBeanReference(exposedObject, beanName);` 对我们的原始 `ServiceA` 的半成品进行增强处理。`AbstractAutoProxyCreator` 中 `getEarlyBeanReference` 具体代码如下：

```java
@Override
public Object getEarlyBeanReference(Object bean, String beanName) {
    Object cacheKey = getCacheKey(bean.getClass(), beanName);
    this.earlyProxyReferences.put(cacheKey, bean);
    return wrapIfNecessary(bean, beanName, cacheKey);
}
```

这里就不深入展开了，只需要了解到 `wrapIfNecessary` 是具体创建半成品「代理对象」的位置就行了。

步骤 7 完成后，由于有了 `ServiceA` 半成品「代理对象」，此时就可以返回 `ServiceB` 的 `populate` 方法，并完成其属性填充工作。随后调用 `initializeBean` 方法，调用该方法前，`ServiceB` 还是原始的目标类型，没有任何增强。

`initializeBean` 中在执行了各种初始化操作后，会进入 `BeanPostProcessor` 的 after 中，`AbstractAutoProxyCreator` 中该方法的实现如下：

```java
@Override
public Object postProcessAfterInitialization(@Nullable Object bean, String beanName) {
    if (bean != null) {
        Object cacheKey = getCacheKey(bean.getClass(), beanName);
        if (this.earlyProxyReferences.remove(cacheKey) != bean) {
            return wrapIfNecessary(bean, beanName, cacheKey);
        }
    }
    return bean;
}
```
是不是感觉非常得熟悉呢？这里同样调用了 `wrapIfNecessary` 方法，完成了 `ServiceB` 成品「代理对象」创建，注意，这里是成品。

接下来，使用这个 `ServiceB` 的成品「代理对象」完成 `ServiceA` 的 `populate` 工作，并进入到 `ServiceA` 的 `initializingBean` 方法。这时与 `ServiceB` 中不同的是，`ServiceA` 已经创建过一次并且进行了相关缓存（`cacheKey` 的作用），因此不会再进行创建，直接返回即可。

最终，容器中的 `ServiceA` 和 `ServiceB` 均顺利创建，都被进行了动态代理增强，且循环依赖也得到了解决。

---

## 总结

Spring 循环依赖分为两种情况：

- 构造器注入
- setter注入

只有在 setter（包括 `@Autowired` 注解，它的注入时期也是在 `populate` 中）注入情景下才能够解决，整体思路是利用提前「暴露」一个半成品对象完成其中一方的属性填充。而 AOP 场景下的循环依赖实际上还是依赖这套逻辑，只是对提前「暴露」的这个半成品进行了一些处理。