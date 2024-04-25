---
title: "AQS 源码分析"
slug: "aqs-source-code"
summary: "Java AbstractQueuedSynchronizer（AQS）源码解析"
author: ["SadBird"]
date: 2022-02-10T11:28:03+08:00
cover:
    image: ""
    alt: ""
categories: [Java]
tags: [Java, AQS, Concurrency]
katex: false
mermaid: false
draft: true
---

AQS（AbstractQueuedSynchronizer）是 Java 1.5 后引进的同步框架，为 `ReentrantLock`、`CountDownLatch`、`Semaphore` 等 JUC（java.util.concurrent）工具实现提供了通用的模板机制，{{< inTextImg url="https://raw.githubusercontent.com/gohugoio/hugoDocs/master/static/img/hugo-logo.png" height="16" >}}其中的核心为：

- 维护管理同步状态（state）。
- 阻塞线程和解除阻塞的机制（blocking & unblocking）。
- 排队（queuing）。

详细的内容建议各位去看看这篇 AQS 作者 Doug Lea 发表的文章：[《The java.util.concurrent Synchronizer Framework》](https://www.sciencedirect.com/science/article/pii/S0167642305000663)，包括了 AQS 的设计理念、功能目标、实现手段、性能测试等。

由于不是入门文章，想要阅读 AQS 的源码至少需要了解 `ReentrantLock`、`Semaphore` 等 JUC 工具的使用方法，且对 CAS、`volatile` 有基本的认识。

在详细介绍 AQS 源码之前，先进行一个身的热：写一个丐中丐版的「同步器」。

## 简单的同步机制实现

现在模拟四个线程，Thread-1 到 Thread-4 执行相同的业务代码，并发地修改同一个共享资源 `sharedResource`，然后使用一种容易理解的乞丐版 `CasLock` 进行线程间的同步，代码如下所示：

```java {hl_lines=[55]}
public class CasLockDemo {
    public static void main(String[] args) throws InterruptedException {
        // 自定义丐版锁
        CasLock lock = new CasLock();
        // 共享资源任务
        Task task = new Task(lock);

        // 使用固定数量线程池
        ThreadPoolExecutor executor = (ThreadPoolExecutor) Executors.newFixedThreadPool(4);
        // 设置 ThreadFactory 修改 Thread 名称
        executor.setThreadFactory(new ThreadFactory() {
            private int id = 1;
            @Override
            public Thread newThread(Runnable r) {
                Thread t = new Thread(null, r, "Thread-" + id++);
                return t;
            }
        });

        // 开始执行所有任务
        for (int i = 0; i < 4; i++) {
            executor.submit(task);
        }

        // 等待所有任务完成，关闭线程池
        executor.awaitTermination(15, TimeUnit.SECONDS);
        executor.shutdown();
    }
}

/**
 * 自定义丐版锁，使用 CAS 保证只有一个线程能够通过
 */
class CasLock {
    // volatile 修饰的锁内部状态，保证可见性和有序性
    private volatile int state = 0;
    // 持有锁的线程
    private Thread currentThread;

    // Unsafe 相关代码，通过反射获取 Unsafe 对象，Unsafe 中封装了 CAS 的相关逻辑
    private static Unsafe UNSAFE;
    private static long STATE_OFFSET;

    static {
        Field unsafeField = Unsafe.class.getDeclaredFields()[0];
        unsafeField.setAccessible(true);
        try {
            UNSAFE = (Unsafe) unsafeField.get(null);
            STATE_OFFSET = UNSAFE.objectFieldOffset(CasLock.class.getDeclaredField("state"));
        } catch (NoSuchFieldException | IllegalAccessException ignored) {}
    }

    public void lock() {
        // 使用 CAS 尝试修改 state 状态（由 0 转变为 1），由于 CAS 的原子性，同一时间只有一个线程能通过这个自旋循环
        while (!UNSAFE.compareAndSwapInt(this, STATE_OFFSET, 0, 1)) {
            // spin
            System.out.println(Thread.currentThread().getName() + " is spinning...");
            try {
                TimeUnit.SECONDS.sleep(1);
            } catch (InterruptedException ignore) {}
        }
        // 修改状态成功的线程获得到当前的锁
        currentThread = Thread.currentThread();
    }

    public void unlock() {
        // 只有当前持有锁的线程才能进行解锁操作
        if(Thread.currentThread() != currentThread) {
            throw new IllegalMonitorStateException();
        }

        // 解锁时由于不存在竞争，因此直接赋值即可，不需要 CAS
        state = 0;
        currentThread = null;
    }
}

/**
 * 自定义任务，用于修改共享资源 sharedResource
 */ 
class Task implements Runnable {
    private int sharedResource = 0;
    private final CasLock lock;

    public Task(CasLock lock) {
        this.lock = lock;
    }

    @Override
    public void run() {
        // 获取锁，获取成功的线程才能接下去执行，获取失败的锁将在这里一直自旋
        lock.lock();

        sharedResource = sharedResource + 1;
        System.out.println("Do something..." + Thread.currentThread().getName() + "...Resource-" + sharedResource);

        try {
            TimeUnit.SECONDS.sleep(3);
        } catch (InterruptedException ignore) {}

        // 执行完成，释放锁
        lock.unlock();
    }
}
```
main 方法部分较为简单，使用 Java 的固定大小线程池多次执行同一个任务，等待任务完成后关闭线程池。

`CasLock` 就是一个丐版的同步器，维护了一个 `volatile` 类型的 `state`，该值初始为 0，表示当前同步器未被任何线程持有。当某个线程调用 `lock` 方法时，同步器状态就会被 CAS 操作修改为 1，表示该线程持有了同步器。该线程执行任务过程中，由于 `state` 始终为 1，其他线程的 CAS 操作都会失败，并在 `while` 循环中自旋、睡眠。当线程执行完任务并调用 `unlock` 后，`state` 重新设置回 0，表示同步器再次进入可被获取的状态，此时其他线程才有机会重新抢占同步器。至于 `Unsafe` 类这里理解为提供 CAS 操作支持的工具就好了。

对于上述代码中的同步部分，先拿两个线程来模拟一下，假如 Thread-1 先通过 CAS 设置了同步器中的 `state`，其后的 Thread-2 会在 `lock` 的 `while` 中自旋（`sleep` 会导致用户态到内核态的切换，但会暂时让出 CPU 资源），待 Thread-1 完成任务且执行完 `unlock` 后，Thread-2 才能通过该 `while`，如下图所示：

![](https://s2.loli.net/2022/02/11/QyijmsLN9z2vJVS.png)

执行上述代码结果大致如下：

```shell
Thread-2 is spinning...
Do something...Thread-1...Resource-1 # Thread-1 获得了锁，并更改了共享资源
Thread-4 is spinning...
Thread-3 is spinning...
Thread-3 is spinning...
Thread-4 is spinning...
Thread-2 is spinning...
Thread-2 is spinning...
Thread-4 is spinning...
Thread-3 is spinning...
Thread-4 is spinning...
Thread-2 is spinning...
Do something...Thread-3...Resource-2 # Thread-1 释放了锁，Thread-2 获得了锁，并更改了共享资源
Thread-4 is spinning...
Thread-2 is spinning...
Thread-2 is spinning...
Thread-4 is spinning...
Do something...Thread-2...Resource-3 # Thread-2 释放了锁，hread-3 获得了锁，并更改了共享资源
Thread-4 is spinning...
Thread-4 is spinning...
Thread-4 is spinning...
Do something...Thread-4...Resource-4 # Thread-3 释放了锁，Thread-4 获得了锁，并更改了共享资源
```

可以发现同一时刻只有一个线程能够通过我们的简陋同步器，并修改共享资源，其他线程都会进入 `while` 循环自旋，只有在上一个线程释放锁后，`state` 状态重新恢复为 0，其他线程才有机会结束自旋状态并通过 CAS 争抢执行权。

从这个实验中可以大致了解到同步器的作用，当多个线程同时访问同一资源的时候，同步器提供了控制多个线程访问行为的通用手段，示例中同一时间只允许一个线程能够通过同步器进入资源的修改访问，其他线程必须等待当前线程完成后才能进行下一轮的资源抢占。AQS 就是为了能够方便地创建各种不同作用的同步器所做出抽象：

- 一个表示同步状态的 `state`（亦即当前同步器的可通过性，示例中 0 表示未被线程持有，当前线程可通过，1 表示同步器已被其他线程持有，不可通过），以及对该 `state` 的一系列操作，包括原子性的 CAS 操作。
- 阻塞机制，自旋可以看成一种特殊的阻塞，它能够避免用户态到内核态切换的消耗，但它始终在执行空循环，一直占用 CPU 资源，因此需要提供一种长时间的阻塞机制，在阻塞期间 CPU 资源能够被其他任务使用。
- 队列，虽然在示例中没有体现队列，但队列是 AQS 的核心，它既实现了公平性，也支持超时、取消等操作。

## AQS 解析

### state 管理

对于 AQS 的第一个要点「`state` 管理」，主要是使用 CAS 和 `volatile`，CAS 保证操作的原子性，而 `volatile` 则保证了 `state` 的可见性和有序性，关于这两点，本文不会重点介绍，感兴趣的朋友可以参考 oracle 的两个官方文档进行详细了解： [CAS](https://docs.oracle.com/javase/8/docs/api/java/util/concurrent/atomic/package-summary.html#package.description) 和 [volatile](https://docs.oracle.com/javase/specs/jls/se8/html/jls-8.html#jls-8.3.1.4)。

### 阻塞机制

从论文中，我们可以了解到，AQS 实现线程阻塞的机制主要使用 `LockSupport` 这个类，它提供了一系列**静态方法**用于提供阻塞和唤醒线程的服务。[官方 API](https://docs.oracle.com/javase/8/docs/api/java/util/concurrent/locks/LockSupport.html) 对于 `LockSupport` 类的简介如下：
{{< admonition type=quote title="Locksupport" open=true >}}
This class associates, with each thread that uses it, a permit (in the sense of the Semaphore class). A call to park will return immediately if the permit is available, consuming it in the process; otherwise it may block. A call to unpark makes the permit available, if it was not already available. (Unlike with Semaphores though, permits do not accumulate. There is at most one.)
{{< /admonition >}}

简单概括起来就是：`LockSupport` 为每个使用它的线程都提供了一个「permit」许可（默认这个「permit」许可是不可用状态）。当某个线程调用 `park()` 方式时，如果这个「permit」可用，那么就会立刻返回，并消耗掉这个「permit」（消耗掉了就表示这个「permit」转为不可用状态）；如果线程调用 `park()` 时，「permit」为不可用状态，那么该线程会直接阻塞。当 `unpark()` 被调用后（如果当前线程的「permit」此时为不可用状态），「permit」又会重新转入可用状态，且会唤醒 `park()` 中的线程。这里有个隐含的信息，这个「permit」没有数量的概念，它只有可用和不可用两个状态，如果一个「permit」已经是可用状态，那么再次调用 `unpark()` 不会有其他效果，它仍然还是可用状态，这也就是论文中提到的：「多次调用 `unpark()` 只能起到一次 `unpark()` 的效果」。

`LockSupport` 基本使用方法是：在线程 t 没有抢到资源的情况下，调用 `LockSupport.park()` 让**当前线程** t 进入阻塞状态，等到资源可用时，由**释放资源的线程**调用 `LockSupport.unpark(t)` 方法唤醒线程 t，让它有机会获得资源。

#### 对比 Thread.resume 和 Thread.suspend

API 和论文中都强调了 `LockSupport` 和 `Thread.resume()`、`Thread.suspend()` 的区别，在某些竞争激烈的情况下，如果先调用了 `ruseme()` 再调用 `suspend()`，那么那个线程将一直处于阻塞状态，而 `LockSupport` 不存在这个问题，即使先调用了 `unpark()` 后调用 `park()`，也能保证线程正常执行。示例如下：

```java
public class LockSupportVSThreadResumeDemo {
    public static void main(String[] args) throws Exception {
        Thread thread1 = new Thread(() -> {
            System.out.println("Thread-1 started.");
            sleep(1000);
            System.out.println("Thread-1 finished.");
        });
        thread1.setName("Thread-1");
        thread1.start();
        // 先唤醒
        thread1.resume();
        // 这里睡一小下，为了让 thread1 的启动输出能打印出来
        sleep(500);
        // 后挂起
        thread1.suspend();

        System.out.println("==================================");

        Thread thread2 = new Thread(() -> {
            System.out.println("Thread-2 started.");
            // 睡 1 秒，保证 park() 在主线程的 unpark() 后执行
            sleep(1000);
            // 后挂起
            LockSupport.park();
            System.out.println("Thread-2 finished");
        });
        thread2.setName("Thread-2");
        thread2.start();
        // 先唤醒
        LockSupport.unpark(thread2);
    }

    public static void sleep(long milliseconds) {
        try {
            TimeUnit.MILLISECONDS.sleep(milliseconds);
        } catch (InterruptedException e) {
            // ignore
        }
    }
}
```
在 IDEA 中执行结果如下：

![](https://s2.loli.net/2022/04/13/4g2fJKN8XMIajHB.png)

Thead-1 使用 `resume()` 和 `suspend()`，这里使用不严谨的 `sleep()` 确保 `suspend()` 在 `resume()` 后执行；Thread-2 使用 `LockSupport`，同样使用 `sleep()` 保证 `park` 在 `unpark()` 之后执行。

程序没有正常停止，且 Thread-1 没有打印出 finished，表示它没有正常执行到最后，使用 [Arthas](https://github.com/alibaba/arthas) 查看该线程状态如下：

![](https://s2.loli.net/2022/04/13/c12YQMGRpUPqlwD.png)

很显然，它被挂起了，`resume()` 在 `suspend()` 之前无法保证线程能正常执行，因此这两个方法被 JDK 标记为危险方法，后面都不再使用了，`LockSupport` 替代了它们的作用。

#### 唤醒方式和注意事项

[官方 API](https://docs.oracle.com/javase/8/docs/api/java/util/concurrent/locks/LockSupport.html) 和论文中都提到了线程调用 `park()` 进入阻塞状态后的唤醒的条件，有以下几种：

- 调用 `unpark()` 后。
- 线程被中断（调用 `Thread.interrupt()`）或者使用带超时时间的 `park(timeout)` 到期。
- 伪唤醒（论文中为 Spurious wakeup），这种唤醒表示即使没有上面两种唤醒，在 `park()` 中阻塞的线程也会由于其他原因被唤醒（这种唤醒不是我们想要的）。

正因为「伪唤醒」的存在，API 中特别说明了 `LockSupport` 的使用方法，通常要将它放在一个循环当中，以防「伪唤醒」影响了业务的正确性，这点的理解可以类比 `synchronized` 中的 `wati()` 和 `notifyAll()` 机制，`notifyAll()` 一次会唤醒多个线程，但最终，还是只有一个线程会抢到资源，其他线程仍然要通过 while 循环进入等待状态：

```java
while (!canProceed()) { ... LockSupport.park(this); }
```

这里的 `park()` 还多了一个 Object 参数，它是用来监控和诊断当前线程具体是因为哪个业务陷入等待阻塞的，如果业务中有多个地方会阻塞线程时（或者说有多个同步器时），就需要使用这种方式，在诊断和监控的业务中使用 `LockSupport.getBlocker(Thread t)` 获取线程 t 的真实阻塞状态，这也是官方鼓励的使用方式。

结合我们刚完成的丐版同步器中的锁方法来理解一下，假设修改 `CasLock` 中的加锁代码如下：

```java
public void lock() {
    // 
    while (!UNSAFE.compareAndSwapInt(this, STATE_OFFSET, 0, 1)) {
        // spin
        System.out.println(Thread.currentThread().getName() + " is spinning...");
        try {
            // TimeUnit.SECONDS.sleep(1);
            // 将原来的睡眠修改为 park
            LockSupport.park(this);
        } catch (InterruptedException ignore) {}
    }
    // 修改状态成功的线程获得到当前的锁
    currentThread = Thread.currentThread();
}
```

使用 `park()` 替代 `sleep()` 是一种优雅、高效的手段，`sleep()` 我们难以控制线程被唤醒的时刻，有可能资源已经让出了，但线程还在阻塞，也有可能资源还被占用，但线程提前被唤醒。`park()` 则不存在这个问题，除了「伪唤醒」，线程会在资源被占用期间保持阻塞，让出 CPU 资源给其他线程，而且能够在程序中控制它的唤醒时机，在真正资源可用的时候 `unpark()` 唤醒它（比如当前占有资源的线程释放资源时）。

关于 Java 中的阻塞和等待机制的底层实现，这里推荐两篇文章，非常详细：[Unsafe.park vs Object.wait](https://zeral.cn/java/unsafe.park-vs-object.wait/)、[Java Thread 和 Park](https://www.beikejiedeliulangmao.top/java/concurrent/thread-park/)。

最后，回顾一下上面的代码，`lock()` 可以利用 CAS 保证只有一个线程能够通过，其余线程都要使用 `LockSupport` 挂起。这就引入了一个新的需求了，最早使用 `Thread.sleep()` 我们可以利用睡眠时间让每个线程自己醒来，然后重新抢锁，但这个 `park()` 是需要我们在**释放资源的线程**中调用 `unpark()` 手动唤醒的。那么这么多阻塞的线程要怎么管理？释放资源的线程在释放资源后又要选择唤醒谁？这里就要隆重介绍下面的一个核心机制——CLH 队列。

### 队列

现在可以介绍 AQS 的两个关键操作了：

- *acquire* 操作，仅当 state 代表有可用的资源时，才允许线程继续执行，否则阻塞调用 *acquire* 的线程。
- *release* 操作，改变 state 的值使其处于可用状态，进而让正处于阻塞等待中的一个或者多个线程能够有机会重新争夺资源。

在论文和 AQS 源码中都给出了两种核心操作的伪代码：

```
Acquire:
    while (!tryAcquire(arg)) {
        enqueue thread if it is not already queued;
        possibly block current thread;
    }
    dequeue current thread if it was queued;
  
Release:
    update synchronization state;
    if (tryRelease(arg))
        unblock the first queued thread;
```
翻译成中文：

- Acquire：如果尝试获取资源（`tryAcquire(arg)`）失败，就将线程入队并阻塞当前线程（while 表示有可能多次失败，需要多次尝试，直到获取到资源），待唤醒且成功获取到资源后，将线程出队。
- Release：如果当前线程 t 的业务逻辑已经执行完成，首先将 state 资源更新（回到可用状态），然后尝试释放资源，若成功，那么就在当前线程 t 中（即将结束）唤醒队列中的第一个等待线程（隐含条件是线程 t 之前肯定是争夺资源成功，否则无法走到释放资源的逻辑）。

现在暂时可以将 `acquire` 和 `release` 分别理解为加锁和解锁操作，对比上面的丐版锁实现，`tryAcquire()` 基本上与 CAS 操作相同，最后抢锁失败后同样要进入阻塞，但 `acquire` 在陷入阻塞前多了一个将当前线程放入队列的操作。这个队列就是论文中提到的「CLH 变体」队列，它沿用了 CLH 队列的思想，但使用场景略有不同，因此在 AQS 中进行了适当的修改。它最主要的作用是用于管理**处于阻塞状态的线程**，能够高效地处理线程的入队阻塞和出队解锁操作，遵循 FIFO 的原则，且支持**公平机制**、**超时机制**和**取消**操作。 

