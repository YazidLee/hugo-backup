---
title: ThreadLocal 分析（下）——使用和源码
slug: threadlocal-source
summary: ThreadLocal 的使用、注意事项及源码分析。
author:
- SadBird
date: 2021-09-19T02:44:58.000+08:00
cover:
  image: https://i.loli.net/2021/09/25/HTBpP15DImOXl7A.jpg
  alt: ''
categories:
- Java
tags:
- Java
- ThreadLocal
- Reference
katex: true

---
## ThreadLocal 基本使用

下面示例模拟两个请求，在两个线程完成任务，任务由两部分组成，其中 `Service1` 负责生成 `TRACE_ID` 和一部分任务并调用 `Service2` ，而 `Service2` 可以使用 `TRACE_ID` ，完成剩余部分任务，最后清理 `TRACE_ID` 。

```java
public class ThreadLocalDemo {
    public static void main(String[] args) {
        Service2 service2 = new Service2();
        Service1 service1 = new Service1(service2);
        
        // 两个线程模拟两个请求
        Thread request1 = new Thread(service1::service1);
        Thread request2 = new Thread(service1::service1);

        request1.start();
        request2.start();
    }
}

/**
 * 全局上下文，管理TRACE_ID
 */
class TraceContext {
    // API文档中推荐ThreadLocal声明为private static
    private static final ThreadLocal<String> CONTEXT = new ThreadLocal<>();

    public static void set(String traceId) {
        CONTEXT.set(traceId);
    }

    public static String get() {
        return CONTEXT.get();
    }

    public static void remove() {
        CONTEXT.remove();
    }
}

/**
 * 负责创建TRACE_ID，调用Service2
 */
class Service1 {
    private static final String TRACE_ID_PREFIX = "X-TRACE-ID-";
    private static final AtomicInteger ID = new AtomicInteger(1);

    private Service2 service2;

    public Service1(Service2 service2) {
        this.service2 = service2;
    }

    public void service1() {
        // 在service1中先设置TRACE_ID
        TraceContext.set(TRACE_ID_PREFIX + ID.getAndIncrement());

        // 打印新生成的TRACE_ID，模拟一些业务操作
        System.out.println("generate new TRACE_ID: " + TraceContext.get()
                + " -> do something in service1, current thread is: " + Thread.currentThread());

        // 再调用service2
        service2.service2();
    }
}

/**
 * 使用TRACE_ID，并完成清理工作
 */
class Service2 {
    public void service2() {
        // 打印TRACE_ID， 模拟对TRACE_ID的操作
        System.out.println("current TRACE_ID is: " + TraceContext.get()
                + " -> do something in service2, current thread is: " + Thread.currentThread());

        // 操作完成后，手动清理
        TraceContext.remove();
    }
}
```

以上就是 `ThreadLocal` 最基本的使用场景，通过 `ThreadLocal` 来透传全局的某些上下文信息，以便后续的分析和追踪（`logback` 中实现 `MDC` 正是使用了 `ThreadLocal`）。

***

## ThreadLocal 源码分析

### ThreadLocal 概览

在解释具体代码之前，首先要搞清楚 `ThreadLocal`、`Thread` 及 `ThreadLocal` 中实际保存的 `value` 的关系，下面是 `ThreadLocal` 源码中的一段注释：

```java
/**                                                               
 * ThreadLocals rely on per-thread linear-probe hash maps attached
 * to each thread (Thread.threadLocals and                        
 * inheritableThreadLocals).  The ThreadLocal objects act as keys,
 * searched via threadLocalHashCode.  This is a custom hash code  
 * (useful only within ThreadLocalMaps) that eliminates collisions
 * in the common case where consecutively constructed ThreadLocals
 * are used by the same threads, while remaining well-behaved in  
 * less common cases.                                             
 */                                                               
private final int threadLocalHashCode = nextHashCode();
```

这里面有几个关键信息：

1. `ThreadLocal` 机制依靠的是 `Thread.threadLocals` 和 `Thread.inheritableThreadLocals` 这两个哈希表。
2. 每个线程有自己的 `Thread.threadLocals` 和 `Thread.inheritableThreadLocals`，线程间通过这种方式避免了共享，实现了隔离。
3. `ThreadLocal` 自身的作用是作为 `Thread.threadLocals` 和 `Thread.inheritableThreadLocals` 的 Key，因此每个 `ThreadLocal` 都需要有自己的hashcode，即 `threadLocalHashCode`。
4. `Thread.threadLocals` 和 `Thread.inheritableThreadLocals` 处理冲突的方式为 `linear-probe`，即线性探测。

在此基础上，我们先去 `Thread` 中找到 `Thread.threadLocals` 和 `Thread.inheritableThreadLocals`：

```java
// ...

/* ThreadLocal values pertaining to this thread. This map is maintained
 * by the ThreadLocal class. */                                        
ThreadLocal.ThreadLocalMap threadLocals = null;                        
                                                                       
/*                                                                     
 * InheritableThreadLocal values pertaining to this thread. This map is
 * maintained by the InheritableThreadLocal class.                     
 */                                                                    
ThreadLocal.ThreadLocalMap inheritableThreadLocals = null;

// ...
```

现在，可以画出一个大致的关系草图如下，先以 `threadLocals` 为例，`inheritableThreadLocals` 原理与 `threadLocals` 相同：

![](https://i.loli.net/2021/09/25/NeXLKPmW4vCJbcM.png)

从图上能更直观地看出 `ThreadLocal` 的「地位」，在层次结构上，它只是作为 `Thread` 中一个哈希表的 Key。但它的功能可不仅仅是个 Key，再回头看看 `threadLocals` 源码注释：

```java
/* ThreadLocal values pertaining to this thread. This map is maintained
 * by the ThreadLocal class. */                                        
ThreadLocal.ThreadLocalMap threadLocals = null;                                                                  
```

不难看出 `ThreadLocal` 还肩负着维护 `threadLocals` 的重要使命，即对 `threadLocals` 进行增删改查等操作。 下面就对 `ThreadLocal` 的这两大作用分别进行源码分析。

### 作为哈希表的 Key

上面已经提到，每个 `ThreadLocal` 都有 `threadLocalHashCode` 属性，这个值将作为 Key 的 hashcode 参与到后续的计算。`threadLocalHashCode` 的计算方式如下：

```java
private final int threadLocalHashCode = nextHashCode();              
                                                                     
/**                                                                  
 * The next hash code to be given out. Updated atomically. Starts at 
 * zero.                                                             
 */                                                                  
private static AtomicInteger nextHashCode =                          
    new AtomicInteger();                                             
                                                                     
/**                                                                  
 * The difference between successively generated hash codes - turns  
 * implicit sequential thread-local IDs into near-optimally spread   
 * multiplicative hash values for power-of-two-sized tables.         
 */                                                                  
private static final int HASH_INCREMENT = 0x61c88647;                
                                                                     
/**                                                                  
 * Returns the next hash code.                                       
 */                                                                  
private static int nextHashCode() {                                  
    return nextHashCode.getAndAdd(HASH_INCREMENT);                   
}
```

可以看到，第1个 `ThreadLocal` 的 `threadLocalHashCode` 为 0，此后，每新建一个 `ThreadLocal` 对象，该对象的 `threadLocalHashCode` 值就为上一个对象的 `threadLocalHashCode` 值加上 `HASH_INCREMENT`。

说得直白点，设 `HASH_INCREMENT` 值为 $a$，那么第 1 个 `ThreadLocal` 对象的 `threadLocalHashCode` 为 $0 * a$，第 2 个为 $1 * a$，第 3 个为 $2 * a$，... ，第 n 个为 $(n - 1) * a$，属于乘法 hash。

代码中，这个 $a$ 值设定为一个特殊的数字：`0x61c88647`，理由在注释中已经给出，这个值能够使 Key 值在大小为 $2 ^ n$ 的哈希表上均匀地分布，至于其中的原理就不继续深究，和黄金分割、斐波那契相关，感兴趣的可以自行查阅资料。

继续查看 `ThreadLocal` 的静态内部类 `ThreadLocalMap`，它在构造函数中将 Key 的 hashcode 映射到具体位置的代码如下：

```java
// ...
private static final int INITIAL_CAPACITY = 16;

//...
int i = key.threadLocalHashCode & (INITIAL_CAPACITY - 1);
```

为了证明这种方式的有效性，下面进行一个小的模拟实验：

```java
private static final int A = 0x61c88647;

public static void main(String[] args) {
    hashSequence(1);
    hashSequence(2);
    hashSequence(3);
    hashSequence(4);
} 
                      
private static void hashSequence(int n) {                       
    int size = 1 << n;                                         
    int mod = size - 1;                                        
                                                               
    System.out.print("hash seq for " + size + " size table: ");
                                                               
    for (int i = 0; i < size; i++) {                           
        int index = (i * A) & mod;                             
        System.out.print( index + "  ");                       
    }                                                          
                                                               
    System.out.println();                                      
}
```

结果如下：

```bash
hash seq for 2 size table: 0  1  
hash seq for 4 size table: 0  3  2  1  
hash seq for 8 size table: 0  7  6  5  4  3  2  1  
hash seq for 16 size table: 0  7  14  5  12  3  10  1  8  15  6  13  4  11  2  9
```

效果拔群！

### 管理 threadLocals

* 增、改：`set` 方法源码如下，关于 `ThreadLocalMap` 放在后面探讨，这里先简单理解为一个普通的哈希表：

  ```java
  public void set(T value) {  
      // 获取当前线程          
      Thread t = Thread.currentThread();
      // 获取线程中的threadLocals
      ThreadLocalMap map = getMap(t);   
      if (map != null)
          // 不为空直接set，set方法其实是有“副作用”的，但这里暂时理解为简单的取值   
          // 这里this就是当前的ThreadLocal对象，作为Key               
          map.set(this, value);         
      else    
          // 为空就new Map                          
          createMap(t, value);          
  }
  
  ThreadLocalMap getMap(Thread t) {
      return t.threadLocals;       
  }
  
  void createMap(Thread t, T firstValue) {                       
      t.threadLocals = new ThreadLocalMap(this, firstValue);     
  }
  ```
* 查：`get` 方法源码如下：

  ```java
  public T get() {       
      // 这两行和set一模一样                               
      Thread t = Thread.currentThread();                
      ThreadLocalMap map = getMap(t);                   
      if (map != null) {
          // map不为空，直接从map中取值，getEntry其实是有「副作用」的，但这里暂时理解为简单的取值                                
          ThreadLocalMap.Entry e = map.getEntry(this);  
          if (e != null) {                              
              @SuppressWarnings("unchecked")            
              T result = (T)e.value;                    
              return result;                            
          }                                             
      } 
      // map为空，则需要初始化map                                                
      return setInitialValue();                         
  }
  
  // 这个方法和set基本一模一样
  private T setInitialValue() { 
      // 获取初始值        
      T value = initialValue();         
      Thread t = Thread.currentThread();
      ThreadLocalMap map = getMap(t);  
      // 将初始值设置到map中 
      if (map != null)   
          // set方法其实是有「副作用」的，但这里暂时理解为简单的取值 
          // 这里this就是当前的ThreadLocal对象，作为Key                 
          map.set(this, value);         
      else                              
          createMap(t, value);          
      return value;                     
  }
  
  // 待子类重写，返回初始value
  protected T initialValue() {
      return null;            
  }
  ```
* 删：`remove` 方法源码如下：

  ```java
  public void remove() {                                
      ThreadLocalMap m = getMap(Thread.currentThread());
      if (m != null)   
          // 这里this就是当前的ThreadLocal对象，作为Key传入，最终从map中删除Key为当前ThreadLocal的元素 
          // 这里是线性探测法的remove，需要特别注意
          // 与get、set类似，这里的remove也会有特殊的操作，这里暂时理解为简单的删除                               
          m.remove(this);                               
  }
  ```
* Java8 新增静态方法 `withInitial` ：

  ```java
  public static <S> ThreadLocal<S> withInitial(Supplier<? extends S> supplier) {
      return new SuppliedThreadLocal<>(supplier);                               
  }
  
  static final class SuppliedThreadLocal<T> extends ThreadLocal<T> {
                                                                    
      private final Supplier<? extends T> supplier;                 
                                                                    
      SuppliedThreadLocal(Supplier<? extends T> supplier) {         
          this.supplier = Objects.requireNonNull(supplier);         
      }                                                             
                                                                    
      @Override                                                     
      protected T initialValue() {                                  
          return supplier.get();                                    
      }                                                             
  }
  ```

  也比较容易理解，原来的写法是：

  ```java
  ThreadLocal<Object> tl = new ThreadLocal<>() {
      @Override
      protected Object initialValue() {
          return new Object();
      }
  }
  ```

  现在可以写成这样，比较省事：

  ```java
  ThreadLocal<Object> tl = ThreadLocal.withInitial(Object::new);
  ```

OK，至此，`ThreadLocal` 表面上的东西已经介绍得差不多了，代码都比较简单，结合上面那个草图理解起来应该没什么问题。然而，`ThreadLocal` 最为复杂的部分其实是它的内部类 `ThreadLocalMap`，下面的内容就是把这块硬骨头一点一点啃下来。

***

## ThreadLocalMap 源码分析

在进入源码前，需要有一些知识铺垫：

1. 首先需要了解过哈希表是什么，对哈希冲突、开放地址、线性探测等概念比较熟悉，最好自己动手实现过。可以上网找找，资料挺多的，这里推荐一个入门视频：

   {{< bilibili BV1MC4y1p7rP >}}
2. 对 Java 的弱引用有所了解，不知道的可以看看之前的这篇文章 [ThreadLocal 分析（上）——Java 中的引用](https://www.liyangjie.cn/posts/work/threadlocal-reference/)。

### ThreadMap 字段

初步先看看 `ThreadLocalMap` 的字段：

![](https://i.loli.net/2021/09/25/q8mJRXyKC2hwM4S.png)

阅读过 `HashMap` 源码的话其实这些字段都不需要再解释了，非常简单，从上到下依次为：初始容量（最大桶数量）、实际的哈希表（`Entry` 数组，它的长度一定为 $2 ^ n$）、当前哈希表中元素的数量、下次扩容的阈值。

其他字段都好说，这里引入关键问题的字段就是 `Entry`：

```java

/**
 *... 
 * To help deal with very large and long-lived usages, the hash table entries use
 * WeakReferences for keys.
 *...
 */
static class ThreadLocalMap {
    // ...

    /**                                                               
    * The entries in this hash map extend WeakReference, using       
    * its main ref field as the key (which is always a               
    * ThreadLocal object).  Note that null keys (i.e. entry.get()    
    * == null) mean that the key is no longer referenced, so the     
    * entry can be expunged from table.  Such entries are referred to
    * as "stale entries" in the code that follows.                   
    */                                                               
    static class Entry extends WeakReference<ThreadLocal<?>> {        
        /** The value associated with this ThreadLocal. */            
        Object value;                                                 
                                                                          
        Entry(ThreadLocal<?> k, Object v) {                           
            super(k);                                                 
            value = v;                                                
        }                                                             
    }

    // ...
}
```

有没有似曾相识的感觉，在上一篇 [ThreadLocal 分析（上）——Java 中的引用](https://www.liyangjie.cn/posts/work/threadlocal-reference/) 中，介绍过一个 `WeakHashMap`，它的 `Entry` 定义 `private static class Entry<K,V> extends WeakReference<Object> ...` 与这里的 `Entry` 如出一辙，第一段注释也写得很清楚，使用 `WeakReference` 作为 Key 是为了回收生命周期较长的大对象。

留意第二段注释中有个特别的说明：「当某个 `entry` 满足 `entry.get() == null` 时（隐含条件是 `entry != null`），表明这个 `entry` 的 Key 已经不再被引用关联到，因此这个 `entry` 可以被的删除（`expunged`），这样的 `entry` 在代码中被称为 `stale entry`。」多看几遍这几个重要的单词，`expunged`、`stale entries`，后面会频繁出现。

现在可以将第一个草图进行修改了，哈希表 `ThreaedLoclaMap` 中 `Entry` 的Key实际上是一个 `WeakReference` 对象，这个对象中的 `referent` 弱指向了实际的 `ThreadLocal` 对象，虚线表示弱引用：

![](https://i.loli.net/2021/09/25/f1TJCLbvGpXl6nF.png)

接下来看看 `ThreadLocalMap` 的构造函数（在 `ThreadLocal` 的 `createMap` 方法中使用到，忘记的话可以退回到上一节的 `set` 方法中查看）：

```java
// ...

private static final int INITIAL_CAPACITY = 16;

// ...

ThreadLocalMap(ThreadLocal<?> firstKey, Object firstValue) { 
    // 创建初始长度为16的Entry数组     
    table = new Entry[INITIAL_CAPACITY];  
    // 将传入的 ThreadLocal作为key， Object作为value，新建第一个Entry放入哈希表中                        
    int i = firstKey.threadLocalHashCode & (INITIAL_CAPACITY - 1);
    table[i] = new Entry(firstKey, firstValue);   
    // 当前元素个数为1                
    size = 1; 
    // 设置扩容阈值                                                    
    setThreshold(INITIAL_CAPACITY);                               
}

// 设置扩容阈值为 len 的 2/3
private void setThreshold(int len) {
    threshold = len * 2 / 3;        
}
```

### set

```java
// 计算哈希表当前位置i的下一位置，一般情况为i + 1
// 但当超过数组长度len时，就重新回到数组开头位置0
private static int nextIndex(int i, int len) {
    return ((i + 1 < len) ? i + 1 : 0);       
}

// 计算哈希表当前位置i的上一位置，一般情况为i - 1
// 但到达0位置时，它的上一位置是len - 1
private static int prevIndex(int i, int len) {
    return ((i - 1 >= 0) ? i - 1 : len - 1);  
}

private void set(ThreadLocal<?> key, Object value) {                                                                          
    Entry[] tab = table;                                          
    int len = tab.length;     
    // 计算参数key在哈希表中的对应的实际位置i                                   
    int i = key.threadLocalHashCode & (len-1);                    
    
    // 线性探测法 
    // 从i开始，往「后」遍历，直到i位置的Entry为null                                                              
    for (Entry e = tab[i];                                        
         e != null;                                               
         e = tab[i = nextIndex(i, len)]) {  
        // e.get()获取当前i位置的Key，是WeakReference中的方法，有可能返回null                      
        ThreadLocal<?> k = e.get();                               
        
        // 找到当前key，表示是修改操作，直接修改value并返回                                                         
        if (k == key) {                                           
            e.value = value;                                      
            return;                                               
        }                                                         
        
        // k为null的情况，表示该位置Entry的Key已经被回收，需要进行特殊处理，后面介绍                                                         
        if (k == null) {                                          
            replaceStaleEntry(key, value, i);                     
            return;                                               
        }                                                         
    }                                                             
    
    // i位置的Entry为null，表示该key还不存在，就把当前key、value放入i位置
    // 线性探测法，这里的i不一定为最初的由hashcode计算后的i                                                             
    tab[i] = new Entry(key, value);                               
    int sz = ++size;  
    // 先进行启发式清理操作，随后判断是否需要进行rehash操作                                            
    if (!cleanSomeSlots(i, sz) && sz >= threshold)                
        rehash();                                                 
}

private void rehash() {
    // rehash前进行一个全面的清理                                     
    expungeStaleEntries();                                  
                                                            
    // Use lower threshold for doubling to avoid hysteresis 
    // 这里判断条件将扩容的要求缩减为了3/4的threshold，初始构造时threshold为2/3的len
    // 因此相当于扩容的要求为1/2的len 
    if (size >= threshold - threshold / 4)                  
        resize();                                           
}

private void resize() { 
    // 新哈希表的容量为原来的2倍                                      
    Entry[] oldTab = table;                                   
    int oldLen = oldTab.length;                               
    int newLen = oldLen * 2;                                  
    Entry[] newTab = new Entry[newLen];                       
    int count = 0;                                            
     
    // 将所有旧元素放到新的哈希表中                                                         
    for (int j = 0; j < oldLen; ++j) {                        
        Entry e = oldTab[j];                                  
        if (e != null) {                                      
            ThreadLocal<?> k = e.get();                       
            if (k == null) {
                // 旧元素中如果有已经成为stale entry的，直接将其value的引用断开
                // 方便GC回收value占用的空间                                  
                e.value = null; // Help the GC                
            } else { 
                // 线性探测法将旧元素放到新表中的合适位置                                         
                int h = k.threadLocalHashCode & (newLen - 1); 
                while (newTab[h] != null)                     
                    h = nextIndex(h, newLen);                 
                newTab[h] = e;                                
                count++;                                      
            }                                                 
        }                                                     
    }                                                         
   
    // 重新设置扩容阈值和当前元素个数，并将table指向新表，完成扩容操作                                                          
    setThreshold(newLen);                                     
    size = count;                                             
    table = newTab;                                           
}
```

1. 首先介绍一下 `nextIndex` 和 `preIndex` 方法，它们分别计算当前位置 `i` 的下一个位置和上一个位置，这种计算方式使得数组的位置得到了循环利用，逻辑上构成了一个环形数组，`next` 表示顺时针，而 `pre` 表示逆时针，如下图所示：

   ![](https://i.loli.net/2021/09/25/EcMjfxBbpv8LrSt.png)
2. `set` 方法的主要作用是新增和修改哈希表中的元素，处理冲突的方式也是常用的线性探测法，即如果使用 Key（`ThreadLocal` 类型）的 `threadLocalHashCode` 计算出的位置已经存在 `Entry`（这个 `Entry` 有可能是有效的元素，也有可能是 Key 已经被回收的 `stale entry`），就进入循环，判断是否是修改操作。注意循环中还有个 `replaceStaleEntry`，它会执行一些清理工作，然后将 `key`、`value` 放到合适的 `Entry` 中，后面会详细介绍。一直探测到某个位置的 `Entry` 为 `null`，就用 `key` 、`value` 新建 `Entry` 并放在该位置。
3. `rehash` 操作前，会先进行一次 `cleanSomeSlots` 清理操作，这个方法在源码注释中使用了 _Heuristically（启发式地）_ 进行描述，因此这里简称它为 `启发式清理`。而在 `rehash` 方法中，在调用 `resize` 方法扩容前，还会调用另外一个 `expungeStaleEntries` 清理操作，熟悉的词汇，在源码注释中描述为 _Expunge all stale entries in the table（清理所有 stale entry）_，它本质上是调用了 `expungeStaleEntry` 方法，而 `expungeStaleEntry` 方法是对哈希表中的 stale entry 进行部分清理，后面就简称它为 `分段式清理`。
4. 两个清理工作完成后，才开始正式的 `resize` 扩容流程，新建一个两倍容量的数组，将旧表中的元素转移到新表，同时清理一些 stale entry。

### getEntry

```java
private Entry getEntry(ThreadLocal<?> key) {  
     // 计算key对应在哈希表中的实际位置i，作为查找的起点           
     int i = key.threadLocalHashCode & (table.length - 1);
     Entry e = table[i];
     // 如果i位置的entry不为空，且直接就是要找的key，直接返回，提高效率                                  
     if (e != null && e.get() == key)                     
         return e;                                        
     else
         // 否则，需要进一步查询                                                
         return getEntryAfterMiss(key, i, e);             
 }

private Entry getEntryAfterMiss(ThreadLocal<?> key, int i, Entry e) {
    Entry[] tab = table;                                             
    int len = tab.length;                                            
    
    // 当前entry不为空，可能是有效entry，也可能是stale entry                                                                  
    while (e != null) {                                              
        ThreadLocal<?> k = e.get();
        // 找到了目标key，直接返回该Entry                                  
        if (k == key)                                                
            return e;
        // k为null，表示该Entry是stale entry，以i为起点进行分段清理                                                
        if (k == null)                                               
            expungeStaleEntry(i);                                    
        else 
            // 表示当前位置是有效entry，但不是目标entry，继续查找下一个位置                                                        
            i = nextIndex(i, len);                                   
        e = tab[i];                                                  
    }
    // entry数组中的查找碰到null，表示查找失败，哈希表中不存在该key，返回null                                                                
    return null;                                                     
}
```

`getEntry` 的流程整体上比较简单，和普通线性探测哈希表的 get 方法没什么区别：

1. 使用 key 的 `threadLocalHashCode` 计算出实际位置 `i`，以这个 `i` 为查找的起点，如果 `i` 位置的 Entry 就是我们想要查找的目标（`e.get() == key`），则直接返回。其实这里 `e == null` 时也可以直接返回 `null`，不过代码中把它延迟到了 `getEntryAfterMiss` 中，没什么区别。
2. `getEntryAfterMiss` 就从起点 `i` 开始，向后查找（`nextIndex`），如果找到目标，直接返回 Entry，如果遇到 `null`，直接返回 `null` 表示哈希表中没有该目标，这两个操作与普通线性探测法一致。不同的是当遇到 `k == null`，也就是 Entry 为 stale entry 时，需要多进行一次 `分段式清理` 操作。

### remove

```java
private void remove(ThreadLocal<?> key) {      
    Entry[] tab = table;                       
    int len = tab.length;                      
    int i = key.threadLocalHashCode & (len-1); 
    for (Entry e = tab[i];                     
         e != null;                            
         e = tab[i = nextIndex(i, len)]) {
        // 找到目标     
        if (e.get() == key) {
            // 断开key的弱引用                  
            e.clear();
            // 以i为起点进行一次分段清理                         
            expungeStaleEntry(i);              
            return;                            
        }                                      
    }                                          
}
```

线性探测法的 `remove` 操作其实是比较繁琐的，上面的代码看上去很简单，因为它把具体的操作放到了 `分段式清理` 的方法中，接下来就是要对清理方法进行分析。

### 清理

从上面对几个增删改查操作的源码，不难发现，大多数方法除了完成自身的本职工作外，都会附带地在某些条件下对哈希表进行一些清理工作，包括 `分段式清理` 和 `启发式清理`，下面将分别进行分析。

* 分段式清理

```java
private int expungeStaleEntry(int staleSlot) {                            
    Entry[] tab = table;                                                  
    int len = tab.length;                                                 
                                                                          
    // expunge entry at staleSlot 
    // 这步很简单，就是简单的删除staleSlot位置的entry
    // 断开entry中指向value的强引用，以便value会被GC回收                                      
    tab[staleSlot].value = null;  
    // 清空数组当前位置                                       
    tab[staleSlot] = null;                                                
    size--;                                                               
                                                                          
    // Rehash until we encounter null                                     
    Entry e;                                                              
    int i; 
    // 从被删除元素的下个位置开始，对每个Entry进行rehash操作，直到键簇的末尾(遇到null)                                                              
    for (i = nextIndex(staleSlot, len);                                   
         (e = tab[i]) != null;                                            
         i = nextIndex(i, len)) {                                         
        ThreadLocal<?> k = e.get(); 
        // 比起普通线性探测的删除，多了这个清理stale entry的操作
        // k == null，表示当前entry为stale entry                                      
        if (k == null) {
            // 同样，断开value的强引用，将table                                                  
            e.value = null; 
            // 清空数组当前位置                                              
            tab[i] = null;                                                
            size--;                                                       
        } else {
            // key不为空表示该entry有效，则进行rehash操作
            // 重新计算位置                                                          
            int h = k.threadLocalHashCode & (len - 1);  
            // 新位置h与当前位置i不相等，表示它是因为哈希冲突被「挤」到i位置
            // rehash后它有机会更靠近h位置                  
            if (h != i) { 
                // 这个操作很重要，表示将当前i位置留空，
                // 保证rehash后，当前entry至少能再次放到这个i位置                                                
                tab[i] = null;                                            
                                                                          
                // Unlike Knuth 6.4 Algorithm R, we must scan until       
                // null because multiple entries could have been stale.  
                // 从h位置往后找到第一个为null的位置即为该entry的新位置
                // 上面在i位置留了个空，因此最坏情况是最终h==i
                while (tab[h] != null)                                    
                    h = nextIndex(h, len);                                
                tab[h] = e;                                               
            }                                                             
        }                                                                 
    }                                                                     
    return i;                                                             
}
```

这个清理基本上等同于普通线性探测法的删除操作，只是在 rehash 的过程中增加了一个删除 stale entry 的步骤。下面以一个示例对流程进行讲解：

1. 初始状态：`K1~K7` 代表一个键簇，假定 `K1~K7` 计算后得到的位置均为 `13`。图中绿色表示有效 entry，灰色表示 stale entry，而白色为 `null`。现在开始执行 `expungeStaleEntry(13)`，即传入的参数 `staleSlot = 13`。

   ![](https://i.loli.net/2021/09/25/Vo8XRde32W6vCAn.png)
2. 根据步骤，首先删除 `K1` 的 `Entry`，并将 `i` 移动到 `K1` 的下个位置 `14`：

   ![](https://i.loli.net/2021/09/25/UbnYR2vdl7FVTZ3.png)
3. 随后，`K2` 位置为 stale entry，进入 `k == null` 分支，删除 `K2`，进入下次循环，`i` 到达 `15`，`K3` 为有效 entry，进行 rehash 操作，将 `h` 进行计算 `h = 13`（1 中的假设）。

   ![](https://i.loli.net/2021/09/25/Yxi7F5KkSvDQjaL.png)
4. 先清空 `i` 位置，随后开始判断 `h` 位置，刚好 `h` 位置为空，则直接将 `K3` 代表的 `Entry` 放入 `13` 位置，`i` 移动到 `0` 位置。

   ![](https://i.loli.net/2021/09/25/7lcorFteNGsDApC.png)
5. 与步骤 3 类似，清空 `K4`，`i` 移动至 `1` 位置。

   ![](https://i.loli.net/2021/09/25/SveMP48UqOtGFBc.png)
6. `K5~K7` 均为有效 entry，因此进行 rehash 操作，`K5` 的 `h = 13`，此时 `13` 位置不为空，则 `h` 移动到 `14`，`14` 位置为空，则将 `K5` 的 `Entry` 移动到 `14`。同理，将 `K6` 和 `K7` 移动到 `15` 和 `0` 位置。最后，`i` 移动到 `4` 的位置（**原** 键簇末尾紧邻的 null 位置），返回 `i`（马上会用到），本次 `分段式清理` 结束。

   ![](https://i.loli.net/2021/09/25/bvNpCDqBdocyRhi.png)

了解过 `expungeStaleEntry` 基本原理后，回头看看 `rehash` 代码中调用的 `expungeStaleEntries` 方法：

```java
/**                                       
 * Expunge all stale entries in the table.
 */                                       
private void expungeStaleEntries() {      
    Entry[] tab = table;                  
    int len = tab.length;   
    // 遍历哈希表每个位置，对stale entry进行清理              
    for (int j = 0; j < len; j++) {       
        Entry e = tab[j];                 
        if (e != null && e.get() == null) 
            expungeStaleEntry(j);         
    }                                     
}
```

是不是就毫无难度了，这就是一个简单粗暴的全局大清理工作。

* 启发式清理

```java

/**                                                            
 * Heuristically scan some cells looking for stale entries.    
 * This is invoked when either a new element is added, or      
 * another stale one has been expunged. It performs a          
 * logarithmic number of scans, as a balance between no        
 * scanning (fast but retains garbage) and a number of scans   
 * proportional to number of elements, that would find all     
 * garbage but would cause some insertions to take O(n) time.  
 *                                                             
 * @param i a position known NOT to hold a stale entry. The    
 * scan starts at the element after i.                         
 *                                                             
 * @param n scan control: {@code log2(n)} cells are scanned,   
 * unless a stale entry is found, in which case                
 * {@code log2(table.length)-1} additional cells are scanned.  
 * When called from insertions, this parameter is the number   
 * of elements, but when from replaceStaleEntry, it is the     
 * table length. (Note: all this could be changed to be either 
 * more or less aggressive by weighting n instead of just      
 * using straight log n. But this version is simple, fast, and 
 * seems to work well.)                                        
 *                                                             
 * @return true if any stale entries have been removed.        
 */
private boolean cleanSomeSlots(int i, int n) { 
    boolean removed = false;                   
    Entry[] tab = table;                       
    int len = tab.length;                      
    do {                                       
        i = nextIndex(i, len);                 
        Entry e = tab[i];                      
        if (e != null && e.get() == null) {    
            n = len;                           
            removed = true;                    
            i = expungeStaleEntry(i);          
        }                                      
    } while ( (n >>>= 1) != 0);                
    return removed;                            
}
```

这里把源码中的所有注释都搬进来了，非常详细的一段注释，从设计思想到各参数的详细讲解，应有尽有。代码不长，核心循环的工作是以 `i` 为起点对哈希表进行扫描（注释中重点写明这个起始 `i` 位置一定 **不是** stale entry），判断是否存在 stale entry。如果一直没扫描到，那么在扫描 $log_2 n$ 次后就结束循环，返回 `false`。如果扫描到存在 stale entry，那么 `cleanSomeSlots` 调用我们刚介绍过的 `expungeStaleEntry` 进行清理，`i` 的值将直接跳到被清理键簇的紧邻 `null` 位置，并且会将扫描次数扩大，进行额外的 $log_2 (table.length)-1$ 次扫描。

每次发现 stale entry，就会重新将扫描次数进行增加，哈希表中的 stale entry 越多，扫描的次数就会越多，进行的清理操作就越多，这就是一个逐步启发的过程。代码注释中说到这种方式是一种折中的实现，在完全不进行扫描和全局扫描之间找到一个平衡点。

这个方法会在两个地方被调用，第一个是在 `set` 方法的末尾，新增元素成功后，在 `rehash` 之前进行一次启发式清理，这时候传入的两个参数分别为新增元素的位置 `i` 及新增后所有元素的个数 `sz`。

```java
// 在i位置新增entry元素                                                            
tab[i] = new Entry(key, value);                               
int sz = ++size;  
// 先进行启发式清理操作，随后判断是否需要进行rehash操作                                            
if (!cleanSomeSlots(i, sz) && sz >= threshold)                
    rehash();  
```

第二个被调用的地方就是我们之前一笔带过的 `replaceStaleEntry`，这个方法逻辑比较复杂，涉及的内容比较多，因此我放到了最后再来补上。

* replaceStaleEntry

```java
private void replaceStaleEntry(ThreadLocal<?> key, Object value,           
                               int staleSlot) {                            
    Entry[] tab = table;                                                   
    int len = tab.length;                                                  
    Entry e;                                                               
                                                                           
    // Back up to check for prior stale entry in current run.              
    // We clean out whole runs at a time to avoid continual                
    // incremental rehashing due to garbage collector freeing              
    // up refs in bunches (i.e., whenever the collector runs).             
    int slotToExpunge = staleSlot;                                         
    for (int i = prevIndex(staleSlot, len);                                
         (e = tab[i]) != null;                                             
         i = prevIndex(i, len))                                            
        if (e.get() == null)                                               
            slotToExpunge = i;                                             
                                                                           
    // Find either the key or trailing null slot of run, whichever         
    // occurs first                                                        
    for (int i = nextIndex(staleSlot, len);                                
         (e = tab[i]) != null;                                             
         i = nextIndex(i, len)) {                                          
        ThreadLocal<?> k = e.get();                                        
                                                                           
        // If we find key, then we need to swap it                         
        // with the stale entry to maintain hash table order.              
        // The newly stale slot, or any other stale slot                   
        // encountered above it, can then be sent to expungeStaleEntry     
        // to remove or rehash all of the other entries in run.            
        if (k == key) {                                                    
            e.value = value;                                               
                                                                           
            tab[i] = tab[staleSlot];                                       
            tab[staleSlot] = e;                                            
                                                                           
            // Start expunge at preceding stale entry if it exists         
            if (slotToExpunge == staleSlot)                                
                slotToExpunge = i;                                         
            cleanSomeSlots(expungeStaleEntry(slotToExpunge), len);         
            return;                                                        
        }                                                                  
                                                                           
        // If we didn't find stale entry on backward scan, the             
        // first stale entry seen while scanning for key is the            
        // first still present in the run.                                 
        if (k == null && slotToExpunge == staleSlot)                       
            slotToExpunge = i;                                             
    }                                                                      
                                                                           
    // If key not found, put new entry in stale slot                       
    tab[staleSlot].value = null;                                           
    tab[staleSlot] = new Entry(key, value);                                
                                                                           
    // If there are any other stale entries in run, expunge them           
    if (slotToExpunge != staleSlot)                                        
        cleanSomeSlots(expungeStaleEntry(slotToExpunge), len);             
}
```

这也是个非常繁琐的方法，但是注释内容较多，理解起来也很方便。

1. 这个方法是在 `set` 中被调用的，在线性探测插入（或修改）元素时，如果遇到了 stale entry，那么就进入到 `replaceStaleEntry`，传入的参数为元素的 `key`、`value` 以及 stale entry 的位置 `i`。

   ```java
   // k为null的情况，表示stale entry                                                        
   if (k == null) {                                          
       replaceStaleEntry(key, value, i);                     
       return;                                               
   }
   ```
2. `replaceStaleEntry` 中的第一个循环主要作用是找到 `i` 位置所在键簇最前端的某个 stale entry 位置。举例说明，`set` 方法将传入参数 `K8`，图中 `K8` 为待探测元素，计算得到它的起始位置为 `0`。由于 `K4` 为有效 entry，且 `K4 ≠ K8`，因此 `set` 方法中的 `i` 移动至 `1` 位置。`1` 位置上的 `K5` 是 stale entry，因此，从这里开始调用 `replaceStaleEntry`，传入的第三个参数 `staleSlot` 为 `1`。这时候，`replaceStaleEntry` 的第一个循环就从这个 `staleSlot` 开始 **向前移动**，寻找最前端的 stale slot，即 `13`（虽然 `15` 也是 stale slot，但它不是这个键簇的最前端），并赋值 `slotToExpunge = 13`。

   ![](https://i.loli.net/2021/09/25/rmgx6PUztFLnW8R.png)
3. 第二个循环从 `staleSlot` 的下个位置开始，**往后移动**，在键簇中寻找 `k == key` 的 `Entry`，直到键簇末尾。注意循环末尾的一小段代码：

   ```java
   if (k == null && slotToExpunge == staleSlot)                       
       slotToExpunge = i; 
   ```

   它表示如果在 **往后**（区别步骤 2 中的往前）寻找的过程中遇到了 stale entry，且刚才步骤 2 中没找到 stale entry，那么就将 `slotToExpunge` 赋值为这个 stale entry 的位置 `i`。再用一个例子来说明，如下图所示，同样从 `set` `K8` 元素开始，到 `1` 位置进入 `replaceStaleEntry`，此时往前寻找不到 stale entry，那么进入第二个循环前，`slotToExpunge == staleSlot`。

   进入第二个循环后，向后寻找到 `2` 位置，发现 `K6` 是 stale slot，即 `k == null`，且这时候满足第二个条件，因此 `slotToExpunge = 2`。

   ![](https://i.loli.net/2021/09/25/YftE2wO5p4bFIR8.png)

   这个赋值操作最多只会执行一次，第二次再进来 `slotToExpunge == staleSlot` 这个条件一定不会再满足了，这个循环的起始位置是 `staleSlot` 的 **下个位置**，已经就不等于 `staleSlot` 了，往后的 `i` 值就更不会满足该条件。
4. 第二个循环过程中，如果找到了满足 `k == key` 条件的 `Entry`，那么就会进入替换及清理的代码中：

   ```java
   if (k == key) {                                                    
       e.value = value;                                               
                                                                              
       tab[i] = tab[staleSlot];                                       
       tab[staleSlot] = e;                                            
                                                                              
       // Start expunge at preceding stale entry if it exists         
       if (slotToExpunge == staleSlot)                                
           slotToExpunge = i;                                         
       cleanSomeSlots(expungeStaleEntry(slotToExpunge), len);         
       return;                                                        
   }
   ```

   `staleSlot` 是调用 `replaceStaleEntry` 方法时传入的参数，也就是 `set` 方法调用过程中发现的第一个 stale entry 的位置。这里先将当前 `Entry` 的 `value` 进行了替换修改，然后将当前位置 `i` 与 `staleSlot` 位置的元素进行了交换，交换过后，`i` 位置变为 stale entry，而 `staleSlot` 位置成为了有效 entry。

   这段代码就是 `replaceStaleEntry` 命名的由来，它将原来 `set` 中识别出的 stale entry 替换为了一个新的有效 entry（key 是原来已经存在的，仅修改了 value）。下图中，`K8 == K8'`，当 `i == 4` 时，进入上述逻辑中，先将 `K8'` 的 `value` 进行替换修改，再将 `K5` 与 `K8'` 进行交换，得到下面的成果。

   ![](https://i.loli.net/2021/09/25/RnS1LPQ6hMsr3oZ.png)

   ![](https://i.loli.net/2021/09/25/yRc5FGDdluv3hE8.png)

   替换成功后，随后条件判断与步骤 3 逻辑相同，都是确定 `slotToExpunge` 的位置，此时的 `i` 位置已经是 stale entry 了，因此可以作为 `expungeStaleEntry` `分段式清理` 的起点。

   最后就是进行两次清理，先分段清理，再将其返回值传入 `cleanSomeSlots` 进行启发式清理，启发式清理中的第二个参数为 `len`，即哈希表当前的最大容量，区别 `set` 方法末尾的参数传入的 `sz`。
5. 若第二个循环中没有找到能够替换的 `Entry`，则进入到最后的新建逻辑：

   ```java
    // If key not found, put new entry in stale slot                       
   tab[staleSlot].value = null;                                           
   tab[staleSlot] = new Entry(key, value);                                
                                                                              
   // If there are any other stale entries in run, expunge them           
   if (slotToExpunge != staleSlot)                                        
       cleanSomeSlots(expungeStaleEntry(slotToExpunge), len); 
   ```

   `staleSlot` 处成为新元素插入的位置，如果在第二个循环中发现了其他 stale entry，就进行两步清理工作。

***

## ThreadLocal 注意事项

### 内存泄漏

![](https://i.loli.net/2021/09/25/td1sG2VzF9WQwTN.png)

根据官方文档的推荐，我们平时使用 `ThreadLocal` 往往都会将它声名为 `private static`，那么，上图中红色部分的强引用将会一直存在（metaspace 中），该 `ThreadLocal` 在一个长期执行线程的 `Thread.threadLocals` 哈希表中对应的一个 `Entry e`，由于强引用的存在，`e.get()` 返回的 **不会** 是 `null`，那么指望上面的各种自动清理方法回收 `value` 内存就不太现实，需要开发人员手动调用 `remove` 方法回收不再使用的 `ThreadLocal`。

### 脏数据

在线程池环境下，由于线程的复用，`ThreadLocal` 的脏数据问题比较常见。

设想如下场景：用户 A 登录了网站，请求执行某些任务，为了后续方便，系统将部分用户信息保存到 `ThreadLocal` 中，但是忘记在任务完成后将这些信息手动清理；随后用户 B 也登录了同一个系统，执行了相同的任务，因为线程池中线程的复用，他居然获得到了用户 A 的某些信息，这显然是不行的。

上述场景用简单的代码模拟如下：

```java
public class ThreadDirtyData {
    public static void main(String[] args) {
        ExecutorService executorService = Executors.newFixedThreadPool(1);
        executorService.execute(new UserTask("userA"));                   
        executorService.execute(new UserTask("userB"));                   
                                                                  
        TimeUnit.SECONDS.sleep(3);
        executorService.shutdownNow();
    }
}

class UserData {
    String data;

    public UserData(String data) {
        this.data = data;
    }

    @Override
    public String toString() {
        return data;
    }
}

class UserContext {
    private static final ThreadLocal<UserData> CONTEXT = new ThreadLocal<>();
    public static void set(UserData data) {
        CONTEXT.set(data);
    }

    public static UserData get() {
        return CONTEXT.get();
    }

    public static void remove() {
        CONTEXT.remove();
    }
}

class UserTask implements Runnable {
    private String userName;

    public UserTask(String name) {
        userName = name;
    }

    @Override
    public void run() {
        UserData userData = UserContext.get();
        if (userData == null) {
            UserContext.set(new UserData(userName + "'s data"));
            userData = UserContext.get();
        }
        System.out.println(userData);
    }
}
```

执行结果：

```java
userA's data
userA's data
```

即使执行我们执行的任务是用户 B 的 Task，但是还是获取到了 A 的数据。

解决方案与内存泄漏相同，`ThreadLocal` 使用完，手动调用 `remove` 进行清理。

### ThreadLocal 数据向子线程传递

`ThreadLocal` 数据对于它的子线程是不可见的，但很多场景下需要在子线程中使用父线程的数据，`InheritableThreadLocal` 由此而生。

在 `Thread` 的 `init` 方法中有这么一段：

```java
if (inheritThreadLocals && parent.inheritableThreadLocals != null)     
    this.inheritableThreadLocals =                                     
        ThreadLocal.createInheritedMap(parent.inheritableThreadLocals);
```

而在父线程创建子线程时，会调用到这里的方法，从而将父线程 `inheritableThreadLocals` 中的所有元素拷贝给子线程的 `inheritableThreadLocals`。`createInheritedMap` 里面的内容比较简单，这里就不再深入了，感兴趣的可以自己去看看。

但是在线程池的环境下，由于线程都已经自己创建好了，当任务从上游的父线程提交给线程池中的线程执行时，没有调用到上面的这个 `init` 过程，自然就没法向线程池中的线程传递数据了。针对这个问题，阿里提供了一个开源的 `TransmittableThreadLocal`，详细使用和原理这里就不展开了，有需要的可以自行查阅 [官网](https://github.com/alibaba/transmittable-thread-local)。