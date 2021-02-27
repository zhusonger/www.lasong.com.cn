---
title: 00:Android问题集锦
author: Zhusong
layout: post
footer: true
category: Android
date: 2020-2-20
excerpt: "00:Android问题集锦"
abstract: "记录Android开发过程中碰到的问题"
---

# [Gradle同步问题](https://www.jianshu.com/p/24a38f8400cc)  

新建项目卡在Gradle sync步骤，通过模拟Android Studio下载Gradle的过程来跳过IDE的下载过程, 因为它比较慢  

解决方式

### 方法一

* 打开项目的gradle文件夹 => wrapper文件夹 => gradle-wrapper.properties, 拷贝distributionUrl地址   
* 打开浏览器输入distributionUrl地址,自己下载好文件  
* 进入~/.gradle/wrapper/dists/gradle-{版本号}-all/{电脑上的一串符号}/ 
* 删除后缀.part文件, 创建空文件gradle-{版本号}-all.zip.ok, 可以去其他文件夹目录拷贝一个, 然后修改名字  
* 拷贝下载的gradle压缩包到当前目录, 并解压  
* 重新同步


### 方法二

在下载ExoPlayer源代码后, 一直Read Timeout, 代理设置了还是不行, 所以把库地址改成国内阿里云的


```groovy
buildscript {
    repositories {
//        maven { url "https://jitpack.io" }
		// 这里改成国内的
        maven{ url'http://maven.aliyun.com/nexus/content/groups/public/' }
        maven{ url'http://maven.aliyun.com/nexus/content/repositories/jcenter'}
        google()
//        jcenter()
    }
    dependencies {
        classpath 'com.android.tools.build:gradle:3.5.1'
        classpath 'com.novoda:bintray-release:0.9.1'
        classpath 'com.google.android.gms:strict-version-matcher-plugin:1.2.0'
    }
}
allprojects {
    repositories {
		// 这里改成国内的
        maven{ url'http://maven.aliyun.com/nexus/content/groups/public/' }

        maven{ url'http://maven.aliyun.com/nexus/content/repositories/jcenter'}
//        google()
//        jcenter()
    }
    project.ext {
        exoplayerPublishEnabled = false
    }
    if (it.hasProperty('externalBuildDir')) {
        if (!new File(externalBuildDir).isAbsolute()) {
            externalBuildDir = new File(rootDir, externalBuildDir)
        }
        buildDir = "${externalBuildDir}/${project.name}"
    }
    group = 'com.google.android.exoplayer'
}

apply from: 'javadoc_combined.gradle'
```

# AS依赖库缓存问题

上传了自己的开源项目到jcenter, 因为一开始上传的项目引用到了本地项目, 导致上传上去的库依赖关系有本地项目, 理所当然的, 在引用的时候就出现找不到的问题, 后面就更新后上传, 服务端已经更新了, 可是本地项目还是一直没有更新, 试过删除 `~/.gradle/caches/modules-2/files-2.1` 下的对应的开源库, 但是项目更新还是按照旧的依赖关系去获取依赖库

解决方式:

* 运行androidDependencies任务, 会看到之前报错的依赖库会依赖一个unspecified的库  

	![]({{site.assets_path}}/img/android/img-android-as-gradle-dependencies.png)

* 我们对这个任务添加一下强制刷新的参数, 然后运行   

	```
	--refresh-dependencies
	```	
	* 右键选择Create   

	![]({{site.assets_path}}/img/android/img-android-as-gradle-create-dependency.png)  
	
	* 添加参数   

	![]({{site.assets_path}}/img/android/img-android-as-gradle-create-params.png)   
	
	* 运行   

	![]({{site.assets_path}}/img/android/img-android-as-gradle-run-dependency.png) 


* 重新运行项目, 使用最新的依赖关系进行关联

# 卡在Configure projects

打开Build标签, 查看具体原因。  

### NDK is missing a "platforms" directory.

表示找不到NDK, 在local.properties设置ndk.dir.  

```sh
# 如果要用到ndk
ndk.dir=/Users/zhusong/Documents/Dev/android-sdk-macosx/ndk/21.0.6113669
```

# Android App

### 问题1: 一个动态高度的TextView, 在上下2个控件之间, 动态增长, 直到下面的那个控件撑到底部, 并且文字不能被裁减

通过约束布局的layout\_constraintVertical\_bias和layout\_constraintVertical\_chainStyle实现高度的自适应, 通过代码中动态监控来设置最大行数来解决不裁剪的问题。

因为是在recycleview里的, 可能会复用, 所以用addOnPreDrawListener监听。使用完之后调用removeOnPreDrawListener移除。

```java
/**
 * 更新最大行数
 * @param textView
 */
private void updateMaxLines(TextView textView) {
    if (null == textView) {
        return;
    }
    // 先重置为最大行数
    textView.setMaxLines(Integer.MAX_VALUE);
    textView.getViewTreeObserver().addOnPreDrawListener(new ViewTreeObserver.OnPreDrawListener() {
        @Override
        public boolean onPreDraw() {
            textView.getViewTreeObserver().removeOnPreDrawListener(this);
            float lineHeight = textView.getLineHeight() * textView.getLineSpacingMultiplier();
            int height = textView.getHeight();
            Layout layout = textView.getLayout();
            if (null != layout) {
                int lineCount = layout.getLineCount();
                int bottom = layout.getLineBottom(lineCount - 1);
                int lines = bottom > height ? (int)(height / lineHeight) : lineCount;
                textView.setMaxLines(lines);
            }
            // 是否继续绘制, true继续绘制/false取消后续绘制
            return true;
        }
    });
}
```

### 问题2: 显示输入法并显示隐藏的输入框布局时正常, 但是在代码隐藏时, 状态已经是GONE, 但是还是显示在屏幕内

原因是问题1中addOnPreDrawListener导致的问题, 监听有个返回值, 如果是false, 表示取消后续的绘制, 之前看的网上加的这个监听, 它返回false, 想着应该是不拦截处理的, 就照猫画虎的返回了false。这个问题很隐蔽, 不太容易发现。

查看onPreDraw的代码以及返回值注释理解后改为true。

```java
/**
 * Notifies registered listeners that the drawing pass is about to start. If a
 * listener returns true, then the drawing pass is canceled and rescheduled. This can
 * be called manually if you are forcing the drawing on a View or a hierarchy of Views
 * that are not attached to a Window or in the GONE state.
 *
 * @return True if the current draw should be canceled and resceduled, false otherwise.
 */
@SuppressWarnings("unchecked")
public final boolean dispatchOnPreDraw() {
    boolean cancelDraw = false;
    final CopyOnWriteArray<OnPreDrawListener> listeners = mOnPreDrawListeners;
    if (listeners != null && listeners.size() > 0) {
        CopyOnWriteArray.Access<OnPreDrawListener> access = listeners.start();
        try {
            int count = access.size();
            for (int i = 0; i < count; i++) {
                cancelDraw |= !(access.get(i).onPreDraw());
            }
        } finally {
            listeners.end();
        }
    }
    return cancelDraw;
}
```

```java
@return True if the current draw should be canceled and resceduled, false otherwise.

cancelDraw |= !(access.get(i).onPreDraw()); 
```
这行代码就是如果有一个是返回false的, 那他就会取消绘制。TextView里的onPreDraw也是返回的true。


### 问题3: 使用主题的方式的状态栏透明(Android5.0以上) 

```xml
<style name="AppTheme.TransparentBar">
    <!-- true: status栏会有一层阴影；false: status栏没有阴影-->
    <item name="android:windowTranslucentStatus">false</item>
    <!--状态栏是否覆盖在ContentView上-->
    <item name="android:windowDrawsSystemBarBackgrounds">true</item>
    <!--Android 5.x开始需要把颜色设置透明，否则导航栏会呈现系统默认的浅灰色-->
    <item name="android:statusBarColor">@android:color/transparent</item>
</style>
```

* 状态栏背景是纯色, 根布局fitsSystemWindows=true, background

```xml
<?xml version="1.0" encoding="utf-8"?>
<androidx.coordinatorlayout.widget.CoordinatorLayout xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto"
    xmlns:tools="http://schemas.android.com/tools"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:fitsSystemWindows="true"
    android:background="@android:color/holo_blue_dark"
    tools:context=".MainActivity">
</androidx.coordinatorlayout.widget.CoordinatorLayout>
```

* 状态栏与顶部AppBarLayout扩展到状态栏, 根布局&AppBarLayout 设置 fitsSystemWindows=true
* 覆盖在AppBarLayout上可以使用elevation属性增大层级
* AppBarLayout内的滑动并在指定高度停止layout_scrollFlags=scroll\|exitUntilCollapsed, 并设置minHeight(默认0,表示滑到顶)

```xml
<?xml version="1.0" encoding="utf-8"?>
<androidx.coordinatorlayout.widget.CoordinatorLayout xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto"
    xmlns:tools="http://schemas.android.com/tools"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:fitsSystemWindows="true"
    android:background="@android:color/holo_blue_dark"
    tools:context=".MainActivity">


    <com.google.android.material.appbar.AppBarLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:fitsSystemWindows="true"
        >

        <ImageView
            android:layout_width="match_parent"
            android:layout_height="200dp"
            android:background="@drawable/ic_launcher_background"
            app:layout_scrollFlags="scroll|exitUntilCollapsed"
            android:minHeight="?attr/actionBarSize"
            />


        <androidx.appcompat.widget.Toolbar
            android:id="@+id/toolbar"
            android:layout_width="match_parent"
            android:layout_height="?attr/actionBarSize"
            android:background="?attr/colorPrimary"
            />


    </com.google.android.material.appbar.AppBarLayout>


    <TextView
        android:layout_width="match_parent"
        android:layout_height="?attr/actionBarSize"
        android:background="#4D000000"
        android:elevation="20dp"
        />
</androidx.coordinatorlayout.widget.CoordinatorLayout>

```

	
## 缩写解释

* aapt: Android Asset Packaging Tool => Android打包工具
* apt: Annotation Processor Tool => 注解处理器	
