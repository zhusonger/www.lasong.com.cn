---
title: 08: WeakHandler的“坑”
author: Zhusong
layout: post
footer: true
category: Android
date: 2020-12-08
excerpt: "08: WeakHandler的“坑”"
abstract: ""
---

# WeakHandler项目

<https://github.com/badoo/android-weak-handler>

# WeakHandler 分析
<http://ohmerhe.com/2016/01/18/how-to-work-weakhandler/>

# WeakHandler的“坑”

## 引起内存泄漏的原因
使用匿名内部类创建的Handler容易产生内存泄漏, 这是Android开发基本都知道的问题。分析在WeakHandler都有写。引起泄漏的原因是线程持有对Runnable的引用，同时Runnable是在Activity创建的,  持有对Activity的强引用。导致即使Activity关闭, 出栈了, 但是线程如果还在运行, 就会保持对Runnable的引用, 间接引用到了Activity, 导致Activity的泄漏。

## 如何解决

WeakHandler就是在Runnable中间加了一个一个WeakRunnable充当桥梁, 当Activity关闭时, 由于是弱引用, WeakRunnable可以被回收, 在这里中断了对Activity的引用。即使线程在运行任然不会影响Activity对象的回收。

但是如果WeakHandler也是弱引用, WeakRunnable一下就被回收了, 所以WeakHandler需要在Activity定义一个全局变量, 保持对WeakRunnable的强引用。避免WeakHandler内的ChainedRef链保存的WeakRunnable丢失。

弱引用在每次GC时就会被回收(没有GC Roots引用的情况下)，那保持一个全局的WeakHandler就可以保证内部的ChainedRef保存的Runnable不会丢失。

## “坑”？

我这是说另外一个点。就是我们习惯使用一个Handler.Callback来统一处理消息，如果你是在某个方法内创建的WeakHandler, 并在方法内创建Handler.Callback, 那么很容易就出现发送了消息, 但是Handler.Callback没有执行到。

这是因为Handler.Callback被GC回收了。

原因是因为你在方法内创建的话, 它引用的是方法栈帧, 但是方法在执行完成后出栈, 就没有GC Roots指向这个方法栈帧, 就被回收了, 栈帧内部执行的也就丢失了强引用, 被GC回收了。导致WeakHandler虽然没有被回收, 但是它处理所有消息的Handler.Callback已经被回收了。

## 解决方法

1. 可以跟WeakHandler一样, 定义一个全局变量mCallback。

2. 也可以跟WeakHandler一起在变量定义时, 就创建WeakHandler和Handler.Callback实例。

	```java
	private WeakHandler mHandler = new WeakHandler(msg -> {
	      ILog.d(TAG, "WeakHandler : " + msg);
            return false;
    });
	```
	
## 扩展
那为什么在使用post方法时, 也是在方法内创建的Runnable可以正常使用, 那是因为post发送的Runnable封装成WeakRunnbale时,  还加入到了WeakHandler内的全局变量mRunnables链表结构中。

所以我们在解决Handler.Callback的问题的思路就是保持一个跟Activity周期一致的全局变量即可。
