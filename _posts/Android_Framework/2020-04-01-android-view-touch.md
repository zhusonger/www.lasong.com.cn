---
title: 05:Android View事件分发源码分析
author: Zhusong
layout: post
footer: true
category: Android Framework
date: 2020-04-05
excerpt: "05:Android View事件分发源码分析"
abstract: ""
---
# Android源码

<https://android.googlesource.com/>

<https://www.androidos.net.cn/sourcecode>

# 总体

先说我们都知道的事件分发顺序

dispatchTouchEvent => onInterceptTouchEvent(ViewGroup) => onTouchEvent

1. dispatchTouchEvent 从WMS发送触摸事件到屏幕上触发, 如果返回true, 表示被这个View接受并处理触摸事件。如果返回false, 表示这个View不处理这个触摸事件。
2. onInterceptTouchEvent 当触发的是ViewGroup时, 也是在dispatchTouchEvent, 但是它还是把事件再通过onInterceptTouchEvent来判断这个事件是ViewGroup来处理, 还是由它的子View来处理。true表示由当前ViewGroup来处理。false表示这个ViewGroup不处理, 由子View处理。
3. onTouchEvent 如果dispatchTouchEvent返回true, 就由当前View来处理触摸事件。否则忽略。优先通过mOnTouchListener对象的onTouch来处理触摸事件。ViewGroup是在onInterceptTouchEvent返回true之后, 然后调用父类(View)的dispatchTouchEvent, 就是执行当前ViewGroup的onTouchEvent来处理。

事件的传递是从外到内的, 就是说先从父View处理, 父View不处理再传递给子View。

# 源码分析

## Activity

最先接收到触摸事件的就是Activity了。 然后交给它的Window来处理, window是在attach方法里创建的PhoneWindow。


```java

public boolean dispatchTouchEvent(MotionEvent ev) {
	// 所有的触摸事件首先会调用onUserInteraction
    if (ev.getAction() == MotionEvent.ACTION_DOWN) {
        onUserInteraction();
    }
    // 然后交给Activity的Window来处理
    if (getWindow().superDispatchTouchEvent(ev)) {
        return true;
    }
    return onTouchEvent(ev);
}

final void attach(Context context, ActivityThread aThread,
        Instrumentation instr, IBinder token, int ident,
        Application application, Intent intent, ActivityInfo info,
        CharSequence title, Activity parent, String id,
        NonConfigurationInstances lastNonConfigurationInstances,
        Configuration config, String referrer, IVoiceInteractor voiceInteractor,
        Window window, ActivityConfigCallback activityConfigCallback, IBinder assistToken) {
    
    // ...
    
    mWindow = new PhoneWindow(this, window, activityConfigCallback);
    mWindow.setWindowControllerCallback(this);
    mWindow.setCallback(this);
    mWindow.setOnWindowDismissedCallback(this);
    mWindow.getLayoutInflater().setPrivateFactory(this);
    // ...
}
```

## PhoneWindow

PhoneWindow的superDispatchTouchEvent调用的是mDecor的superDispatchTouchEvent方法, mDecor

```java
@Override
public boolean superDispatchTouchEvent(MotionEvent event) {
    return mDecor.superDispatchTouchEvent(event);
}
```