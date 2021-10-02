---
title: HashMap 基础
slug: hashmap-source
summary: Java 中的 HashMap，分析其基本结构及部分源码。
author:
- SadBird
date: 2021-08-29T04:08:04.000+08:00
cover:
  image: https://i.loli.net/2021/09/25/5pcWZw1uk8lVvzf.png
  alt: HashMap
categories:
- Java
tags:
- HashMap
katex: false

---
HashMap 是 Java 程序员使用频率最高处理的数据结构之一，线程不安全，允许 null 作为键和值。HashMap 对 Key 要求是不可变类型的，设想如果是可变类型的 Key，那么在使用过程中很有可能对 Key 对象进行了修改，导致哈希值发生变化，最终无法定位到 HashMap 中的元素。

Java8 对 HashMap 进行了大修改，为了防止链表过大，影响插入和查找的效率（链表过大时，时间复杂度为 _O(n)_），当链表元素的数量超过某个值时，自动将链表转换为红黑树（时间复杂度为 _O(log n)_，注意这个地方有个坑，文章最后会介绍）。

***

## 基础结构

![](https://i.loli.net/2021/09/25/iDejz2BNJY79x3P.png)

简单来说，HashMap 就是一个数组，数组中的每个位置被称做 **bin** 或者 **bucket**（中文翻译为 **桶**），每个 **桶** 中都存放着一些 **Node**（结点）。当一个桶中的 Node 数量较少的时候，使用链表对 Node 进行存储；当一个桶中的 Node 数量超过某个阈值的时候，就会将链表转换为红黑树，这个操作叫做 **treeify**，即「树化」，注意树化操作还需要满足另外一个条件，就是数组的长度要超过 `MIN_TREEIFY_CAPACITY = 64`，否则它的操作就不是树化，而是 **resize**。同样，在 **resize** 操作的时候，也会判断一个桶中的 Node 数量是否会少于某个阈值，如果满足条件，则会重新将红黑树转换回链表，这个操作称为 **untreeify**。

首先介绍几个重要的参数：

* _capacity_：数组当前的最大长度，即为桶数量的最大值，最多存放多少个桶，这个数值在第一次添加元素的时候初始化为 16。满足一定条件时，会扩容。**这个长度必须是2的整数次方(16, 32, 64, 128 ...)**，稍后在扩容章节会详细讲解其中的原因。
* _loadFactor_：负载因子，它搭配 _capacity_ 使用，判断扩容条件，默认值为 0.75。
* _size_：当前 HashMap 中的 Node 总数量。
* _threshold_：扩容阈值，它的值为 `loadFactor * capacity`，**重点：当 _size_ 的值大于 _threshold_ 值时，进行扩容**。

***

## 源码分析

### table 数组

这就是图中所示的那个数组，类型为 `Node`：

```java
transient Node<K,V>[] table;
```

再看看 `Node` 的内容，很明显，就是一个简单的链表结构：

```java
static class Node<K,V> implements Map.Entry<K,V> {
    final int hash; // 当前节点中Key的hash值，注意不是hashCode()的返回值，具体是什么会在扩容中介绍
    final K key; // 键
    V value; // 值
    Node<K,V> next; // 下一个结点
 
    ...
}
```

当然还有其他类型的 Node，如 TreeNode，这里就不展示了。

### put 方法

当需要将元素存入 HashMap 时，我们使用 `V put(K, V)` 方法，它的作用是，若 key 已经存在，则用新的 value 替换原来的 value；否则插入新的 key 和 value，返回 null（返回值为 null 也可以说明当前 key 在 map 中对应的值为 null）。它的源码如下：

```java
public V put(K key, V value) {
    return putVal(hash(key), key, value, false, true);
}
```

它调用了 `V putVal(int, K, V, boolean, boolean)` 方法，注意，这里还调用了一个 `hash` 方法，具体将在稍后的扩容中介绍，这里只需要明白它的作用是为了让 Node 分布更均匀。`putVal` 方法的源码如下：

```java
final V putVal(int hash, K key, V value, boolean onlyIfAbsent,
                   boolean evict) {
    Node<K,V>[] tab; Node<K,V> p; int n, i;
    // 1. 当数组为空或者数组长度为0的时候，延迟初始化
    if ((tab = table) == null || (n = tab.length) == 0)
        // 此时，resize将使用16作为初始容量，创建初始数组，n = size = 16，threshold = 16 * 0.75 = 12
        n = (tab = resize()).length;
    // 2. 将hash映射到数组长度内，得到索引值，并判断tab在该处是否已经有Node
    if ((p = tab[i = (n - 1) & hash]) == null)
        // 若没有Node，则表明此次插入的Node为tab[i]这个桶上的第一个Node，直接将该Node赋值给tab[i]
        tab[i] = newNode(hash, key, value, null);
    // 3. 数组不为空，且当前桶处已有其他Node
    else {
        Node<K,V> e; K k;
        // 判断待插入的key与桶中的第一个Node的key是否相等，若相等，则稍后直接覆盖
        if (p.hash == hash &&
            ((k = p.key) == key || (key != null && key.equals(k))))
            e = p;
        // 如果是红黑树结构，则进行红黑树的put操作
        else if (p instanceof TreeNode)
            e = ((TreeNode<K,V>)p).putTreeVal(this, tab, hash, key, value);
        // 如果是链表结构
        else {
            // 遍历链表，直到找到元素，或者到达表尾
            for (int binCount = 0; ; ++binCount) {
                // 到达表尾，没有找到与传入的key相等(hash和equals判断)的Node，则插入新结点
                if ((e = p.next) == null) {
                    p.next = newNode(hash, key, value, null);
                    // 若插入新结点后，当前桶中的链表结点数超过了8个，则转换为红黑树
                    if (binCount >= TREEIFY_THRESHOLD - 1) // -1 for 1st
                        treeifyBin(tab, hash);
                    break;
                }
                // 在链表中找到了与传入key相等的Node，则直接退出遍历，并在稍后将值直接覆盖
                if (e.hash == hash &&
                    ((k = e.key) == key || (key != null && key.equals(k))))
                    break;
                p = e;
            }
        }
        // 4. e不为空表示HashMap中已有相同key的Node，直接将旧值替换成新值
        if (e != null) { // existing mapping for key
            V oldValue = e.value;
            if (!onlyIfAbsent || oldValue == null)
                e.value = value;
            afterNodeAccess(e);
            // 返回旧值
            return oldValue;
        }
    }
    // 修改后，这个值递增，确保fast-fail机制
    ++modCount;
    // 5. size自增，若此时size的值大于threshold，则进行扩容
    if (++size > threshold)
        resize();
    afterNodeInsertion(evict);
    return null;
}
```

着重介绍其中几个关键流程（以下编号与代码注释中的编号对应）：

1. 判断当前的数组是否为空（或长度为 0），若满足条件，则说明当前 put 的 Node 为当前 HashMap 对象中的第一个 Node，就调用 `resize()` 方法创建一个数组。在之前的 Java 版本中，这个创建数组的操作都是在构造函数中完成的，这就导致了，即使不往 HashMap 里存东西，它也会占据内存空间。这里延迟到了添加第一个元素的时候，确保即使 new 了一个 HashMap，且不往里面存东西，它也不会占据额外的内存空间。
2. 这里先将一个 hash 值（32 位 int 值）映射到数组的索引范围内，常见的做法是对素数取余，但这里利用位运算进行 `(n - 1) & hash`（稍后再介绍这个操作），这里将这个索引值记为 _index_。随后判断这个索引位置上的桶是否已经有 Node 存在，若没有，则表示当前插入 Node 为该桶中的第一个 Node，直接进行赋值操作 `tab[index] = newNode...`。
3. 若 index处 的桶中已有 Node，则需要进一步的判断：
   * 若index处桶中的第一个 Node 的 key 就与待插入的 key 相等（hash 和 equals 判断），则不用进行后面的判断，准备进行直接的值覆盖。
   * 否则，判断当前 Node 的类型，若是 TreeNode，表明它是红黑树，则进行红黑树的 put 操作。
   * 否则，表示当前 Node为 普通链表类型，对当前的链表进行遍历操作。若找到了 key 相等的 Node，就 break 结束遍历，准备直接覆盖值；若找不到，则在链表尾插入相应的新 Node，并判断当前链表的长度，若超过了阈值 `TREEIFY_THRESHOLD`（8），则将链表树化，转化成红黑树结构。
4. 在上述的插入过程中，若找到了 key 与待插入 key 相等的 Node，则直接用新值对该 Node 的值进行覆盖，并直接返回 **旧值**，结束整个插入过程。
5. 若没有找到 key 与待插入 key 相等的 Node，则表明进行了插入操作，此时 Node 的总数量增加，即 size 自增。此时判断 size 的值是否大于扩容域值，若满足条件，则进行扩容，这个操作将在下面进行具体介绍。

值得注意的一点是，`treeifyBin` 这个将列表转换为红黑树的方法，它在数组的总容量较小的情况下并不会真正将链表转换为红黑树，而是先进行 `resize` 扩容操作，具体代码如下：可以看到，在 _length_ 小于 `MIN_TREEIFY_CAPACITY`（64）的情况下，它直接调用了 `resize()` 方法，并没有直接将链表转换为树：

```java
final void treeifyBin(Node<K,V>[] tab, int hash) {
    int n, index; Node<K,V> e;
    if (tab == null || (n = tab.length) < MIN_TREEIFY_CAPACITY)
        resize();
    else if (...) {
        ...
    }
}
```

### 扩容

**扩容（resize）** 就是重新计算容量、扩大数组容量以及将已有元素重新放置。若向 HashMap 对象里不停的添加元素，而 HashMap 对象内部的数组存储的元素达到一定数量时，就需要扩大数组的长度，以便能装入更多的元素。当然 Java 里的数组是无法自动扩容的，方法是使用一个新的、更大的数组代替已有的容量小的数组。

当然，「能够装入更多的元素」这个说法不太严谨，其实就算不扩容，理论上也能不停地加入元素，因为链表和红黑树都能无限扩展：

![](https://i.loli.net/2021/09/25/KRiqk1Qf3bwYPES.png)

HashMap 的查询和插入效率很高，理论上能达到常数级别，但当每个桶中的 Node 都非常多，查询效率和插入效率就会大打折扣，每次查询或者插入需要比较的次数迅速增加，链表会退化为 _O(n)_（JDK8 之前），而红黑树也需要 _O(logn)_。因此，当 Node 过多，可以通过扩容的方式，将集中在同若干个桶中的Node分散到更多的桶中，用空间换取时间。

#### (length - 1) & hash

关于这个容量，首先要介绍一个重要的结论，它的值必须是一个2的正整数次幂。

* 当使用默认的构造方法（无参数）创建 HashMap 时，默认的初始容量为 16（如上面所说，是在插入第一个元素时分配的）。
* 如果使用的是带参数的构造方法（带 int 值的），那么就会先计算大于等于该值的、最小的一个 2 的正整数次幂（比如传入的 int 值为 17，2^4 < 17 < 2^5，则其初始容量为 2^5 = 32），同样是延迟到第一次 put 时才创建数组。下面是相关的代码：

```java
/**
* The default initial capacity - MUST be a power of two. 默认初始容量-必须为2的幂
*/
static final int DEFAULT_INITIAL_CAPACITY = 1 << 4; // aka 16
...
public HashMap(int initialCapacity, float loadFactor) {
    if (initialCapacity < 0)
        throw new IllegalArgumentException("Illegal initial capacity: " + initialCapacity);
    if (initialCapacity > MAXIMUM_CAPACITY)
        initialCapacity = MAXIMUM_CAPACITY;
    if (loadFactor <= 0 || Float.isNaN(loadFactor))
        throw new IllegalArgumentException("Illegal load factor: " +
                                           loadFactor);
    this.loadFactor = loadFactor;
 
    // tableSizeFor()方法将返回大于等于initialCapacity的2的整数幂，并将这个返回值赋值给threshold
    // 在第一次调用resize()方法时，会将这个threshold作为初始容量创建数组，这个地方用法比较特殊
    // 后续操作中threshold将一直作为判断是否扩容的标准，它的值为capacity*loadFactor
    this.threshold = tableSizeFor(initialCapacity);
}
```

所以为什么一定要是 2 的正整数次幂呢？这里又需要回顾上面 `putVal` 中，注释编号为 2 的代码处：

```java
... n = tab.length ...
...
if ((p = tab[i = (n - 1) & hash]) == null)
...
```

上述代码中 `i = (n - 1) & hash` 很明显是在获取哈希值为 `hash` 的 key 所对应的数组索引（替代求余操作），其中的 `n` 值为数组的 `length`，所以这个索引实际上就是 `(length - 1) & hash`。
将两个 int 类型的正整数进行按位与计算，结果不会超过两个数中的最小者，所以上面的操作结果不会超过 `length - 1`，即结果范围为：_\[0, length - 1\]_，这就将 `hash` 映射到了数组的索引中。如下图所示，假定容量为 64：

![](https://i.loli.net/2021/09/25/MfD5dwZ6tgFCrm1.png)

随之而来的一个问题是，那为什么一定要是 2 的整数幂呢？任意一个容量 `(randomLength - 1) & hash` 进行按位与不也可以得到不超过容量的索引吗？现在假设不是 2 的整数次幂，比如 62，如下图所示。绿色位置的值为 0，此时进行按位与操作，不管 `hash` 中的红色部分值是 0 还是 1，计算结果中相应位置上的值都是 0。这意味着，计算后的索引结果中，不能取得 _\[0, 61\]_ 这个区间内的所有值，有些值是不可能得到的，比如 2，3 等等（因为结果的第二位是 0，所以不可能是 2 和 3），也即 HashMap 中会有许多桶始终为空，造成了链表或者红黑树的高度增加，效率降低。因此，`(length - 1)` 的二进制表示需要全部为 1，也即 `length` 必须是 2 的整数幂。

![](https://i.loli.net/2021/09/25/sUHjzbtfPOIMY2v.png)

#### int hash(Object) 方法

在 `put` 方法介绍时，还留了一个坑，那就是 `int hash(Object)` 方法，有了刚介绍的知识，就可以简单了解一下了：

```java
// put方法调用了putVal方法，putVal方法的第一个参数使用了hash方法，因此实际上传入putVal方法的hash值其实是经过处理的hashCode()
public V put(K key, V value) {
    return putVal(hash(key), key, value, false, true);
}
 
// hash方法
static final int hash(Object key) {
    int h;
    return (key == null) ? 0 : (h = key.hashCode()) ^ (h >>> 16);
}
```

`putVal` 方法的第一个参数使用了 `int hash(Object)` 方法，因此实际上传入 `putVal` 方法的 `hash` 值其实是经过再处理的哈希值，而不是直接使用我们代码中编写的 `hashCode()`。这个方法是对程序员重写的 `hashCode()` 的一种优化，因为程序员编写的 `hashCode()` 目的是尽量让返回值在 int（32位）范围内尽可能不同。然而，根据上一部分的分析，在数组容量 `length` 较小时，我们往往只使用到了低位的 `hash` 值，高位的 `hash` 值被忽略（此时 `length - 1` 的二进制高位均为 0），这很可能导致冲突较多。因此，`int hash(Object)` 方法让高位与低位进行了一次异或运算，保证高位的值也能够体现在 `hash` 值中，能够有效减少冲突。

#### resize() 方法

啥都不说，先上源码：

```java
final Node<K,V>[] resize() {
    // 扩容前的数组
    Node<K,V>[] oldTab = table;
    // 扩容前的容量，因为这个方法在第一次put的时候也会被调用，它需要考虑到为null的情况
    int oldCap = (oldTab == null) ? 0 : oldTab.length;
    // 扩容前的扩容阈值threshold
    int oldThr = threshold;
    // 扩容后的新容量和新阈值
    int newCap, newThr = 0;
    // 如果旧的容量大于0，表示不是第一次put元素，HashMap中已有数据
    if (oldCap > 0) {
        if (oldCap >= MAXIMUM_CAPACITY) {
            threshold = Integer.MAX_VALUE;
            return oldTab;
        }
        // 1. 容量翻倍
        else if ((newCap = oldCap << 1) < MAXIMUM_CAPACITY &&
                 // 如果旧容量比16小，则使用后面的方式计算新扩容阈值
                 oldCap >= DEFAULT_INITIAL_CAPACITY)
            // 同时，新的容量阈值为旧容量阈值的两倍(因为新的容量翻倍了)
            newThr = oldThr << 1; // double threshold
    }
    // 上文提到过，当使用带int参数的HaspMap构造方法时，就在这个地方将threshold作为初始化数组的大小
    // 注意此处没有指定newThr，则时候稍后的方法进行计算
    else if (oldThr > 0) // initial capacity was placed in threshold
        newCap = oldThr;
    else {               // zero initial threshold signifies using defaults
        // 同样在上文提到过，当使用无参数的HashMap构造方法时，就在这里指定默认的初始数组大小
        newCap = DEFAULT_INITIAL_CAPACITY;
        newThr = (int)(DEFAULT_LOAD_FACTOR * DEFAULT_INITIAL_CAPACITY);
    }
    // 针对上文中没有计算newThr的情况，统一在这进行计算
    if (newThr == 0) {
        // newThr的值为capacity * loadFactor
        float ft = (float)newCap * loadFactor;
        newThr = (newCap < MAXIMUM_CAPACITY && ft < (float)MAXIMUM_CAPACITY ?
                  (int)ft : Integer.MAX_VALUE);
    }
    // 将计算后的新阈值赋给threshold，表示扩容后的阈值
    threshold = newThr;
    // 2. 创建大小为新容量的数组
    @SuppressWarnings({"rawtypes","unchecked"})
    Node<K,V>[] newTab = (Node<K,V>[])new Node[newCap];
    // 将HashMap中的数组替换为新数组
    table = newTab;
    // 将旧数组中的Node往新数组中搬
    if (oldTab != null) {
        // 遍历旧数组中的各个桶
        for (int j = 0; j < oldCap; ++j) {
            Node<K,V> e;
            if ((e = oldTab[j]) != null) {
                oldTab[j] = null;
                // 如果桶中只有一个Node，则使用(length - 1) & hash的方法，直接将这个Node存到新数组的相应位置
                if (e.next == null)
                    newTab[e.hash & (newCap - 1)] = e;
                // 如果是红黑树，则进行红黑树相关操作
                else if (e instanceof TreeNode)
                    ((TreeNode<K,V>)e).split(this, newTab, j, oldCap);
                // 3. 如果是链表，则遍历链表中的所有结点，确定其在新数组中的位置
                else { // 4. preserve order
 
                    // 5. 将旧桶中的链表结点分成两类，分别组成两个链表，然后分别插入到新数组的特定桶中
                    Node<K,V> loHead = null, loTail = null; // 低位置的链表，记为lo
                    Node<K,V> hiHead = null, hiTail = null; // 高位置的链表，记为hi
                    Node<K,V> next;
                    do {
                        next = e.next;
                        // 骚操作，表示e所指向的结点在新数组中的下标和旧数组中的下标相同，把这些Node放到lo链表中，原因还是因为数组容量为2的整数幂
                        if ((e.hash & oldCap) == 0) {
                            if (loTail == null)
                                loHead = e;
                            else
                                loTail.next = e;
                            loTail = e;
                        }
                        // 否则，表示e所指向的结点在新数组中的下标是旧数组中下标加上旧数组的容量，把这些Node放到hi链表中
                        else {
                            if (hiTail == null)
                                hiHead = e;
                            else
                                hiTail.next = e;
                            hiTail = e;
                        }
                    } while ((e = next) != null);
                    // 分别将两个链表插入到低位和高位桶中
                    if (loTail != null) {
                        loTail.next = null;
                        newTab[j] = loHead;
                    }
                    if (hiTail != null) {
                        hiTail.next = null;
                        newTab[j + oldCap] = hiHead;
                    }
                }
            }
        }
    }
    return newTab;
}
```

还是和前面的 `putVal` 一样，列举几个关键点进行分析：

1. 这里不讨论数组为空的情况，假设现在 HashMap 中已经有许多 Node 了，并且在插入完成某个新的 Node 后，触发了扩容（忘记了？快回头去看看 `putVal` 方法的第 5 点），此时，把新的容量和新的扩容阈值都设为原来的 2 倍。
2. 随后，创建一个大小为新容量的数组，并将 HashMap 中的 table 重新赋值（这个也忘记了?请回到源码分析的开头部分），这时候就已经完成了容量的翻倍，但旧数组中的 Node 都还没搬过来。
3. 由于红黑树较为复杂 ~~(我还不会)~~，这里只分析链表的情况。
4. 请注意这个地方有个很显眼的 `preserve order`，这个是 JDK 开发人员的注释，为什么要特别加这么一条注释呢？其实是因为这个地方在 Java8 之前有个不算坑的坑，这里就稍微说明一下：由于 Java8 之前，采用的是链表的头插法，因此在扩容过程中，有可能导致链表结点之间的顺序改变，这在一般情况下并不是什么问题，但在多线程环境下，有概率出现循环链表，从而出现死循环的情况。有人就把这个问题反馈给了 JDK 开发人员，但是，HashMap 的说明中明确指出了，HashMap 是线程不安全的，所以当时也并没有对这个问题进行解决（这纯粹就是使用者的锅）。但是到了 Java8，这个问题被重写 HashMap 的 JDK 开发人员顺手给解决了，他特地在这标注了一个  `preserve order`，表示已经解决了那个坑，有兴趣的话可以访问这个链接 [JAVA HASHMAP的死循环](https://coolshell.cn/articles/9606.html)。
5. 这个位置就是要开始将旧数组中的链表搬到新数组的桶中了。与 Java8 之前的方法不同，在这段代码中，没有对每个 Node 重新进行 hash 值的计算（为了在新的数组中确定Node的索引值），而是使用了 `(e.hash & oldCap) == 0` 这么一个熟悉的条件判断进行索引位置的确定。啧，怎么又是个按位与操作？之前我们使用过 `hash & (length - 1)` 确定索引值，而这里的 `(e.hash & oldCap) == 0` 又是个什么操作？仔细分析，不难发现，`oldCap` 表示扩容前的容量，是一个 2 的整数幂的值，所以它的二进制表示为某个特定位上的值为 1，其余位置全是 0，用它和结点的 hash 值进行按位与，就是判断结点的 `hash` 值在那个对应的特定位置上是否为 0。那这又有什么用呢？结合下面图片进行分析：

![](https://i.loli.net/2021/09/25/ZV6nXycJaRqGLzY.png)

图中，上面两个二进制数表示的是扩容前的某个结的 `hash` 值和 `oldCap - 1`；下面两个二进制数表示的是扩容后的 **同一个** 结点的 hash 值和 `newCap - 1`。通过观察，由于扩容时容量加倍，使得 `newCap - 1` 比 `oldCap - 1` 多出了一位 1（绿色的部分），因此进行 `hash & (length - 1)` 时，`hash` 中参与计算的位也多了一位（红色的部分）。这个位置 `hash` 的值不是 0 就是 1，也就是说，`hash & (newCap - 1)` 和 `hash & (oldCap - 1)` 的结果就差在这一位上（因为是计算同一个结点在新老数组中的索引位置，参与计算的 `hash` 值是相同的，而且容量减 1 的值在各个位上都是 1）。所以我们就可以做出一个判断：

* 当红色部分的值为 0 时，新数组中的索引值 newIndex 和老数组中的索引值相同，即 `newIndex = oldIndex`。
* 当红色部分的值为 1 时，新数组中的索引值 newIndex 是老数组中的索引值加上老数组的容量 `newIndex = oldIndex + oldCap`。

有了这些分析，我们现在就可以知道，`(e.hash & oldCap) == 0` 这个操作判断的就是新增位上（红色的部分）`hash` 值的情况（0或1）。随后，把所有判断结果为 0 的结点连接成一个链表 `lo`，把所有判断结果为 1 的结点连接成一个链表 `hi`。最后，把 `lo` 放到新数组中索引与老数组相同的位置，而 `hi` 则被放入 `[oldIndex + oldCap]` 的位置。

### HashMap 和 Comparable

最后，还有一个坑要填（即使实际开发中并不会遇到）。虽然对于红黑树的了解不算深入，但至少知道它是个动态平衡的二叉查找树，**比大小** 是它核心的一个操作。随之而来的一个问题就是，HashMap 不像 TreeMap 要求 Key 实现 Comparable 或者构造时提供 Comparator，它对于 Key 没有这方面的限制，那它内部是通过什么来进行比较呢？下面先进行一个实验：

```java
class TestKey {
    private String id;
    private int number;

    public TestKey(String id, int number) {
        this.id = id;
        this.number = number;
    }

    /**
     * 故意写个冲突的hashCode
     * @return 返回固定的hashCode
     */
    @Override
    public int hashCode() {
        return 5;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        TestKey testKey = (TestKey) o;
        return number == testKey.number &&
                id.equals(testKey.id);
    }
}

public class HashMapDemo {
    private static final int COUNT = 500_000;
    public static void main(String[] args) {
        HashMap<TestKey, Integer> testMap = new HashMap<>();
        Integer testValue = -1;
        TestKey key = null;
        long startTime = System.currentTimeMillis();
        for (int i = 0; i < COUNT; i++) {
            key = new TestKey("test", i);
            testMap.put(key, i);
        }
        long endTime = System.currentTimeMillis();
        System.out.println("插入耗时:" + (endTime - startTime));
    }
}
```

执行结果：

```java
插入耗时:4875921
```

上述代码中的 `TestKey` 作为 HashMap 的键，且刻意让它的 `hashCode()` 方法返回固定值，在 `put` 的时候不断产生冲突。 `main` 方法中进行了 50 万次 `put`，花了 1 个多小时才完成。

现在修改 `TestKey` 类，让它实现 `Comparable` 接口，其他代码不变：

```java
class TestKey implements Comparable<TestKey> {
    ...
    @Override
    public int compareTo(TestKey o) {
        return number - o.number;
    }
}
```

再次执行，看看结果：

```java
插入耗时:155
```

可以看到，其他操作都不变，仅仅多实现了一个 `Comparable`，`put` 的执行时间就显著缩短了。由于这么多数据都在同一个桶中，它们的结构肯定是红黑树，因此，直接分析 `putTreeVal` 方法：

```java
final TreeNode<K,V> putTreeVal(HashMap<K,V> map, Node<K,V>[] tab,
                                       int h, K k, V v) {
    Class<?> kc = null;
    boolean searched = false;
    TreeNode<K,V> root = (parent != null) ? root() : this;
    for (TreeNode<K,V> p = root;;) {
        int dir, ph; K pk;
        if ((ph = p.hash) > h)
            dir = -1;
        else if (ph < h)
            dir = 1;
        else if ((pk = p.key) == k || (k != null && k.equals(pk)))
            return p;
        else if ((kc == null &&
                  (kc = comparableClassFor(k)) == null) ||
                 (dir = compareComparables(kc, k, pk)) == 0) {
            if (!searched) {
                TreeNode<K,V> q, ch;
                searched = true;
                if (((ch = p.left) != null &&
                     (q = ch.find(h, k, kc)) != null) ||
                    ((ch = p.right) != null &&
                     (q = ch.find(h, k, kc)) != null))
                    return q;
            }
            dir = tieBreakOrder(k, pk);
        }
        ...
        }
    }
}
```

能够发现，在红黑树中插入数据时，先判断 `hash` 值，当 `hash` 值相等，且 `equals` 判断也相等，则会判断是否为 `Comparable`；若 Key 实现了 `Comparable`，则直接使用 `compareTo` 方法进行大小判断；若连 `Comparable` 都没实现（或者 `compareTo` 方法判断为相等时），则会调用 `tieBreakOrder` 方法，这个方法中使用 `System.identityHashCode` 进一步分析。对于 50 万个数据来说，`System.identityHashCode` 调用相当耗时，从上面的例子中可以看到，花了 1 个多小时。

因此，虽然 Java8 对 HashMap 进行了优化，使过长的链表优化成红黑树，但如果 Key 的 `hashCode` 算法不佳，且 Key 没有实现 `Comparable` 接口，那么仍然有可能引发很糟糕的后果。在 HashMap 源码中，编写者有这么一段话：

{{< admonition type=quote title="HashMap" open=true >}}
If neither of these apply, we may waste about a factor of two in time and space compared to taking no precautions. But the only known cases stem from poor user programming practices that are already so slow that this makes little difference.
{{< /admonition >}}

大概意思是：如果两者都不满足（指良好的 `hashCode` 方法和实现 `Comparable` 接口），那么 HashMap 的新实现（红黑树）会 **浪费两倍的空间和时间**。但是这种极端的情况是由开发者不良的编程实现引起的，其实用什么实现（链表或者红黑树）已经没区别了。