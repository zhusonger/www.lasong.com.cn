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

使用匿名内部类创建的Handler容易产生内存泄漏, 这是Android开发基本都知道的问题。分析在WeakHandler都有写。

在WeakHandler有提到, 需要在全局变量里定义一个WeakHandler变量, 用来保持强引用,  避免WeakHandler内的ChainedRef保存的弱引用链丢失。弱引用在每次GC时就会被回收(没有GC Roots引用的情况下)，那保持一个全局的WeakHandler就可以保证内部的ChainedRef保存的Runnable不会丢失。

我这是说另外一个点。就是我们习惯使用一个Handler.Callback来统一处理消息，如果你是在某个方法内创建的Handler.Callback, 那么很容易就出现发送了消息, 但是Handler.Callback没有执行到。

这是因为Handler.Callback被GC回收了。

原因是因为你在方法内创建的话, 它引用的是方法栈帧, 但是方法在执行完成后出栈, 就没有GC Roots指向这个方法栈帧, 就被回收了, 栈帧内部执行的也就丢失了强引用, 被GC回收了。导致WeakHandler虽然没有被回收, 但是它处理所有消息的Handler.Callback已经被回收了。

## 解决方法

如果想用Handler.Callback统一处理, 可以跟WeakHandler一样, 定义一个全局变量mCallback, 在销毁时, 把mCallback置空。不置空的话, 还是会有内存泄漏的问题。Handler.Callback被外部强引用和被WeakHandler弱引用。因为它不被回收是外部的强引用，如果不置空它并不会被有效回收，只有置空之后，只有WeakHandler弱引用才能被安全回收。