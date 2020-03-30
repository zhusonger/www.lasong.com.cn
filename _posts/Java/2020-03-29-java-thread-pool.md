---
title: 06:Java线程以及线程池
author: Zhusong
layout: post
footer: true
category: Java
date: 2020-3-29
excerpt: "06:Java线程以及线程池"
abstract: ""
---

# 概念
线程是CPU调度的最小单位。  
线程的实现主要有3种实现方式。 

* 内核线程(Kernel-Level Thread, KLT)

	> 内核线程就是内核通过调度器(Scheduler)对线程进行调度, 并负责将线程的任务映射到各个处理器(CPU)上。不过程序一般不会直接去使用内核线程, 而是去使用内核线程的一种高级接口, 轻量级进程(Light Weight Process, LWP)。基于内核线程实现的, 所以需要在用户态与内核太切换, 消耗会比较大。但是各自独立, 一个线程阻塞不会影响整个进程工作。
	
* 用户线程(User-Level Thread, ULT)

	> 只要不是内核线程, 就可以认为是用户线程。从这个定义来说, 轻量级进程(LWP)也属于用户线程。狭义来说, 是完全建立在用户空间的线程库,内核线程不能感知到线程的存在, 不需要内核的帮助。  
	> 如果实现足够完善, 那理论上来说, ULT是一种很好的实现, 可以非常高效的运行。跟之前的ReentrantLock一样, 在最后才会进入系统刮起, 调用到内核资源。可以支持更大的线程数量。  
	> 但是现实是线程的创建, 调度, 阻塞, 映射到处理器实现起来都异常困难。所以现在的实现基本都不完全使用用户线程了。

* 结合上面2种线程实现, 用户线程与内核线程混合实现

	> 混合模式的情况下, 轻量级进程(LWP)作为用户进程与内核线程的桥梁。

# Java线程的实现
由于线程的实现很大程序取决于系统的线程模型来实现。目前来说, Java在Windows与Linux线程都是1:1的线程模型, 即1个Java线程对应到一个轻量级进程(LWP)。
	
# 线程调用的方式

## 协同式线程调度
线程的执行时间由线程自己控制, 线程把工作做完之后, 主动通知系统切换到另外一个线程中。

* 优点: 线程完全由自己控制, 切换操作都是自己控制, 所以没有线程同步的问题。
* 缺点: 线程执行时间不可控, 如果代码实现有问题, 没有主动通知系统切换线程, 一直占用系统的资源。这样的实现方式全依赖应用程序的稳定性, 如果实现不好, 会把整个系统搞崩。
	
## 抢占式线程调度
每个线程的执行时间由系统来分配, 线程的切换不由线程控制。Java的yield可以让出执行时间, 但是什么时候执行还是不可知的。所以会存在同步问题。
优点: 系统稳定, 不会出现某个线程一直占用资源, 如果某个进程出了问题, 就可以通过杀死这个进程。

## Java的调用方式
说完2者的区别, 肯定也能得出结论, Java就是使用抢占式的线程调度。不过线程实现了一个优先级, 建议系统根据优先级多分配一些运行时间。不过这个映射关系跟系统线程模型的优先级有关, 可能会出现多个Java线程优先级在系统的优先级是一样的。

# 状态
* 新建(New)

	> 创建后未开启状态
	
* 运行(Runnable)

	> 包括Ready以及Running, 正在运行或者等待CPU分配执行时间。
	
* 无限期等待(Waiting)

	> 无限期等待, 不会被分配CPU执行时间, 直到其他线程显示的唤醒它们。
	>
	> * Object.wait()方法
	> * Thread.join()方法 => 内部还是wait
	> * LockSupport.park()方法 => 底层互斥量实现阻塞
		
* 限期等待(Timed Waiting)

	> 有超时时间的等待, 不会被分配CPU执行时间, 时间到了之后自动唤醒。
	>
	> * Thread.sleep(timeout)方法
	> * Object.wait(timeout)方法
	> * Thread.join(timeout)方法
	> * LockSupport.parkNanos(timeout)方法
	> * LockSupport.parkUtil(timestamp)方法
	
* 阻塞(Blocked)

	> 线程被阻塞, 跟等待的区别是, 阻塞是进入同步块时的状态, 在等待获取到一个排他锁的时候。获取到锁就进入Runnable, 否则就阻塞, 这是我们同步线程中经常碰到的情况。涉及到锁升级也是在这里。  
	> synchronized
	
* 结束(Terminated)

	> 线程已终止, 结束执行。


# 线程池
从上面线程的实现方式可以看到, 如果没有节制的创建线程, 对系统来说是一个很消耗性能的工作, 那我们创建线程池, 就是相当于固定了线程的个数, 避免线程的无限创建。没有工作的时候核心线程就等待/阻塞, 有任务就使用线程池里的线程执行任务, 这样就限制了线程数量。

# 线程池的优势
* 控制线程数量, 减少系统压力
* 减少线程创建与销毁的资源消耗
* 任务与线程分离, 提升线程复用

# 线程池实现思路

线程池的整体思路就是, 开限定数量的线程, 有任务过来丢给空闲的线程去做, 否则就排队等待。

如果任务都做完了, 就把线程休眠, 不占用系统资源。

![1]({{site.assets_path}}/img/java/java_thread_pool.jpg)

# 源码分析

## 成员变量

* ctl  
这个成员变量就一行,  但是注释非常多。因为这一个成员变量, 同时代表了运行状态与工作线程数的值。
具体就是通过位运算得到高位的状态和低位的数量。

```java
/**
 * The main pool control state, ctl, is an atomic integer packing
 * two conceptual fields
 *   workerCount, indicating the effective number of threads
 *   runState,    indicating whether running, shutting down etc
 *
 * In order to pack them into one int, we limit workerCount to
 * (2^29)-1 (about 500 million) threads rather than (2^31)-1 (2
 * billion) otherwise representable. If this is ever an issue in
 * the future, the variable can be changed to be an AtomicLong,
 * and the shift/mask constants below adjusted. But until the need
 * arises, this code is a bit faster and simpler using an int.
 *
 * The workerCount is the number of workers that have been
 * permitted to start and not permitted to stop.  The value may be
 * transiently different from the actual number of live threads,
 * for example when a ThreadFactory fails to create a thread when
 * asked, and when exiting threads are still performing
 * bookkeeping before terminating. The user-visible pool size is
 * reported as the current size of the workers set.
 *
 * The runState provides the main lifecycle control, taking on values:
 *
 *   RUNNING:  Accept new tasks and process queued tasks
 *   SHUTDOWN: Don't accept new tasks, but process queued tasks
 *   STOP:     Don't accept new tasks, don't process queued tasks,
 *             and interrupt in-progress tasks
 *   TIDYING:  All tasks have terminated, workerCount is zero,
 *             the thread transitioning to state TIDYING
 *             will run the terminated() hook method
 *   TERMINATED: terminated() has completed
 *
 * The numerical order among these values matters, to allow
 * ordered comparisons. The runState monotonically increases over
 * time, but need not hit each state. The transitions are:
 *
 * RUNNING -> SHUTDOWN
 *    On invocation of shutdown(), perhaps implicitly in finalize()
 * (RUNNING or SHUTDOWN) -> STOP
 *    On invocation of shutdownNow()
 * SHUTDOWN -> TIDYING
 *    When both queue and pool are empty
 * STOP -> TIDYING
 *    When pool is empty
 * TIDYING -> TERMINATED
 *    When the terminated() hook method has completed
 *
 * Threads waiting in awaitTermination() will return when the
 * state reaches TERMINATED.
 *
 * Detecting the transition from SHUTDOWN to TIDYING is less
 * straightforward than you'd like because the queue may become
 * empty after non-empty and vice versa during SHUTDOWN state, but
 * we can only terminate if, after seeing that it is empty, we see
 * that workerCount is 0 (which sometimes entails a recheck -- see
 * below).
 */
private final AtomicInteger ctl = new AtomicInteger(ctlOf(RUNNING, 0));
```
* 状态值

状态的说明在ctl的注释中, 状态转换也在注释里说明了。

// 运行时状态, 接受新任务并处理等待队列  
RUNNING:  Accept new tasks and process queued tasks  

// 关闭状态, 不接受新任务, 但是会处理等待队列  
SHUTDOWN: Don't accept new tasks, but process queued tasks  

// 停止状态, 不接受新任务, 也不处理等待队列, 同时打断进行中的任务  
STOP:     Don't accept new tasks, don't process queued tasks, and interrupt in-progress tasks  

// 整理状态,  所有的任务已经停止, 工作数量为0, 线程池正在尝试转换成TERMINATED状态  
TIDYING:  All tasks have terminated, workerCount is zero, the thread transitioning to state TIDYING will run the terminated() hook method

// 终止状态, terminated方法被调用并完成了了  
TERMINATED: terminated() has completed

```java
private static final int COUNT_BITS = Integer.SIZE - 3;
private static final int CAPACITY   = (1 << COUNT_BITS) - 1;

// 运行状态存储在高位
// runState is stored in the high-order bits
private static final int RUNNING    = -1 << COUNT_BITS;
private static final int SHUTDOWN   =  0 << COUNT_BITS;
private static final int STOP       =  1 << COUNT_BITS;
private static final int TIDYING    =  2 << COUNT_BITS;
private static final int TERMINATED =  3 << COUNT_BITS;
```

* workQueue
工作队列, 感觉称作waitQueue更贴切, 这个队列添加元素的唯一地方是execute方法。只有核心线程全部执行完之后, 才会添加到workQueue进行排队。

```java
private final BlockingQueue<Runnable> workQueue;
```

* mainLock

注释第一句

Lock held on access to workers set and related bookkeeping.

当访问工作任务集合时 以及 相关记录的地方 进行锁定  

```java
private final ReentrantLock mainLock = new ReentrantLock();
```

* workers

工作线程集合。记录所有的工作线程, 只有得到mainLock锁才能访问。

```java
/**
 * Set containing all worker threads in pool. Accessed only when
 * holding mainLock.
 */
private final HashSet<Worker> workers = new HashSet<Worker>();
```

* termination

中断条件, 主要用来调用虚拟机内实现的 pthread_cond_wait 相关的代码, 条件就是时间, 超时自动唤醒。

```java
/**
 * Wait condition to support awaitTermination
 */
private final Condition termination = mainLock.newCondition();
```

* largestPoolSize

记录线程池达到过的 __同时运行__ 最大的线程数。

在addWorker方法中更新。

```java
/**
 * Tracks largest attained pool size. Accessed only under
 * mainLock.
 */
private int largestPoolSize;
```

* completedTaskCount

累计完成的任务数。在一个工作线程结束的时候更新。工作线程里有个字段completedTasks, 表示这个线程完成的任务数。

```java

/**
 * Counter for completed tasks. Updated only on termination of
 * worker threads. Accessed only under mainLock.
 */
private long completedTaskCount;
```

* threadFactory

没啥好说的, 线程工厂。创建新线程使用的。一般就直接new Thread()返回。

但是就我的理解来说, 这里JDK提供出来是想说, 你的线程还有自己的一些行为, 比如线程开始会初始化, 在线程结束做释放这样的行为。

如果只是重写之后只是new Thread(), 就没必要重写这个属性了。

```java
private volatile ThreadFactory threadFactory;
```


* handler

拒绝策略, 默认是AbortPolicy, 对这个任务抛出异常。JDK还提供DiscardPolicy、DiscardOldestPolicy、CallerRunsPolicy。  
功能分别是直接忽略任务、忽略最前面添加的任务、直接在调用者线程运行任务。

```java
 /**
 * Handler called when saturated or shutdown in execute.
 */
private volatile RejectedExecutionHandler handler;

/**
 * A handler for rejected tasks that throws a
 * {@code RejectedExecutionException}.
 */
public static class AbortPolicy implements RejectedExecutionHandler {
    /**
     * Creates an {@code AbortPolicy}.
     */
    public AbortPolicy() { }

    /**
     * Always throws RejectedExecutionException.
     *
     * @param r the runnable task requested to be executed
     * @param e the executor attempting to execute this task
     * @throws RejectedExecutionException always
     */
    public void rejectedExecution(Runnable r, ThreadPoolExecutor e) {
        throw new RejectedExecutionException("Task " + r.toString() +
                                             " rejected from " +
                                             e.toString());
    }
}
```

* corePoolSize & maximumPoolSize

核心线程以及最大线程数。corePoolSize <= maximumPoolSize, 核心线程数与超过核心数的线程, 唯一的区别是超时线程结束行为。

如果设置了allowCoreThreadTimeOut true, 那核心线程还是非核心线程是没区别的。

```java
/**
 * Core pool size is the minimum number of workers to keep alive
 * (and not allow to time out etc) unless allowCoreThreadTimeOut
 * is set, in which case the minimum is zero.
 */
private volatile int corePoolSize;

/**
 * Maximum pool size. Note that the actual maximum is internally
 * bounded by CAPACITY.
 */
private volatile int maximumPoolSize;

```

* allowCoreThreadTimeOut

是否允许核心线程超时, 默认是false, 如果是false, 核心线程空闲也会存活, 不会关闭。

如果是true, 就会使用keepAliveTime来判断, 如果超过keepAliveTime的时间还是没有任务, 就关闭核心线程。

```java
/**
 * If false (default), core threads stay alive even when idle.
 * If true, core threads use keepAliveTime to time out waiting
 * for work.
 */
private volatile boolean allowCoreThreadTimeOut;
```

* keepAliveTime

作用与workQueue, 调用poll(long timeout, TimeUnit unit)方法, 如果等待任务数量为0, 会阻塞等待timeout时间, 如果还是没有任务, 就返回null。

根据这个引申出了线程的生命周期。具体看注解部分。

```java
// 用户获取工作队列workQueue的任务
// 这个方法是工作线程Worker循环调用的, 
private Runnable getTask() {
    boolean timedOut = false; // Did the last poll() time out?

    for (;;) {
        int c = ctl.get();
        int rs = runStateOf(c);

        // Check if queue empty only if necessary.
        if (rs >= SHUTDOWN && (rs >= STOP || workQueue.isEmpty())) {
            decrementWorkerCount();
            return null;
        }

        int wc = workerCountOf(c);
        // 注意这里
        // 这里意思是否需要进行超时判断
        // 当工作线程超过核心线程, 就是非核心线程数的那些线程 / 允许核心线程超时
        // allowCoreThreadTimeOut为true就是所有线程都会进行超时获取
        // 线程池线程的运行生命周期是根据该函数是否返回null来决定的
        // 如果这个函数返回null, 那工作线程就结束了
        // 
        // Are workers subject to culling?
        boolean timed = allowCoreThreadTimeOut || wc > corePoolSize;


        if ((wc > maximumPoolSize || (timed && timedOut)) // 工作线程超过最大线程 或者 上次获取任务为空(一般情况就是workQueue为空)
            && (wc > 1 || workQueue.isEmpty())) { // 工作线程大于1 或者 workQueue为空
            if (compareAndDecrementWorkerCount(c)) //就减掉工作线程数量, 并把当前这个线程停止
                return null;
            continue;
        }

        // 归纳一下上面的代码就是
        // 1. 线程数超过最大的线程数, 执行完的这个线程就直接结束了, 保证在执行的线程数小于等于最大线程
        // 2. 根据超时规则, 我这个线程超时了还是没有任务, 结束线程
        // 那没有超时的情况怎么处理的呢? 往下看
 
 		// 没错, 主要依赖BlockingQueue的take方法, 内部调用是await, 核心线程就阻塞在这里了
 		// 
        try {
            Runnable r = timed ?
                workQueue.poll(keepAliveTime, TimeUnit.NANOSECONDS) : // 这里参照poll方法的注释说明
                workQueue.take(); // 这里参考take方法内的注释说明
            if (r != null)
                return r;
            timedOut = true;
        } catch (InterruptedException retry) {
            timedOut = false;
        }
    }
}

public E poll(long timeout, TimeUnit unit) throws InterruptedException {
    long nanos = unit.toNanos(timeout);
    final ReentrantLock lock = this.lock;
    lock.lockInterruptibly();
    try {
    	// 1. 如果队列数量为0, 进入循环
        while (count == 0) {
        	// 2. 如果等待时间是0, 返回null
            if (nanos <= 0)
                return null;
            // 3. 这里就不再进去看awaitNanos的实现了, 就是等待nanos, 返回剩余的可等待时间
            // 这里等待了nanos之后, 返回就是0了, 回到2退出。
            nanos = notEmpty.awaitNanos(nanos);
        }
        return dequeue();
    } finally {
        lock.unlock();
    }
}

public E take() throws InterruptedException {
    final ReentrantLock lock = this.lock;
    lock.lockInterruptibly();
    try {
    	// 如果没有线程就等待。谜底揭晓
        while (count == 0)
            notEmpty.await();
        return dequeue();
    } finally {
        lock.unlock();
    }
}
```

* shutdownPerm

用于检测运行时权限, 检测调用者是否有权限停止线程池。这个又是新的知识点了。我也没看过=。=。找到一篇文章, 以后再研究  
<https://blog.csdn.net/john1337/article/details/102912070>

```java
private static final RuntimePermission shutdownPerm =
        new RuntimePermission("modifyThread");
```

* ONLY_ONE

固定的一个标志位, 表示一次只停止一个线程。

```java
private static final boolean ONLY_ONE = true;
```


# 总结

到这里我们源码分析就结束了, 一般分析源码, 首先, 自己思考如果我设计这么一个东西, 我会怎么做, 然后在看它的属性有哪些, 查看属性调用的位置。  
跟你的思路对比, 发现异同点。一步步分析。  
但是切记不要钻牛角尖。比如这里的ctl这个标志位与执行线程数量结合的属性。  
如果一直在纠结它是怎么计算的。那会耗费很多时间。抓大放小。  