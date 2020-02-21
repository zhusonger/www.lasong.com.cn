---
title: 01:Android自定义控件-getX和getRawX
author: Zhusong
layout: post
footer: true
post_list: "category"
category: Android
date: 2020-2-20
excerpt: "01:Android自定义控件-getX和getRawX"
abstract: ""
---


## 功能
需要做一个控件随着手指拖动, 现在做的简单点, 不用WMS添加Window, 直接添加到布局中, 然后监听onTouch事件, 那样直接更新leftMargin和topMargin即可

## 问题
在计算偏移距离时, 用了getX和getY来计算偏移量, 发现在疯狂抖动, 直接换了getRawX和getRawY就正常了

## 区别
getRawX：触摸点相对于屏幕的坐标  
getX： 触摸点相对于触摸控件的坐标  

## 代码

```java
private float mDownX;
private float mDownY;
private int mDownLeftMargin;
private int mDownTopMargin;

@Override
public boolean onTouchEvent(MotionEvent event) {
    boolean ret = super.onTouchEvent(event);
    switch (event.getAction()) {
        case MotionEvent.ACTION_DOWN: {
            mDownX = event.getRawX();
            mDownY = event.getRawY();
            FrameLayout.LayoutParams lp = (FrameLayout.LayoutParams) getLayoutParams();
            mDownLeftMargin = lp.leftMargin;
            mDownTopMargin = lp.topMargin;
            break;
        }

        case MotionEvent.ACTION_MOVE: {
            float currentX = event.getRawX();
            float currentY = event.getRawY();
            float offsetX = currentX - mDownX;
            float offsetY = currentY - mDownY;
            FrameLayout.LayoutParams lp = (FrameLayout.LayoutParams) getLayoutParams();
            lp.leftMargin = mDownLeftMargin + (int) offsetX;
            lp.topMargin = mDownTopMargin + (int) offsetY;
            setLayoutParams(lp);
            break;
        }
    }
    return true;
}
```