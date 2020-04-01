---
title: 02:Android View事件分发源码分析
author: Zhusong
layout: post
footer: true
category: Android Framework
date: 2020-4-1
excerpt: "02:Android View事件分发源码分析"
abstract: ""
---

# 总体

先说我们都知道的事件分发顺序

dispatchTouchEvent => onInterceptTouchEvent(ViewGroup) => onTouchEvent

1. dispatchTouchEvent 从WMS发送触摸事件到屏幕上触发, 如果返回true, 表示被这个View接受并处理触摸事件。如果返回false, 表示这个View不处理这个触摸事件。
2. onInterceptTouchEvent 当触发的是ViewGroup时, 也是在dispatchTouchEvent, 但是它还是把事件再通过onInterceptTouchEvent来判断这个事件是ViewGroup来处理, 还是由它的子View来处理。true表示由当前ViewGroup来处理。false表示这个ViewGroup不处理, 由子View处理。
3. onTouchEvent 如果dispatchTouchEvent返回true, 就由当前View来处理触摸事件。否则忽略。优先通过mOnTouchListener对象的onTouch来处理触摸事件。ViewGroup是在onInterceptTouchEvent返回true之后, 然后调用父类(View)的dispatchTouchEvent, 就是执行当前ViewGroup的onTouchEvent来处理。

