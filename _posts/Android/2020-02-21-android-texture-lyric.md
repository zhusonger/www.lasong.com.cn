---
title: 01:Android自定义控件-TextureView实现歌词控件LrcView
author: Zhusong
layout: post
footer: true
category: Android
date: 2020-2-21
excerpt: "01:Android自定义控件-TextureView实现歌词控件LrcView"
abstract: ""
---

# 功能需求

根据krc歌词文件, 逐字逐句刷新当前播放的歌词  
展示多行, 播放行高亮显示, 逐字更新歌词  

![]({{site.assets_path}}/img/gif/lyric.gif)

# 思路

为了使渲染效率与控件布局都兼顾, 选择TextureView来实现, 既拥有SurfaceView的双缓冲, 独立线程渲染(5.0之后)的优点, 同时兼顾普通  View的动画.


由于歌词渲染属于比较轻量的渲染需求, 使用TextureView优于SurfaceView


[SurfaceView与TextureView区别](https://blog.csdn.net/while0/article/details/81481771)  

[Canvas](https://developer.android.com/reference/android/graphics/Canvas): 画布, 用来显示你展示在屏幕的内容
> The Canvas class holds the "draw" calls. To draw something, you need 4 basic components: A Bitmap to hold the pixels, a Canvas to host the draw calls (writing into the bitmap), a drawing primitive (e.g. Rect, Path, text, Bitmap), and a paint (to describe the colors and styles for the drawing).

[Paint](https://developer.android.com/reference/android/graphics/Paint): 画笔, 用来在画布上渲染的一些配置, 比如颜色, 样式等
> The Paint class holds the style and color information about how to draw geometries, text and bitmaps.


# 实现
* 首先继承TextureView实现自定义控件, 实现它的几个构建方法, 一般我习惯重载构造方法, 然后就可以直接在最后那个构造方法里做初始化.

	```java
	public LrcView(Context context) {
        this(context, null);
    }
	
    public LrcView(Context context, AttributeSet attrs) {
        this(context, attrs, 0);
    }
	
    public LrcView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
    }
	```

* 设置setSurfaceTextureListener回调,这个方法是TextureView持有的Surface的状态回调, 有4个方法

	```java
	// 在首次TextureView创建Surface后回调, 用来判断TextureView是否准备好
	@Override
	public void onSurfaceTextureAvailable(SurfaceTexture surface, int width, int height) {
	}
	// 在TextureView大小发生改变
	@Override
	public void onSurfaceTextureSizeChanged(SurfaceTexture surface, int width, int height) {
	}
	    
	// 在TextureView被销毁时, Texture被移出View Hierachy时触发,用来判断TextureView是否还可用
	@Override
	public boolean onSurfaceTextureDestroyed(SurfaceTexture surface) {
	}
	
	// 每次draw方法后都会调用
	@Override
	public void onSurfaceTextureUpdated(SurfaceTexture surface) {
	}
	
	public LrcView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        setSurfaceTextureListener(this);
    }
	```
* 创建画笔Paint

	```java
	// 创建抗锯齿的画笔
	private Paint mPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
	
	public LrcView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        setSurfaceTextureListener(this);
        // 设置画笔默认配置
        mPaint.setTextSize(DEFAULT_TEXT_SIZE_PX);
        mPaint.setTypeface(Typeface.DEFAULT_BOLD);
        mPaint.setTextAlign(Paint.Align.CENTER);
        mPaint.setColor(DEFAULT_TEXT_COLOR);
    }
	```
	
* 开启单独线程进行画布上内容的绘制, 不停进行更新渲染   
  绘制步骤分为3步: 获取Canvas => 绘制文字 => 释放Canvas  
  这里加一个阻塞的逻辑, 就是当前不需要绘制的情况下wait当前线程, 避免资源消耗  
  在其他开始更新的地方添加唤醒功能

	```java
	public LrcView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        setSurfaceTextureListener(this);
        mPaint.setTextSize(DEFAULT_TEXT_SIZE_PX);
        mPaint.setTypeface(Typeface.DEFAULT_BOLD);
        mPaint.setTextAlign(Paint.Align.CENTER);
        mPaint.setColor(DEFAULT_TEXT_COLOR);
        mThread = new Thread(this, "LrcView");
        mThread.start();
    }
    
    @Override
    public void run() {
        // 移除窗口后退出线程
        while (!mDestroy) {
            // 判断是否不需要画歌词
            if (isBlock()) {
                // 阻塞渲染歌词线程
                synchronized (mFence) {
                    try {
                        mFence.wait();
                    } catch (InterruptedException e) {
                        e.printStackTrace();
                    }
                }
                // 再次回到while循环判断
                // 1. 可能是view被移除释放的阻塞, mDetach = true, 线程结束
                // 2. 正常的视图可见/surface创建并且可见, 不会进入阻塞, 正常执行下面的渲染逻辑
                continue;
            }

            // 省略逻辑代码
            
            // 获得画布
            Canvas canvas = lockCanvas();
            synchronized (mFence) {
                if (mDestroy) {
                    break;
                }
            }
            // 清除上一次的内容
            canvas.drawColor(Color.TRANSPARENT, PorterDuff.Mode.CLEAR);

            // 省略逻辑代码

            // 画默认歌词样式
            canvas.drawText(text, centerX, baselineY, mPaint);
            
            // 释放画布
            unlockCanvasAndPost(canvas);
            
            // 间隔进行下一次绘制, 这个可以根据需要调整
            try {
                Thread.sleep(getPollingInterval());
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }
    }
    
	```
		
* 添加歌曲时间提供器ITimeProvider  
  为了解耦合时间跟歌词渲染的关系, 当然提供一个默认的时间提供器, 根据开始时间计算时间间隔  
  但是比较好的还是通过获取播放的歌曲当前时长

	```java
	public interface ITimeProvider {
		// 获取当前播放时长
	    long getCurrentPosition();
		// 获取刷新间隔
	    long getPollingInterval();
	}
	```
	
* 核心内容就是以上的部分, 其他的就是解析krc歌词, 一些异步线程调用的处理, 没有提取出可配置参数  

# Android Stuido引入

implementation 'cn.com.lasong:widget:0.0.1'

# 开源库地址
<https://github.com/zhusonger/androidz_widget>