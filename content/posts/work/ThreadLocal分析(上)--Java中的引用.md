---
title: ThreadLocal 分析（上）——Java 中的引用
slug: threadlocal-reference
summary: Java 中几种引用类型（强软弱虚），理解 Reference 的本质，结合示例加深理解。
author:
- SadBird
date: 2021-09-15T03:07:15.000+08:00
cover:
  image: https://i.loli.net/2021/09/25/HTBpP15DImOXl7A.jpg
  alt: ''
categories:
- Java
tags:
- Java
- ThreadLocal
- Reference
katex: false

---
## 4 种引用类型概述

在介绍 `ThreadLocal` 之前，首先要大致了解 Java 的几种引用类型。如下图所示，JDK 1.2 之后新增了 `Reference` 的概念，给开发人员提供了与 GC 交互的一种渠道。

![](https://i.loli.net/2021/09/25/UGOFN3m2PSzrjk6.png)

《深入理解 Java 虚拟机》中对于几种引用类型做了简要的描述：

{{< admonition type=quote title="强引用" open=true >}}
强引用（_Strongly Reference_ ）是最传统的「引用」的定义，是指在程序代码中普遍存在的引用赋值，即类似 `Object obj = new Ojbect()` 这种引用关系。无论任何情况下，只要强引用关系还存在，垃圾收集器就永远不会回收掉被引用的对象。
{{< /admonition >}}

{{< admonition type=quote  title="软引用" open=true >}}
软引用（_Soft Reference_）是用来描述一些还有用，但非必须的对象。只被软引用关联着的对象，在系统将要发生内存溢出异常前，会把这些对象列进回收范围之中进行第二次回收，如果这次回收还没有足够的内存，才会抛出内存溢出异常。在 JDK 1.2 之后提供了 `SoftReference` 来实现软引用。
{{< /admonition >}}

{{< admonition type=quote title="弱引用" open=true >}}
弱引用（_Weak Reference_）也是用来描述那些非必须对象，但是它的强度比软引用更弱一些，被弱引用关联的对象只能生存到下一次垃圾收集发生止。当垃圾收集器开始工作，无论当前内存是否足够，都会回收掉只被弱引用关联的对象。在 JDK 1.2 之后提供了 `WeakReference` 来实现弱引用。
{{< /admonition >}}

{{< admonition type=quote title="虚引用" open=true >}}
虚引用（_Phantom Reference_）也被称为「幽灵引用」或者「幻影引用」，它是最弱的一种引用关系。一个对象是否有虚引用存在，完全不会对其生存时间构成影响，也无法通过虚引用来取得一个对象实例。为对象设置虚引用关联的唯一目的只是为了能在这个对象被收集器回收时收到一个系统通知。在 JDK 1.2 之后提供了 `PhantomReference` 来实现虚引用。
{{< /admonition >}}

书中的介绍较为概括，并且没有提供相关的示例，当时第一次看这段文字时并没有搞清楚这几个引用的含义和用法。为了更好地理解，下面将通过几个示例进行分析介绍。

***

## Reference

`Reference` 中有两个重要的字段：

```java
private T referent;         /* Treated specially by GC */

volatile ReferenceQueue<? super T> queue;
```

其中， `referent` 就是指向实际对象的引用，注释中也强调了这个引用会被 GC **特殊对待**；而 `queue` 是与这个 `Reference` 关联的队列，GC 会在某些特殊阶段将当前 `Reference` 放入这个队列中，下面通过实例进行分析。

下面是一个最简单的示例，描述 `Reference` 的基本结构，这里以 `SoftReference` 为例：

```java
private static ReferenceQueue queue = new ReferenceQueue();

public void softReference() {
    Object obj = new Object();
    SoftReference<Object> soft = new SoftReference<>(obj, queue);
}
```

![](https://i.loli.net/2021/09/25/HBFQivb93jzWmhg.png)

图中，彩色部分为 GC Roots，其中 `local variables` 为虚拟机栈中的 **局部变量表**，而 `metaspace` 为 **元空间**。实线表示强引用，虚线表示弱引用。局部变量表中的 `soft` **强引用** 指向了堆中的 `SoftReference` 实例对象， `ojb` **强引用** 指向了 `Object` 实例对象。而元空间中有个名为 `queue` 的 **强引用** 指向了堆中的 `ReferenceQueue` 对象。

`SoftReference` 需要在堆中单独使用一块堆内存记录一个软引用对象，该对象的 `referent` **软指向**（这里的软指向就是指上文中的 GC **特殊对待**，本质上来说它还是一个强引用，在调用 `Reference` 的 `get` 方法时，会返回该强引用，该强引用可以赋值给 GC Roots 或其他可达的强引用，可以用这种方式为对象「续命」）实际的 `Object` 实例对象，而 `queue` **强引用** 指向了堆中的 `ReferenceQueue` 实例对象。

现在将图中的紫色强引用断开，如下所示：

```java
private static ReferenceQueue queue = new ReferenceQueue();

public void softReference() {
    Object obj = new Object();
    SoftReference<Object> soft = new SoftReference<>(obj, queue);
    // 断开强引用
    ojb = null;
}
```

![](https://i.loli.net/2021/09/25/s7MIR3DnQeEhB4r.png)

此时，对于堆中的 `Ojbect` 实例对象来说，仅仅剩下了一个 `referent` **软引用** 指向它，某些文章中称之为 **软可达对象**（_softly reachable object_），这个对象就满足了 GC 的特殊对待要求，当内存溢出时，会将其占用的堆空间回收，并将 `soft` 指向的 `SoftReference` 实例对象放入其 `queue` 关联的 `ReferenceQueue` 实例对象中。

***

## SoftReference 示例

`SoftReference` 被回收需要的前提是内存溢出，因此需要先设定虚拟机参数：

```java
/**
 * -Xms10M -Xmx10M -XX:+PrintGC 
 */
public class SoftReferenceDemo {
    private static List<SoftReference<Data>> softReferences = new ArrayList<>();
    private static ReferenceQueue queue = new ReferenceQueue();

    private static CountDownLatch countDownLatch = new CountDownLatch(1);

    public static void main(String[] args) throws InterruptedException {
        new SoftReferenceHandler().start();
        softReferenceTest();
    }

    private static void softReferenceTest() {
        int i = 0;
        while (i < 8) {
            Data data = new Data();
            SoftReference<Data> softData = new SoftReference<>(data, queue);
            System.out.printf("Add Data%s's SoftReference to list\n", data.hashCode());
            softReferences.add(softData);
            data = null;
            i++;
        }

        for (int j = 0; j < softReferences.size(); j++) {
            System.out.printf("softReferences[%d] real Object is: %s\n", j, softReferences.get(j).get() == null ?
                    "null" : "Data" + softReferences.get(j).get().hashCode());
        }

        countDownLatch.countDown();
    }

    private static class SoftReferenceHandler extends Thread {

        @Override
        public void run() {
            try {
                countDownLatch.await();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }

            Reference reference;
            while (true) {
                if ((reference = queue.poll()) != null) {
                    System.out.printf("SoftReference%s has been unreachable\n", reference.hashCode());
                }
            }
        }
    }
}

class Data {
    private static final int _1M = 1024 * 1024;
    private final byte[] data = new byte[_1M];
}
```

上述代码定义了一个存放 `SoftReference` 的列表 `ArrayList`（`softReferences`）以及与所有 `SoftReference` 相关联的引用队列 `ReferenceQueue`（`queue`）。 `CountDownLatch` 的使用是为了结果的打印顺序比较直观。

主线程中 `softReferenceTest` 方法的第一个 `while` 循环往 `softReferences` 中添加 `Data` 的 `SoftReference` ，同时将该 `Data` 的强引用断开，使得 `Data` 对象只有 `softReferences` 中的软引用。当堆中的空间无法容纳 `Data` 时（示例中设定了虚拟机相关参数，固定堆大小为 10M），会触发 OOM，而对软引用来说，在触发 OOM 之前会再进行一次 GC，对软引用的对象进行清理，而这些被清理了实际对象的软引用会被 GC 放到指定的队列 `queue` 中。第二个 `for` 循环打印 GC 完成之后 `softReferences` 中所有软引用的实际对象（即 `referent`）。这段代码输出结果大致如下：加入 7 个 `Data` 后，再添加第 8 个对象时，堆中剩余空间不足，触发了 GC，并将前 7 个 `Data` 实例对象进行了回收，腾出空间后，将第 8 个对象实例化并加入软引用列表。

```bash
Add Data1956725890's SoftReference to list
Add Data692404036's SoftReference to list
Add Data1554874502's SoftReference to list
Add Data1846274136's SoftReference to list
Add Data1639705018's SoftReference to list
Add Data1627674070's SoftReference to list
Add Data1360875712's SoftReference to list
[GC (Allocation Failure) -- 8537K->8705K(9728K), 0.0010698 secs]
[Full GC (Ergonomics)  8705K->7971K(9728K), 0.0055837 secs]
[GC (Allocation Failure) -- 7971K->8011K(9728K), 0.0009023 secs]
[Full GC (Allocation Failure)  8011K->759K(9728K), 0.0136402 secs]
Add Data1625635731's SoftReference to list
softReferences[0] real Object is: null
softReferences[1] real Object is: null
softReferences[2] real Object is: null
softReferences[3] real Object is: null
softReferences[4] real Object is: null
softReferences[5] real Object is: null
softReferences[6] real Object is: null
softReferences[7] real Object is: Data1625635731
```

`SoftReferenceHandler` 线程不停地轮训软引用关联的队列 `queue` 。当某个软引用中 `referent` 指向的实例对象由于内存不足被 GC 回收时，GC 就会将 **该软引用自身** 加入到 `queue` 中，此时`SoftReferenceHandler` 就会打印该软引用的信息。

```bash
SoftReference901252740 has been unreachable
SoftReference830969067 has been unreachable
SoftReference1954876607 has been unreachable
SoftReference818067091 has been unreachable
SoftReference1161501225 has been unreachable
SoftReference1217855145 has been unreachable
SoftReference346747888 has been unreachable
```

***

## WeakReference 示例

比起 `SoftReference` ，单纯的 `WeakReference` 示例较为简单，不要内存溢出的条件，只需要对象是 _weakly reachable object_（类比 `SoftReference`），且进行过一次 GC 即可。

```java
/**
 * -XX:+PrintGC
 */
public void weakReferenceTest() {                         
    Data data = new Data();                                       
    WeakReference<Data> weakReference = new WeakReference<>(data);
                                                                  
    while (true) {                                                
        if (weakReference.get() == null) {                        
            System.out.println("data has bean unreachable");      
            break;                                                
        }                                                         
        data = null;                                              
        System.gc();                                              
        System.runFinalization();                                 
    }                                                             
}
```

结果如下：

```java
[GC (System.gc())  7895K->896K(502784K), 0.0011793 secs]
[Full GC (System.gc())  896K->614K(502784K), 0.0050382 secs]
data has bean unreachable
```

进行一次 GC 后，弱可达对象就被清理了。

***

## WeakHashMap

`WeakHashMap` 的使用方式与 `HashMap` 类似，不同的是在 `WeakHashMap` 中，Key 的引用类型为弱引用，当该 Key 的其他所有强引用、软引用均断开时，该 Key 将在下次 GC 时被清理。基本示例如下：

```java
/**
 * -XX:+PrintGC
 */
public void weakHashMapTest() {                         
    Key key1 = new Key(1, "key1");                                                 
    Data data1 = new Data();                                                       
                                                                                   
    Key key2 = new Key(2, "key2");                                                 
    Data data2 = new Data();                                                       
                                                                                   
    WeakHashMap<Key, Data> weakHashMap = new WeakHashMap<>();                      
                                                                                   
    weakHashMap.put(key1, data1);                                                  
    weakHashMap.put(key2, data2);                                                  
                                                                                   
    System.out.println("map size before: " + weakHashMap.size());               
                                                                                   
    key1 = null;                                                                   
                                                                                   
    System.gc();                                                                   
    System.runFinalization();                                                      
                                                                                   
    System.out.println("map size after: "+ weakHashMap.size());                                     
}

class Key {                                                  
    int id;                                                  
    String name;                                             
                                                             
    public Key(int id, String name) {                        
        this.id = id;                                        
        this.name = name;                                    
    }                                                        
                                                             
    @Override                                                
    public int hashCode() {                                  
        return Objects.hashCode(id) + Objects.hashCode(name);
    }                                                        
                                                             
    @Override                                                
    public boolean equals(Object obj) {                                                                           
        if (obj == this) {                                   
            return true;                                     
        }
        
        if (!obj.getClass().equals(Key.class)) {             
            return false;                                    
        }                                                     
                                                             
        Key other = (Key)obj;                                
        return other.id == id && other.name.equals(name);    
    }                                                        
}
```

输出结果为：

```java
map size before: 2
[GC (System.gc())  8919K->2880K(502784K), 0.0016938 secs]
[Full GC (System.gc())  2880K->2663K(502784K), 0.0045395 secs]
map size after: 1
```

将 `kye1` 的强引用断开且进行GC后，`WeakHashMap` 清理了 `key1` 对应的元素，因此 `size` 为 1。

此处使用自定义的 `Key` 类型而不是直接用 `String`，是为了突出重点，如果使用 `String` 作为 Key 请一定要注意使用如下方法定义：

```java
// 不要使用这种方式: String key1 = "key1"; 这将在常量池中一直存在一个强引用指向key1，它不会被回收
String key1 = new String("key1");
```

注意，上述代码中，`WeakHashMap` 清理元素的时间是在调用 `size` 方法时。该方法如下：

```java
public int size() {
    if (size == 0)
        return 0;
    expungeStaleEntries();
    return size;
}
```

`expungeStaleEntries` 方法为核心清理方法，它在 `WeakHaspMap` 中的大部分方法中被调用（如 `size`、`put`、`get`、`remove` 等），它清理所有待清理队列（该队列由 GC 完成入队，类比 `SoftReferende`）中的 `Entry` 元素（删除链表中的节点并断开 value 的强引用）：

```java
//...

// queue是作为WeakHashMap的字段，在Map创建实例时完成创建，每个Map实例都有自己的queue
private final ReferenceQueue<Object> queue = new ReferenceQueue<>();

// ...

private void expungeStaleEntries() {
    // 从queue中获取GC过程加入到queue中的Entry，类比SoftReference示例中的queue
    for (Object x; (x = queue.poll()) != null; ) {
        synchronized (queue) {
            @SuppressWarnings("unchecked")
                Entry<K,V> e = (Entry<K,V>) x;
            // 计算该Entry在哈希表中的位置
            int i = indexFor(e.hash, table.length);

            Entry<K,V> prev = table[i];
            Entry<K,V> p = prev;
            while (p != null) {
                Entry<K,V> next = p.next;
                // 由于Entry中的Key此时为null(待清理状态)，因此此处使用==判断是否找到了该Entry，HaspMap中使用的是Key的equals方法
                if (p == e) {
                    // 找到后从链表中删除该Entry
                    // 如果为头节点，则将头节点设为该节点的next
                    if (prev == e)
                        table[i] = next;
                    else
                        prev.next = next;
                    // Must not null out e.next;
                    // stale entries may be in use by a HashIterator
                    // 清理value，断开value的强引用，以便value在下次GC时回收
                    e.value = null; // Help GC
                    // 修改size
                    size--;
                    break;
                }
                prev = p;
                p = next;
            }
        }
    }
}
```

而这个 `Entry` 就是 `WeakHashMap` 中的元素类型，它继承自 `WeakReference` 并且将 Key 作为其 `referent` 字段：

```java
private static class Entry<K,V> extends WeakReference<Object> implements Map.Entry<K,V> {
    V value;                                                                             
    final int hash; 
    // 拉链法                                                                     
    Entry<K,V> next;                                                                     
                                                                                         
    /**                                                                                  
     * Creates new entry.                                                                
     */                                                                                  
    Entry(Object key, V value,                                                           
          ReferenceQueue<Object> queue,                                                  
          int hash, Entry<K,V> next) { 
        // key作为referent传入父类构造方法，同时传入queue                                                  
        super(key, queue);                                                               
        this.value = value;                                                              
        this.hash  = hash;                                                               
        this.next  = next;                                                               
    }
    // ...
}
```

学习 `WeakHashMap` 为后续深入了解 `ThreadLocal` 奠定了基础，`ThreadLocal` 中的 `ThreadLocalMap` 与 `WeakHashMap` 原理基本一致。

### 一个代码调试的小坑

在调试 `WeakHashMap` 代码的过程中，出现了以下的情况：

将上述代码中的第二个 `size` 方法调用取消，并在该行添加断点：

```java {hl_lines=[24],linenostart=1}
/**
 * -XX:+PrintGC
 */
public void  weakHashMapTest() {                                  
    Key key1 = new Key(1, "key1");                                       
    Data data1 = new Data();                                             
                                                                         
    Key key2 = new Key(2, "key2");                                       
    Data data2 = new Data();                                             
                                                                         
    WeakHashMap<Key, Data> weakHashMap = new WeakHashMap<>();            
                                                                         
    weakHashMap.put(key1, data1);                                        
    weakHashMap.put(key2, data2);                                        
                                                                         
    System.out.println("map size before: " + weakHashMap.size());        
                                                                         
    key1 = null;                                                         
                                                                         
    System.gc();                                                         
    System.runFinalization();                                            
                                                                         
    // System.out.println("map size after: " + weakHashMap.size());         
    System.out.println("map size after: ");  // 在这行添加断点                                             
}
```

按上述分析，此时没有调用 `size` 方法及其他附带清理效果的方法，`weakHashMap` 的 `size` 应该为 2，但看下面的截图：

![](https://i.loli.net/2021/09/25/nfioMISKwR84jhH.png)

`size` 的值为 1？折腾了好久，在 `WeakHashMap` 的 `expungeStaleEntries` 方法中加了断点也找不到所以然。后来想了想以前在调试 Spring 源码时也遇到过类似的情况，结果是 idea 的调试过程自动帮我们调用一些方法以获取属性，如 `size`、`toString` 等。

为了确认该结论，先取消断点，在代码最后添加一个阻塞方法 `System.in.read();`，使用 VisualVM 查看内存：

![](https://i.loli.net/2021/09/25/EIutlU4LiAQyNpb.png)

果然，此时的 `size` 为 2，且关联队列中的 `queueLength` 为 1，表示队列中有元素待清理。

***

## PhantomReference

`PhantomReference` 在使用方法上与 `SoftReference`、`WeakReference` 稍有不同，查看它的源码：

```java
public class PhantomReference<T> extends Reference<T> {

    /**
     * Returns this reference object's referent.  Because the referent of a
     * phantom reference is always inaccessible, this method always returns
     * <code>null</code>.
     *
     * @return  <code>null</code>
     */
    public T get() {
        return null;
    }

    /**
     * Creates a new phantom reference that refers to the given object and
     * is registered with the given queue.
     *
     * <p> It is possible to create a phantom reference with a <tt>null</tt>
     * queue, but such a reference is completely useless: Its <tt>get</tt>
     * method will always return null and, since it does not have a queue, it
     * will never be enqueued.
     *
     * @param referent the object the new phantom reference will refer to
     * @param q the queue with which the reference is to be registered,
     *          or <tt>null</tt> if registration is not required
     */
    public PhantomReference(T referent, ReferenceQueue<? super T> q) {
        super(referent, q);
    }

}
```

可以发现，它的构造函数必须接收一个 `ReferenceQueue` 参数，且它的 `get` 方法永远返回 `null`（注意， `PhantomReference` 仍然持有一个 `referent`，只是它不对外公开）。

既然永远获得不到 `referent`，那么 `PhantomReference` 即使从 `queue` 中获取到了该对象，也无法改变其实际目标对象的命运，它最终将被回收。

[Why Garbage Collection?](https://www.artima.com/insidejvm/ed2/gcP.html)

在阅读上面参考文章的时候发现了这段描述：

{{< admonition type=quote title="Phantom Reference" open=true >}}
Note that whereas the garbage collector enqueues soft and weak reference objects when their referents are leaving the relevant reachability state, it enqueues phantom references when the referents are entering the relevant state. You can also see this difference in that the garbage collector clears soft and weak reference objects before enqueueing them, but not phantom reference objects. Thus, the garbage collector enqueues soft reference objects to indicate their referents have just left the softly reachable state. Likewise, the garbage collector enqueues weak reference objects to indicate their referents have just left the weakly reachable state. But the garbage collector enqueues phantom reference objects to indicate their referents have entered the phantom reachable state. Phantom reachable objects will remain phantom reachable until their reference objects are explicitly cleared by the program.
{{< /admonition >}}

也就是说，GC 将 `SoftReference`、`WeakReference` 入队的时机是在清理完它们的目标对象之后，亦即它们的目标 _softly reachable_、 _weakly reachable_ 状态结束之后，而 `PhantomReference` 的入队时机是在它的目标对象被清理之前，亦即它的目标对象刚进入 _phantom reachable_ 时，它将一直保持这种状态，直到他们的目标对象被应用程序显示清理（调用 `clear` 方法）或被 GC 回收。

### PhantomReference 应用

`PhantomReference` 既然无法对目标对象产生实际的影响，那么它的作用就是在对象进入 _phantom reachable_ 状态后，利用 `queue` 进行最后的资源清理工作（_pre-mortem clean_）。

下面以 Java NIO 中的 `DirectByteBuffer` 为例进行简单说明。

`DirectByteBuffer` 分配的是堆外内存，该空间无法通过 GC 进行回收，因此在 `DirectByteBuffer` 对象被回收时，需要通过另外的手段将该对象分配的堆外空间进行回收。

`Reference` 中除了 `referent` 和 `queue` 两个重要字段外，还有个一个静态字段与将要介绍的清理工作息息相关：

```java
/* List of References waiting to be enqueued.  The collector adds
 * References to this list, while the Reference-handler thread removes
 * them.  This list is protected by the above lock object. The
 * list uses the discovered field to link its elements.
 */
private static Reference<Object> pending = null;
```

通过注释能够了解到，它的作用是维护一个链表，链表中的对象是待入队（放入 `queue` 中）的 `Reference` 对象。GC 将 `Reference` 对象放入这个链表中，而有一个后台线程 `Reference-handler` 从这个链表中移除 `Reference` 并将其放入 `queue` 中。

`Reference-handler` 在 `Reference` 中的定义和使用如下：

```java
/* High-priority thread to enqueue pending References
 */
private static class ReferenceHandler extends Thread {

    // ...

    ReferenceHandler(ThreadGroup g, String name) {
        super(g, name);
    }

    public void run() {
        while (true) {
            // 具体执行的任务
            tryHandlePending(true);
        }
    }
}

// ...

static {                                                                  
    ThreadGroup tg = Thread.currentThread().getThreadGroup();             
    for (ThreadGroup tgn = tg;                                            
         tgn != null;                                                     
         tg = tgn, tgn = tg.getParent());                                 
    Thread handler = new ReferenceHandler(tg, "Reference Handler");       
    /* If there were a special system-only priority greater than          
     * MAX_PRIORITY, it would be used here                                
     */                                                                   
    handler.setPriority(Thread.MAX_PRIORITY);                             
    handler.setDaemon(true);                                              
    handler.start();                                                                                                                                                                                  
}
```

`Reference` 在静态代码块中启动了该线程，也就是说只要 `Reference` 被加载，就会启动该线程，线程的核心任务为 `tryHandlePending`，如下：

```java
static boolean tryHandlePending(boolean waitForNotify) {                                      
    Reference<Object> r;                                                                      
    Cleaner c;                                                                                
    try {                                                                                     
        synchronized (lock) {                                                                 
            if (pending != null) {                                                            
                r = pending;                                                                  
                // 'instanceof' might throw OutOfMemoryError sometimes                        
                // so do this before un-linking 'r' from the 'pending' chain... 
                // 如果为Cleaner类型，则赋值给c               
                c = r instanceof Cleaner ? (Cleaner) r : null;                                
                // unlink 'r' from 'pending' chain                                            
                pending = r.discovered;                                                       
                r.discovered = null;                                                          
            } else {                                                                          
                // The waiting on the lock may cause an OutOfMemoryError                      
                // because it may try to allocate exception objects.                          
                if (waitForNotify) {                                                          
                    lock.wait();                                                              
                }                                                                             
                // retry if waited                                                            
                return waitForNotify;                                                         
            }                                                                                 
        }                                                                                     
    } catch (OutOfMemoryError x) {                                                            
        // Give other threads CPU time so they hopefully drop some live references            
        // and GC reclaims some space.                                                        
        // Also prevent CPU intensive spinning in case 'r instanceof Cleaner' above           
        // persistently throws OOME for some time...                                          
        Thread.yield();                                                                       
        // retry                                                                              
        return true;                                                                          
    } catch (InterruptedException x) {                                                        
        // retry                                                                              
        return true;                                                                          
    }                                                                                         
                                                                                              
    // Fast path for cleaners                                                                 
    if (c != null) {
        // c不为空，表示需要执行清理操作                                                                          
        c.clean();                                                                            
        return true;                                                                          
    }                                                                                         
    
    // 如果该引用对象的 queue 不为空，则执行入队操作                                                                                          
    ReferenceQueue<? super Object> q = r.queue;                                               
    if (q != ReferenceQueue.NULL) q.enqueue(r);                                               
    return true;                                                                              
}
```

重点看代码中的中文注释部分，方法的主要工作就是执行 `Cleaner` 的 `clean` 操作，并将引用对象入队。

`Cleaner` 的定义：

```java
public class Cleaner extends PhantomReference<Object> {
    // ...
    private static final ReferenceQueue<Object> dummyQueue = new ReferenceQueue();
    private final Runnable thunk;
 
    // Cleaner本身也是双向链表结构
    private Cleaner next = null; 
    private Cleaner prev = null;

    // 静态字段，存储Cleaner队列头节点
    private static Cleaner first = null;

    // 创建cleaner的工厂方法，将新的Cleaner插入静态队列头部
    public static Cleaner create(Object var0, Runnable var1) { 
        //    
        return var1 == null ? null : add(new Cleaner(var0, var1));
    }
    // ...

    public void clean() {                                                                        
        if (remove(this)) {                                                                      
            try {      
                // 重点                                                                          
                this.thunk.run();                                                                
            } catch (final Throwable var2) {                                                     
                AccessController.doPrivileged(new PrivilegedAction<Void>() {                     
                    public Void run() {                                                          
                        if (System.err != null) {                                                
                            (new Error("Cleaner terminated abnormally", var2)).printStackTrace();
                        }                                                                        
                                                                                             
                        System.exit(1);                                                          
                        return null;                                                             
                    }                                                                            
                });                                                                              
            }                                                                                                                                                                    
        }                                                                                        
    }
}
```

`Cleaner` 继承自 `PhantomReference`，除了关联的队列外，还包含了一个 `Runable` 类型的 `thunk` 字段，这个字段就是底层的清理工，`clean` 最核心的工作就是执行该字段的 `run` 方法。因此，`Reference` 中的辅助线程除了入队操作外，最主要的任务就是执行这个 `thunk` 的 `run` 方法。`Cleaner` 可以理解为一个具有清理功能的 `PhantomReference`。

现在回到 `DirectByteBuffer` 中，先看看它的构造方法：

```java
DirectByteBuffer(int cap) {                   // package-private                                                                          
    // ...
 
    // 重点                                                               
    cleaner = Cleaner.create(this, new Deallocator(base, size, cap));   
    att = null;                                                                                                                                                                                                
}
```

忽略构造函数中具体分配内存的代码，这里重点看与 `DirectByteBuffer` 对象关联的 `cleaner`，它的 `PhantomReference` `referent` 字段指向当前 `DirectByteBuffer` 对象，并且它的清理工 `thunk` 字段为 `Deallocator`。`Deallocator` 为 `DirectByteBuffer` 的静态内部类，其定义如下：

```java
private static class Deallocator                                
    implements Runnable                                         
{                                                               
                                                                
    private static Unsafe unsafe = Unsafe.getUnsafe();          
                                                                
    private long address;                                       
    private long size;                                          
    private int capacity;                                       
                                                                
    private Deallocator(long address, long size, int capacity) {
        assert (address != 0);                                  
        this.address = address;                                 
        this.size = size;                                       
        this.capacity = capacity;                               
    }                                                           
                                                                
    public void run() {                                         
        if (address == 0) {                                     
            // Paranoia                                         
            return;                                             
        }
        // 这里就是最核心的清理工作                                                       
        unsafe.freeMemory(address);                             
        address = 0;                                            
        Bits.unreserveMemory(size, capacity);                   
    }                                                           
                                                                
}
```

`Deallocator` 最终使用 `Unsafe` 完成了堆外内存的释放。

总结一下清理的原理：

1. 随着`Reference` 类被加载，`Reference-handler` 后台线程被启动，它轮循 `pending` 链表，执行 `Cleaner` 的 `clean` 工作。
2. `Cleaner` 继承自 `PhantomReference`，它会被 GC 识别，在进入 _phantom reachable_ 状态前会被GC先放入 `pending` 队列。
3. `clean` 方法最终执行 `Cleaner` 的 `thunk.run()` 进行清理。
4. `DirectByteBuffer` 在创建的同时关联了一个 `Cleaner`，该 `Cleaner` 中的 `thunk` 为 `Deallocator`，`Deallocator` 使用 `Unsafe` 完成了堆外内存的清理释放。

![](https://i.loli.net/2021/09/25/sCtE4jeSyIlf7A5.png)

再从 `DirectByteBuffer` 的角度来看看清理的过程：

1. `DirectByteBuffer` 创建时关联了一个 `Cleaner`，该 `Cleaner` 的 `thunk` 为 `Deallocator`。
2. 当 `DirectByteBuffer` 强引用断开时，GC 识别到 `Cleaner`，并将 `Cleaner` 加入到 `Reference` 的静态链表 `pending` 中。
3. `Reference` 的后台线程 `Reference-handler` 从 `pending` 链表中获取到该 `Cleaner`，并调用 `clean` 方法。
4. `clean` 方法最终调用 `Deallocator` 的 `run` 方法，通过 `Unsafe` 完成了清理工作。