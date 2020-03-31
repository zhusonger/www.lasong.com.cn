---
title: 01:Android Handler源码分析
author: Zhusong
layout: post
footer: true
category: Android Framework
date: 2020-3-31
excerpt: "01:Android Handler源码分析"
abstract: ""
---

# 一: Handler源码分析

## 直接看Handler的注释

1. 第一段  
一个Handler允许 发送和处理 __Message&Runnable__ 到 __一个与线程的关联MessageQueue__ 。
每一个Handler实例与一个线程以及线程内的MessageQueue绑定。
当你创建一个Handler的那个时间, 它必然就与创建它(Handler)的线程/MessageQueue关联。
它将会发送Message&Runnable到绑定线程的MessageQueue中, 并执行从线程队列中吐出的Message&Runnable。

> 第一段翻译结束了。其实这里已经基本说明了Handler的原理。与线程绑定, 实际内部是MessageQueue在处理Message&Runnable。

2. 第二段
Handler有2个主要的作用:   
(1) 在未来的某个时刻, 调度Message&Runnable执行  
(2) 在自己线程中, 插入执行任务到其他线程

> 到这里Handler的主要用途已经说完了。

3. 第三段
Message的调度可以使用的方法, postXXX的重载方法允许你将Runnable对象入队到MessageQueue,  
sendXXX方法会入队一个包含一些数据的Message到MessageQueue,   
并被handleMessage方法处理(需要你实现一个Handler子类)  

> 这一段说明的我们如何使用Handler, 以及使用它的区别

4. 第四段
当posting或者sending到一个Handler时, 你可以选择在MessageQueue准备好就立即执行。  
也可以选择在一个绝对时间或延迟时间来执行。  
后面2个方式可以允许你用来实现一个超时、计时和其他基于时间线的行为。  

> 这一段指明了Handler支持即时和延时的任务。

5. 第五段
当一个应用进程创建的时候, 它有一个专属的主线程用来管理应用顶层对象(activities, broadcast receivers等)  
和顶层对象创建的窗口集。你可以创建你自己的新线程, 然后通过Handler与主应用(即主线程)进行交互。
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

应用主线程的Handler, 注意这里的Looper.getMainLooper()静态方法, 跟踪进去, 发现它返回了一个类变量sMainLooper, 那我们继续跟踪, 发现是在prepareMainLooper方法内赋值的。那这个prepareMainLooper又是在哪调用的呢。 
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

* mLooper



final Looper mLooper;


