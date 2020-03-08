---
title: 02:Android自定义控件-自由拖动控件MoveView
author: Zhusong
layout: post
footer: true
category: Android
date: 2020-2-22
excerpt: "02:Android自定义控件-自由拖动控件MoveView"
abstract: ""
---


# 功能需求
在当前页面内, 跟随手指移动, 先不管边界超出跟自动靠边   
 
![]({{site.assets_path}}/img/gif/move.gif) 

# 思路
首先是当前页面内有效, 就简单一点, 使用自定义控件加上布局的方式实现, 就不通过WMS来实现了

跟随手指移动, 这里需要理解这个含义, 这里跟随的情况是 __不可交互的部分__ 跟随手指移动, 如果有按钮, 拖动条等这种需要交互的控件, 当手指在他们上面拖动时, 它不应该跟随你的手指去移动, 虽然可以控件中去区分后续动作是针对按钮的, 但是这样的灵敏度会有一定的差距, 体验感不是很好, 所以还是不去拦截可交互的内容. 当然, 不可点击的按钮还是作为可拖动的部分

根据上面的描述, 需要在触摸拦截上处理一下

跟随手指移动, 有2种方式去更新位置, 一种是直接设置x,y值(WMS实现拖动窗口方式), 另一种, 更新控件的margin值  

这里我们使用设置x,y的方式, 因为margin值需要获取父控件, 作为自定义控件不够灵活

同时为了可以忽略控件内的内容, 我们继承已有的父布局, 这样可以不管具体内部是什么, 就像普通的父布局一样即可



# 实现

* 继承RelativeLayout实现MoveView   
	
	```java
	public class MoveView extends RelativeLayout {
	    public MoveView(Context context) {
	        this(context, null);
	    }
	
	    public MoveView(Context context, @Nullable AttributeSet attrs) {
	        this(context, attrs, 0);
	    }
	
	    public MoveView(Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
	        super(context, attrs, defStyleAttr);
	    }
	}
	```

* 处理下事件传递, 这里我们的传递规则是
   > 所有的触摸事件都被当前的MoveView所拦截, 不再向下传递(穿透)   
   > 如果是内部的子控件有自己的事件就按照默认规则处理   
   > 如果内部控件都没有拦截事件, 这个事件就由我们这个MoveView处理移动

	```java
	// Step1
	// 返回true拦截事件, 不往下传递
	@Override
	public boolean dispatchTouchEvent(MotionEvent ev) {
	    boolean ret = super.dispatchTouchEvent(ev);
	    return true;
	}
	
	// Step2
	// 本控件内处理, 按照控件正常拦截机制拦截
	@Override
	public boolean onInterceptTouchEvent(MotionEvent ev) {
	    boolean ret = super.onInterceptTouchEvent(ev);
	    return ret;
	}
	
	// 记录最新的位置
	private PointF mLastP = new PointF();
	// Step3 当前View拦截到事件就进行触摸拖动
	@Override
	public boolean onTouchEvent(MotionEvent event) {
		boolean ret = super.onTouchEvent(event);
		// TODO 处理触摸事件进行控件移动
		return true;
	}
	```

* 进行控件的移动
	> 注意这里的getX与getRawX的区别   
	>> getX是相对于父控件左上角开始的坐标位置   
	>> getRawX是相对于屏幕左上角的坐标位置, 在计算偏移量时使用这个     
	>
	>  定义一个坐标记录当前的坐标, 然后在MOVE中计算偏移值, 更新X&Y, 同时必须更新当前的坐标, 用于准确计算下次相对的偏移值
	
	```java
	// 记录最新的位置
    private PointF mLastP = new PointF();
    // Step3 当前View拦截到事件就进行触摸拖动
    @Override
    public boolean onTouchEvent(MotionEvent event) {
        boolean ret = super.onTouchEvent(event);
        switch (event.getAction()) {
            case MotionEvent.ACTION_DOWN: {
                mLastP.x = event.getRawX();
                mLastP.y = event.getRawY();
                break;
            }

            case MotionEvent.ACTION_MOVE: {
                float currentX = event.getRawX();
                float currentY = event.getRawY();
                float offsetX = currentX - mLastP.x;
                float offsetY = currentY - mLastP.y;
                setX(getX() + offsetX);
                setY(getY() + offsetY);
                // 更新最后的位置坐标
                mLastP.x = currentX;
                mLastP.y = currentY;
                break;
            }
        }
        return true;
    }
	```

* Over

# Android Stuido引入

implementation 'cn.com.lasong:widget:0.0.1'

# 开源库地址
<https://github.com/zhusonger/androidz_widget>