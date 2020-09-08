---
title: 04:Android 消息轮询机制源码分析
author: Zhusong
layout: post
footer: true
category: Android Framework
date: 2020-04-04
excerpt: "04:Android 消息轮询机制源码分析"
abstract: ""
---
# Android源码

<https://android.googlesource.com/>

<https://www.androidos.net.cn/sourcecode>

# 一: Handler源码分析

## 直接看Handler的注释

* 第一段    
一个Handler允许 发送和处理 __Message&Runnable__ 到 __一个与线程的关联MessageQueue__ 。  
每一个Handler实例与一个线程以及线程内的MessageQueue绑定。  
当你创建一个Handler的那个时间, 它必然就与创建它(Handler)的线程/MessageQueue关联。  
它将会发送Message&Runnable到绑定线程的MessageQueue中, 并执行从线程队列中吐出的Message&Runnable。  

> 第一段翻译结束了。其实这里已经基本说明了Handler的原理。与线程绑定, 实际内部是MessageQueue在处理Message&Runnable。

* 第二段   
Handler有2个主要的作用:     
(1) 在未来的某个时刻, 调度Message&Runnable执行    
(2) 在自己线程中, 插入执行任务到其他线程   

> 到这里Handler的主要用途已经说完了。 

* 第三段  
Message的调度可以使用的方法, postXXX的重载方法允许你将Runnable对象入队到MessageQueue,    
sendXXX方法会入队一个包含一些数据的Message到MessageQueue,     
并被handleMessage方法处理(需要你实现一个Handler子类)    

> 这一段说明的我们如何使用Handler, 以及使用它的区别  

* 第四段  
当posting或者sending到一个Handler时, 你可以选择在MessageQueue准备好就立即执行。   
也可以选择在一个绝对时间或延迟时间来执行。    
后面2个方式可以允许你用来实现一个超时、计时和其他基于时间线的行为。    

> 这一段指明了Handler支持即时和延时的任务。  

* 第五段  
当一个应用进程创建的时候, 它有一个专属的主线程用来管理应用顶层对象(activities, broadcast receivers等)和顶层对象创建的窗口集。  
你可以创建你自己的新线程, 然后通过Handler与主应用(即主线程)进行交互。    
你创建的线程的行为与之前说明的方法调用都一样的。    
发送的Runnable&Message将会在适当的时候, 被MessageQueue调度与处理。    

```java

/**
 * A Handler allows you to send and process {@link Message} and Runnable
 * objects associated with a thread's {@link MessageQueue}.  Each Handler
 * instance is associated with a single thread and that thread's message
 * queue.  When you create a new Handler, it is bound to the thread /
 * message queue of the thread that is creating it -- from that point on,
 * it will deliver messages and runnables to that message queue and execute
 * them as they come out of the message queue.
 * 
 * <p>There are two main uses for a Handler: (1) to schedule messages and
 * runnables to be executed at some point in the future; and (2) to enqueue
 * an action to be performed on a different thread than your own.
 * 
 * <p>Scheduling messages is accomplished with the
 * {@link #post}, {@link #postAtTime(Runnable, long)},
 * {@link #postDelayed}, {@link #sendEmptyMessage},
 * {@link #sendMessage}, {@link #sendMessageAtTime}, and
 * {@link #sendMessageDelayed} methods.  The <em>post</em> versions allow
 * you to enqueue Runnable objects to be called by the message queue when
 * they are received; the <em>sendMessage</em> versions allow you to enqueue
 * a {@link Message} object containing a bundle of data that will be
 * processed by the Handler's {@link #handleMessage} method (requiring that
 * you implement a subclass of Handler).
 * 
 * <p>When posting or sending to a Handler, you can either
 * allow the item to be processed as soon as the message queue is ready
 * to do so, or specify a delay before it gets processed or absolute time for
 * it to be processed.  The latter two allow you to implement timeouts,
 * ticks, and other timing-based behavior.
 * 
 * <p>When a
 * process is created for your application, its main thread is dedicated to
 * running a message queue that takes care of managing the top-level
 * application objects (activities, broadcast receivers, etc) and any windows
 * they create.  You can create your own threads, and communicate back with
 * the main application thread through a Handler.  This is done by calling
 * the same <em>post</em> or <em>sendMessage</em> methods as before, but from
 * your new thread.  The given Runnable or Message will then be scheduled
 * in the Handler's message queue and processed when appropriate.
 */
```

## 成员变量

* FIND_POTENTIAL_LEAKS  
用于检测这个当前Handler是否是一个可能内存泄漏的Handler。    
从它的判断条件就可以看出来了, 它可能会造成内存的几种情况。    
匿名内部类 或者 成员类(就是跟成员变量一个层级定义的类) 或者 局部类 (方法内部的类) 并且 没有static修饰的Handler。    
其实这些都是一个意思, 就是这个Handler持有外部类的引用。     

```java
private static final boolean FIND_POTENTIAL_LEAKS = false;

// Handler构建方法内

if (FIND_POTENTIAL_LEAKS) {
    final Class<? extends Handler> klass = getClass();
    if ((klass.isAnonymousClass() || klass.isMemberClass() || klass.isLocalClass()) &&
            (klass.getModifiers() & Modifier.STATIC) == 0) {
        Log.w(TAG, "The following Handler class should be static or leaks might occur: " +
            klass.getCanonicalName());
    }
}
```

* MAIN_THREAD_HANDLER  

应用主线程的Handler, 注意这里的Looper.getMainLooper()静态方法, 跟踪进去, 发现它返回了一个类变量sMainLooper, 那我们继续跟踪, 发现是在prepareMainLooper方法内赋值的。  
那这个prepareMainLooper又是在哪调用的呢。     
就是ActivityThread中的main函数的调用的。这个就是应用的启动流程里的应用启动入口了。    

```java
private static Handler MAIN_THREAD_HANDLER = null;

/** @hide */
@UnsupportedAppUsage
@NonNull
public static Handler getMain() {
    if (MAIN_THREAD_HANDLER == null) {
        MAIN_THREAD_HANDLER = new Handler(Looper.getMainLooper());
    }
    return MAIN_THREAD_HANDLER;
}

// ======== Looper.java ========//
public static Looper getMainLooper() {
    synchronized (Looper.class) {
        return sMainLooper;
    }
}

public static void prepareMainLooper() {
    prepare(false);
    synchronized (Looper.class) {
        if (sMainLooper != null) {
            throw new IllegalStateException("The main Looper has already been prepared.");
        }
        sMainLooper = myLooper();
    }
}

// ======== ActivityThread.java ========//
public static void main(String[] args) {
    // 省略
    Looper.prepareMainLooper();

    // ...

    if (sMainThreadHandler == null) {
        sMainThreadHandler = thread.getHandler();
    }

    // ...
    Looper.loop();

    throw new RuntimeException("Main thread loop unexpectedly exited");
}
```

* mLooper & mQueue  

实现线程轮询的核心类。具体到分析Looper和MessageQueue再看。  
2个属性的赋值都在构造方法里。  

这里就是在不理解Handler的情况下, 在非主线线程(主线线程启动就创建了Looper)中创建Handler出错的地方。这是因为Handler是跟线程绑定的,   如果线程没有创建Looper对象, 而直接创建Handler的报错。  

Looper.myLooper()又涉及到经常会问的一个知识点。ThreadLocal线程独立的一个便捷类。  

```java
final Looper mLooper;
final MessageQueue mQueue;

public Handler(@Nullable Callback callback, boolean async) {
    if (FIND_POTENTIAL_LEAKS) {
        final Class<? extends Handler> klass = getClass();
        if ((klass.isAnonymousClass() || klass.isMemberClass() || klass.isLocalClass()) &&
                (klass.getModifiers() & Modifier.STATIC) == 0) {
            Log.w(TAG, "The following Handler class should be static or leaks might occur: " +
                klass.getCanonicalName());
        }
    }

    // 犯错的地方
    mLooper = Looper.myLooper();
    if (mLooper == null) {
        throw new RuntimeException(
            "Can't create handler inside thread " + Thread.currentThread()
                    + " that has not called Looper.prepare()");
    }
    mQueue = mLooper.mQueue;
    mCallback = callback;
    mAsynchronous = async;
}

public Handler(@NonNull Looper looper, @Nullable Callback callback, boolean async) {
    mLooper = looper;
    mQueue = looper.mQueue;
    mCallback = callback;
    mAsynchronous = async;
}
```

* mCallback

消息回调。这里就可以看出我们post/send之后, 在Handler有哪些地方可以设置处理逻辑。

1. 在发送的Message内设置callback,  优先级最高
2. Handler类内部的callback, 次优先级
3. 重写Handler的handleMessage方法, 优先级最低(我最常用的方式=.=)

优先级顺序

Message.callback > Handler.mCallback > handleMessage


```java
/**
 * Handle system messages here.
 */
public void dispatchMessage(@NonNull Message msg) {
    if (msg.callback != null) {
        handleCallback(msg);
    } else {
        if (mCallback != null) {
            if (mCallback.handleMessage(msg)) {
                return;
            }
        }
        handleMessage(msg);
    }
}
```

* mAsynchronous

是否异步处理, 默认都是false, 表示同步顺序执行。

这个参数影响到MessageQueue底层的管道逻辑。在分析MessageQueue里面会说到。


```java
final boolean mAsynchronous;

private boolean enqueueMessage(@NonNull MessageQueue queue, @NonNull Message msg,
            long uptimeMillis) {
    msg.target = this;
    msg.workSourceUid = ThreadLocalWorkSource.getUid();

    if (mAsynchronous) {
        msg.setAsynchronous(true);
    }
    return queue.enqueueMessage(msg, uptimeMillis);
}
```

* mMessenger

mMessenger 在Java代码没有看到 调用getIMessenger的方法, 应该是Native层调用, 用来得到可以向这个Handler发送消息用的中间对象。

比如下面的MessengerImpl, 在Natvie拿到MessengerImpl的对象之后,  通过调用send方法来从Native发送消息给当前Handler。

这里没有说的很明白, 因为过程大概了解, 但是AIDL跟Binder这2个Android系统跨进程通信的机制还没有研究透彻, 这是后面系列文章要研究的。

自定义的AIDL只在刚毕业那会使用过, 后来也没接触, 虽然AMS,WMS都是基于这些来实现的。这些也是要后面研究的东西。以前大致看过, 但是没有整理成完整的思路与文章。

[Android 接口定义语言 \(AIDL\)](https://developer.android.com/guide/components/aidl?hl=zh-cn)

好了, 不赘述了, 理解成mMessenger是Native层跟Handler的消息传递就行了。因为Handler依赖的是底层的实现。

```java
IMessenger mMessenger;
final IMessenger getIMessenger() {
    synchronized (mQueue) {
        if (mMessenger != null) {
            return mMessenger;
        }
        mMessenger = new MessengerImpl();
        return mMessenger;
    }
}

private final class MessengerImpl extends IMessenger.Stub {
    public void send(Message msg) {
        msg.sendingUid = Binder.getCallingUid();
        Handler.this.sendMessage(msg);
    }
}

```


以上是Handler的分析, 发现它就是一个Looper与MessageQueue的封装类。

主要还是要理解它内部的这2个家伙。

## 创建一个与非主线程绑定的Handler

```java
class MyThread extends Thread {
    private Handler mHandler;
    @Override
    public void run() {
        super.run();
        Looper.prepare();
        mHandler = new Handler();
        Looper.loop();
        mHandler = null;
    }
}
```

## 方法

* sendMessageAtTime

handler内的post和send方法最终都是调用sendMessageAtTime。  

通过这个方法把需要执行的Message入队。


```java
public boolean sendMessageAtTime(Message msg, long uptimeMillis) {
    MessageQueue queue = mQueue;
    if (queue == null) {
        RuntimeException e = new RuntimeException(
                this + " sendMessageAtTime() called with no mQueue");
        Log.w("Looper", e.getMessage(), e);
        return false;
    }
    return enqueueMessage(queue, msg, uptimeMillis);
}

private boolean enqueueMessage(MessageQueue queue, Message msg, long uptimeMillis) {
    msg.target = this;
    if (mAsynchronous) {
        msg.setAsynchronous(true);
    }
    return queue.enqueueMessage(msg, uptimeMillis);
}
```

# 二: Message源码分析

在处理每个任务时都依赖一个载体, 就是Message, 那先来看这个消息结构体。

## 成员变量

* what & arg1 & arg2 & obj

这个就是我们常用到的储值数据的字段
顺便一提有个小技巧, 就是想要传递long类型的时候, 懒一点直接obj强转做一层自动装箱。  
另外一种方式就是arg1跟arg2分别存储高32位和低32位的方式。  

```java
/**
 * User-defined message code so that the recipient can identify
 * what this message is about. Each {@link Handler} has its own name-space
 * for message codes, so you do not need to worry about yours conflicting
 * with other handlers.
 */
public int what;

/**
 * arg1 and arg2 are lower-cost alternatives to using
 * {@link #setData(Bundle) setData()} if you only need to store a
 * few integer values.
 */
public int arg1;

/**
 * arg1 and arg2 are lower-cost alternatives to using
 * {@link #setData(Bundle) setData()} if you only need to store a
 * few integer values.
 */
public int arg2;

/**
 * An arbitrary object to send to the recipient.  When using
 * {@link Messenger} to send the message across processes this can only
 * be non-null if it contains a Parcelable of a framework class (not one
 * implemented by the application).   For other data transfer use
 * {@link #setData}.
 *
 * <p>Note that Parcelable objects here are not supported prior to
 * the {@link android.os.Build.VERSION_CODES#FROYO} release.
 */
public Object obj;
```

* replyTo

这个不是在Handler里面用到的, 这里不管。

* sendingUid & workSourceUid

sendingUid 跨进程通信时的发送Message的进程ID
workSourceUid 处理Message的进程的ID

```java
/**
 * Indicates that the uid is not set;
 *
 * @hide Only for use within the system server.
 */
public static final int UID_NONE = -1;

/**
 * Optional field indicating the uid that sent the message.  This is
 * only valid for messages posted by a {@link Messenger}; otherwise,
 * it will be -1.
 */
public int sendingUid = UID_NONE;

/**
 * Optional field indicating the uid that caused this message to be enqueued.
 *
 * @hide Only for use within the system server.
 */
public int workSourceUid = UID_NONE;
```

* flags

标志值, 标志当前Message的状态, 默认是0, 表示未使用, 在obtain和copyFrom方法会更新这个值为0。推荐使用obtatin, 避免频繁的创建Message, 它会保持一个最多MAX_POOL_SIZE大小的链表。你即使不用也会存着。干嘛不用呢。

```java
** If set message is in use.
 * This flag is set when the message is enqueued and remains set while it
 * is delivered and afterwards when it is recycled.  The flag is only cleared
 * when a new message is created or obtained since that is the only time that
 * applications are allowed to modify the contents of the message.
 *
 * It is an error to attempt to enqueue or recycle a message that is already in use.
 */
/*package*/ static final int FLAG_IN_USE = 1 << 0;

/** If set message is asynchronous */
/*package*/ static final int FLAG_ASYNCHRONOUS = 1 << 1;

/** Flags to clear in the copyFrom method */
/*package*/ static final int FLAGS_TO_CLEAR_ON_COPY_FROM = FLAG_IN_USE;

@UnsupportedAppUsage
/*package*/ int flags;
```

* when

目标运行时间, 基于SystemClock.uptimeMillis()的时间。返回从系统启动开始的毫秒时间。不计算睡眠时间。

```java
/**
 * The targeted delivery time of this message. The time-base is
 * {@link SystemClock#uptimeMillis}.
 * @hide Only for use within the tests.
 */
@UnsupportedAppUsage
@VisibleForTesting(visibility = VisibleForTesting.Visibility.PACKAGE)
public long when;

 /**
 * Returns milliseconds since boot, not counting time spent in deep sleep.
 *
 * @return milliseconds of non-sleep uptime since boot.
 */
@CriticalNative
native public static long uptimeMillis();
```

* data
 
跟arg和obj类似, 只是使用Bundle存储。在它们无法存储所需的数据才用到它, Messenger用到时, 还需要设置ClassLoader。

```java
/*package*/ Bundle data;
```

* target

处理这个Message的Handler。在Message入队的时候自动设置。

```java
/*package*/ Handler target;
```

* callback

消息处理回调。优先级最高。

```java
/*package*/ Runnable callback;
```

* next

Message是用一个链表存储的。指向下一个Message。

```java
/*package*/ Message next;
```

* sPoolSync & sPool & sPoolSize

Message复用缓存链表, sPool记录的是链表的第一个节点。

```java
public static final Object sPoolSync = new Object();
private static Message sPool;
private static int sPoolSize = 0;

private static final int MAX_POOL_SIZE = 50;
```

* gCheckRecycle

在调用recycle的时候进行检查, 就是检测flag标志是否还是在使用中。如果是, 就抛出异常。

```java
private static boolean gCheckRecycle = true;
```

## 方法

* recycleUnchecked

Looper每次处理完一个Message之后, 会调用recycleUnchecked, 然后把Message加入到缓存链表中。

```java
/**
 * Recycles a Message that may be in-use.
 * Used internally by the MessageQueue and Looper when disposing of queued Messages.
 */
void recycleUnchecked() {
    // Mark the message as in use while it remains in the recycled object pool.
    // Clear out all other details.
    flags = FLAG_IN_USE;
    what = 0;
    arg1 = 0;
    arg2 = 0;
    obj = null;
    replyTo = null;
    sendingUid = -1;
    when = 0;
    target = null;
    callback = null;
    data = null;

    synchronized (sPoolSync) {
        if (sPoolSize < MAX_POOL_SIZE) {
            next = sPool;
            sPool = this;
            sPoolSize++;
        }
    }
}
```

* obtain

获取缓存的Message。没有就新建一个。

```java
/**
 * Return a new Message instance from the global pool. Allows us to
 * avoid allocating new objects in many cases.
 */
public static Message obtain() {
    synchronized (sPoolSync) {
        if (sPool != null) {
            Message m = sPool;
            sPool = m.next;
            m.next = null;
            m.flags = 0; // clear in-use flag
            sPoolSize--;
            return m;
        }
    }
    return new Message();
}
```

# 三: Looper源码分析

我们按照我们在定义子线程的顺序来, 首先需要调用Looper.prepare()方法, 那就继续从Looper看。

* sThreadLocal

Looper对象的ThreadLocal, 用来隔离各自线程的Looper对象。

```java
static final ThreadLocal<Looper> sThreadLocal = new ThreadLocal<Looper>();

// 自定义线程需要调用的prepare方法, 可以看到是创建了一个线程独立的Looper对象
private static void prepare(boolean quitAllowed) {
    if (sThreadLocal.get() != null) {
        throw new RuntimeException("Only one Looper may be created per thread");
    }
    sThreadLocal.set(new Looper(quitAllowed));
}

// 获取当前线程的Looper
public static @Nullable Looper myLooper() {
    return sThreadLocal.get();
}
```

* sMainLooper

主线程的Looper, 在prepareMainLooper方法中赋值。入口是ActivityThread的main方法, 也是应用的启动入口。

```java
private static Looper sMainLooper;  // guarded by Looper.class
public static void prepareMainLooper() {
    prepare(false);
    synchronized (Looper.class) {
        if (sMainLooper != null) {
            throw new IllegalStateException("The main Looper has already been prepared.");
        }
        sMainLooper = myLooper();
    }
}
```

* sObserver

用来观察所有的Message处理的状态, 在loop()方法内调用。

```java
private static Observer sObserver;
public interface Observer {
    /**
     * Called right before a message is dispatched.
     *
     * <p> The token type is not specified to allow the implementation to specify its own type.
     *
     * @return a token used for collecting telemetry when dispatching a single message.
     *         The token token must be passed back exactly once to either
     *         {@link Observer#messageDispatched} or {@link Observer#dispatchingThrewException}
     *         and must not be reused again.
     *
     */
    Object messageDispatchStarting();

    /**
     * Called when a message was processed by a Handler.
     *
     * @param token Token obtained by previously calling
     *              {@link Observer#messageDispatchStarting} on the same Observer instance.
     * @param msg The message that was dispatched.
     */
    void messageDispatched(Object token, Message msg);

    /**
     * Called when an exception was thrown while processing a message.
     *
     * @param token Token obtained by previously calling
     *              {@link Observer#messageDispatchStarting} on the same Observer instance.
     * @param msg The message that was dispatched and caused an exception.
     * @param exception The exception that was thrown.
     */
    void dispatchingThrewException(Object token, Message msg, Exception exception);
}
```


* mQueue & mThread

在prepare的时候, 会创建一个Looper对象, 创建Looper对象的时候会创建mQueue并获取当前线程。

```java
final MessageQueue mQueue;
final Thread mThread;

private Looper(boolean quitAllowed) {
    mQueue = new MessageQueue(quitAllowed);
    mThread = Thread.currentThread();
}

public static void prepare() {
    prepare(true);
}
private static void prepare(boolean quitAllowed) {
    if (sThreadLocal.get() != null) {
        throw new RuntimeException("Only one Looper may be created per thread");
    }
    sThreadLocal.set(new Looper(quitAllowed));
}
```

* mLogging & mTraceTag & mSlowDispatchThresholdMs & mSlowDeliveryThresholdMs

性能分析相关, 开发时候调试Looper性能相关的代码。后面2个时间阈值说明一下。

mSlowDispatchThresholdMs: 就是处理这个Message处理的时间, 如果超过这个阈值, 就打印日志  

mSlowDeliveryThresholdMs: 这个是Message入队到MessageQueue会更新它需要执行的时间, 默认不传就是当前时间。  
如果我希望它执行的时间在10:00:01, 然后它的实际执行时间(因为是个队列, 一个个执行的, 但是肯定>=当前时间, 除非时光倒流)在10:00:02, 那它的希望执行的时间到实际执行的时间, 间隔是1s。间隔超过设置的值, 就打印日志。

```java
private Printer mLogging;
private long mTraceTag;
/**
 * If set, the looper will show a warning log if a message dispatch takes longer than this.
 */
private long mSlowDispatchThresholdMs;

/**
 * If set, the looper will show a warning log if a message delivery (actual delivery time -
 * post time) takes longer than this.
 */
private long mSlowDeliveryThresholdMs;
```

到这Looper的成员变量看完了。

再来看看Looper最核心的那个方法,loop

## 方法

* loop

在创建完Handler之后, 就需要调用loop方法, 让线程一直运行。

忽略掉上面说明的2个时间变量以及线程检测的逻辑, 核心代码可以简化一下

无限循环, 取MessageQueue里的Message, 即我们在Handler的send/post方法入队的。

如果调用了quit, 会把管道释放, 下次调用next()方法就会直接返回null, 结束loop循环。

否则会一直等待直到有Message。


```java
public static void loop() {
    for(;;) {
        Message msg = queue.next(); // might block
        if (msg == null) {
            // No message indicates that the message queue is quitting.
            return;
        }
        msg.target.dispatchMessage(msg);
        msg.recycleUnchecked();
    }
}
```

* quit & quitSafely

就是释放管道, 下次就取不到管道指针了。loop循环结束。

```java
public void quit() {
    mQueue.quit(false);
}

public void quitSafely() {
    mQueue.quit(true);
}
```

Looper到这里也分析完了。核心的就是loop方法。而loop方法除去 __queue.next()__, 就是一直在循环取消息然后执行。

# MessageQueue

分析下来, 发现所有的事情说白了都是MessageQueue在做。Handler跟Looper就是老板跟包工头的角色。

搬砖工就是MessageQueue。搞懂MessageQueue, 就明白了Android的消息处理机制。

## 成员变量

* mQuitAllowed

是否允许退出。我们创建的都是true。只有主线程是false。

```java
// True if the message queue can be quit.
private final boolean mQuitAllowed;

MessageQueue(boolean quitAllowed) {
    mQuitAllowed = quitAllowed;
    mPtr = nativeInit();
} 

void quit(boolean safe) {
    if (!mQuitAllowed) {
        throw new IllegalStateException("Main thread not allowed to quit.");
    }

    synchronized (this) {
        if (mQuitting) {
            return;
        }
        mQuitting = true;

        if (safe) {
            removeAllFutureMessagesLocked();
        } else {
            removeAllMessagesLocked();
        }

        // We can assume mPtr != 0 because mQuitting was previously false.
        nativeWake(mPtr);
    }
}
// 把Message的队列回收
private void removeAllMessagesLocked() {
    Message p = mMessages;
    while (p != null) {
        Message n = p.next;
        p.recycleUnchecked();
        p = n;
    }
    mMessages = null;
}

// 把超过当前时间的队列元素回收
// 就是目标执行时间 在当前时间之前的不清理, 让它继续在链表队列中等待执行,
//  只清理当前时间之后希望执行的任务。
private void removeAllFutureMessagesLocked() {
    final long now = SystemClock.uptimeMillis();
    Message p = mMessages;
    if (p != null) {
        if (p.when > now) {
            removeAllMessagesLocked();
        } else {
            Message n;
            for (;;) {
                n = p.next;
                if (n == null) {
                    return;
                }
                if (n.when > now) {
                    break;
                }
                p = n;
            }
            p.next = null;
            do {
                p = n;
                n = p.next;
                p.recycleUnchecked();
            } while (n != null);
        }
    }
}
```

* mPtr

Native代码里NativeMessageQueue对象的指针地址。用于调用Native方法的时候传回去让Native知道它的对应关系。

```java
private long mPtr; // used by native code
```

* mMessages

消息链表, mMessages代表链表头结点。在enqueueMessage方法中入队Message。

mBlocked以及nativeWake放到后面再说。

```java
Message mMessages;

boolean enqueueMessage(Message msg, long when) {
    if (msg.target == null) {
        throw new IllegalArgumentException("Message must have a target.");
    }
    if (msg.isInUse()) {
        throw new IllegalStateException(msg + " This message is already in use.");
    }

    synchronized (this) {
        // 如果已经是退出的状态, 就回收msg并返回false
        if (mQuitting) {
            IllegalStateException e = new IllegalStateException(
                    msg.target + " sending message to a Handler on a dead thread");
            Log.w(TAG, e.getMessage(), e);
            msg.recycle();
            return false;
        }
        // 标志message在使用
        msg.markInUse();
        // 更新message的时间
        msg.when = when;
        // 记录当前的头结点
        Message p = mMessages;
        // 是否需要唤醒, 因为Native层是以管道的方式实现等待的。
        // mBlocked变量只有队列中没有元素的时候是ture, 这个值的设置
        // 
        boolean needWake;
        // 如果头结点为空或者 目标运行时间 比 首节点还要小, 更新首节点为这个节点
        if (p == null || when == 0 || when < p.when) {
            // New head, wake up the event queue if blocked.
            msg.next = p;
            mMessages = msg;
            // 队列中没有元素, 说明在阻塞, 需要唤醒处理新的消息
            // 有元素为false, 说明正在运行, 不需要唤醒。
            needWake = mBlocked;
        } else {
            // 否则就是从链表中遍历, 找出第一个比新插入的节点目标时间大的, 插入的它的前面
            // 其实就是按照时间线性排列的一个链表
            // 
            // Inserted within the middle of the queue.  Usually we don't have to wake
            // up the event queue unless there is a barrier at the head of the queue
            // and the message is the earliest asynchronous message in the queue.
            
            // 队列中有个障碍元素, 并且是个异步消息, 需要唤醒处理新的消息
            // 目前障碍还是不能使用的元素, 平时我们设置是否是异步Handler没什么作用
            // 因为正常通过enqueueMessage进入的消息都是target非空的, 所以这里永远是false
            // 
            needWake = mBlocked && p.target == null && msg.isAsynchronous();
            Message prev;
            for (;;) {
                prev = p;
                p = p.next;
                // 后面没有节点或者找到第一个比当前目标时间小的, 也就是按时间来说, 
                // 当前入队的节点刚好是这个节点的前一个
                if (p == null || when < p.when) {
                    break;
                }
                if (needWake && p.isAsynchronous()) {
                    needWake = false;
                }
            }
            // 插入当前节点到队列
            msg.next = p; // invariant: p == prev.next
            prev.next = msg;
        }

        // 如果之前是阻塞队列的状态, 唤醒以处理新的消息
        // We can assume mPtr != 0 because mQuitting is false.
        if (needWake) {
            nativeWake(mPtr);
        }
    }
    return true;
}
```

* mIdleHandlers & mPendingIdleHandlers

MessageQueue闲置时的处理队列。当MessageQueue内没有需要处理的Message时, 会继续处理这个数组。

根据queueIdle这个方法来觉得是否需要删除这个IdleHandler, 如果这个队列一直有IdleHandler, 那MessageQueue就不会闲置。

当这个IdleHandler和Message队列都为空, 就进入无限期的阻塞状态, 直到下一次的唤醒。

> 注意这里的数组在一次取Message只会被处理一次。这个在next方法里可以确认。

```java
private final ArrayList<IdleHandler> mIdleHandlers = new ArrayList<IdleHandler>();
private IdleHandler[] mPendingIdleHandlers;

// next方法中的一段
// Run the idle handlers.
// We only ever reach this code block during the first iteration.
for (int i = 0; i < pendingIdleHandlerCount; i++) {
    final IdleHandler idler = mPendingIdleHandlers[i];
    mPendingIdleHandlers[i] = null; // release the reference to the handler

    boolean keep = false;
    try {
        keep = idler.queueIdle();
    } catch (Throwable t) {
        Log.wtf(TAG, "IdleHandler threw exception", t);
    }

    if (!keep) {
        synchronized (this) {
            mIdleHandlers.remove(idler);
        }
    }
}
```

* mFileDescriptorRecords

Android实现的epoll系统里的文件描述符, MessageQueue底层就是依赖这个实现的。开放出的这个是额外提供给你的支持, 

你可以创建自己的管道文件, 然后添加到这个MessageQueue中, 那对我们自己创建的FileDescriptor出现变化时, 如读取、写入、出错,

Native层的Looper的pollInner方法, 其实就是那个Java代码内MessageQueue的nativePollOnce本地方法调用的实现方法。就会被唤醒,

并调用MessageQueue的dispatchEvents方法来执行注册的回调。

```java
// Called from native code.
@UnsupportedAppUsage
private int dispatchEvents(int fd, int events) {
    // Get the file descriptor record and any state that might change.
    final FileDescriptorRecord record;
    final int oldWatchedEvents;
    final OnFileDescriptorEventListener listener;
    final int seq;
    synchronized (this) {
        record = mFileDescriptorRecords.get(fd);
        if (record == null) {
            return 0; // spurious, no listener registered
        }

        oldWatchedEvents = record.mEvents;
        events &= oldWatchedEvents; // filter events based on current watched set
        if (events == 0) {
            return oldWatchedEvents; // spurious, watched events changed
        }

        listener = record.mListener;
        seq = record.mSeq;
    }

    // Invoke the listener outside of the lock.
    int newWatchedEvents = listener.onFileDescriptorEvents(
            record.mDescriptor, events);
    if (newWatchedEvents != 0) {
        newWatchedEvents |= OnFileDescriptorEventListener.EVENT_ERROR;
    }

    // Update the file descriptor record if the listener changed the set of
    // events to watch and the listener itself hasn't been updated since.
    if (newWatchedEvents != oldWatchedEvents) {
        synchronized (this) {
            int index = mFileDescriptorRecords.indexOfKey(fd);
            if (index >= 0 && mFileDescriptorRecords.valueAt(index) == record
                    && record.mSeq == seq) {
                record.mEvents = newWatchedEvents;
                if (newWatchedEvents == 0) {
                    mFileDescriptorRecords.removeAt(index);
                }
            }
        }
    }

    // Return the new set of events to watch for native code to take care of.
    return newWatchedEvents;
}
```

* mQuitting

MessageQueue退出标志位。

```java
private boolean mQuitting;
```

* mBlocked 

MessageQueue阻塞标志位, 当没有Message需要处理时, 会把等待时间设置为-1, 代表无限期等待。在执行nativePollOnce之前, 设置这个标志位为true, 一但有消息在处理, 就设置为false

```java
// Indicates whether next() is blocked waiting in pollOnce() with a non-zero timeout.
private boolean mBlocked;
```

* mNextBarrierToken

障碍token计数, 每次执行postSyncBarrier都会+1。

```java
// The next barrier token.
// Barriers are indicated by messages with a null target whose arg1 field carries the token.
@UnsupportedAppUsage
private int mNextBarrierToken;
```



## 方法

* next

MessageQueue处理消息的主要方法。阻塞是由nativePollOnce的nextPollTimeoutMillis参数来实现的。  
三种情况:  
1. 当它等于-1时, 就是无限期等待。在没有消息时就是这个状态。  
2. 如果有消息正在处理, 就是0, 代表不阻塞。  
3. 如果非负正整数, 就等待这个时间, 最大不超过Inter的MAX_VALUE。这个情况一般就是2个消息之间有时间间隔。      

```java
@UnsupportedAppUsage
Message next() {
    // Return here if the message loop has already quit and been disposed.
    // This can happen if the application tries to restart a looper after quit
    // which is not supported.
    final long ptr = mPtr;
    if (ptr == 0) {
        return null;
    }

    int pendingIdleHandlerCount = -1; // -1 only during first iteration
    int nextPollTimeoutMillis = 0;
    for (;;) {
        if (nextPollTimeoutMillis != 0) {
            Binder.flushPendingCommands();
        }

        nativePollOnce(ptr, nextPollTimeoutMillis);

        synchronized (this) {
            // Try to retrieve the next message.  Return if found.
            final long now = SystemClock.uptimeMillis();
            Message prevMsg = null;
            Message msg = mMessages;
            // 这里可以忽略, 因为目前不调用postSyncBarrier是不会进入的。
            // 这里意思是第一个是异步消息, 堵住了, 忽略同步消息, 找到下一个异步消息处理
            if (msg != null && msg.target == null) {
                // Stalled by a barrier.  Find the next asynchronous message in the queue.
                do {
                    prevMsg = msg;
                    msg = msg.next;
                } while (msg != null && !msg.isAsynchronous());
            }
            // 有消息处理
            if (msg != null) {
                // 当前时间还没到达头结点需要处理的时间, 就阻塞中间间隔时间
                if (now < msg.when) {
                    // Next message is not ready.  Set a timeout to wake up when it is ready.
                    nextPollTimeoutMillis = (int) Math.min(msg.when - now, Integer.MAX_VALUE);
                } else {
                    // 首个结点处于需要被处理, 更新队列, 并返回首节点处理
                    // Got a message.
                    mBlocked = false;
                    if (prevMsg != null) {
                        prevMsg.next = msg.next;
                    } else {
                        mMessages = msg.next;
                    }
                    msg.next = null;
                    if (DEBUG) Log.v(TAG, "Returning message: " + msg);
                    msg.markInUse();
                    return msg;
                }
            } else {
                // 没有消息, 空队列, 永久阻塞
                // No more messages.
                nextPollTimeoutMillis = -1;
            }
            // 如果MessageQueue退出了, 就直接结束释放
            // Process the quit message now that all pending messages have been handled.
            if (mQuitting) {
                dispose();
                return null;
            }

            // 如果没有消息需要处理(空或者中间间隔), 即将准备进入休眠了, 并且 本次没有处理过mIdleHandlers
            // 就开始更新mPendingIdleHandlers并进行处理
            // If first time idle, then get the number of idlers to run.
            // Idle handles only run if the queue is empty or if the first message
            // in the queue (possibly a barrier) is due to be handled in the future.
            if (pendingIdleHandlerCount < 0
                    && (mMessages == null || now < mMessages.when)) {
                pendingIdleHandlerCount = mIdleHandlers.size();
            }
            if (pendingIdleHandlerCount <= 0) {
                // No idle handlers to run.  Loop and wait some more.
                mBlocked = true;
                continue;
            }

            if (mPendingIdleHandlers == null) {
                mPendingIdleHandlers = new IdleHandler[Math.max(pendingIdleHandlerCount, 4)];
            }
            mPendingIdleHandlers = mIdleHandlers.toArray(mPendingIdleHandlers);
        }
        // 处理mIdleHandlers
        // Run the idle handlers.
        // We only ever reach this code block during the first iteration.
        for (int i = 0; i < pendingIdleHandlerCount; i++) {
            final IdleHandler idler = mPendingIdleHandlers[i];
            mPendingIdleHandlers[i] = null; // release the reference to the handler

            boolean keep = false;
            try {
                keep = idler.queueIdle();
            } catch (Throwable t) {
                Log.wtf(TAG, "IdleHandler threw exception", t);
            }
            // 处理完返回false, 就把这个处理对象移除
            if (!keep) {
                synchronized (this) {
                    mIdleHandlers.remove(idler);
                }
            }
        }
    
        // 如果已经处理完了, 确保下次如果还是没有Message需要处理, 直接进入block状态
        // Reset the idle handler count to 0 so we do not run them again.
        pendingIdleHandlerCount = 0;

        // 重置pendingIdleHandlerCount改为不阻塞, 因为在处理完IdleHandler之后, 可能队列又有新的值了, 我们再确认一次。
        // While calling an idle handler, a new message could have been delivered
        // so go back and look again for a pending message without waiting.
        nextPollTimeoutMillis = 0;
    }
}
```

以上就是MessageQueue的核心功能。

# 参考

looper竟然有副业？   
<http://www.imooc.com/article/details/id/286124>

Android_打入messagequeue内部  
<https://suojingchao.github.io/2015/12/09/Android_%E6%89%93%E5%85%A5MessageQueue%E5%86%85%E9%83%A8.html>

