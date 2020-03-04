---
title: 01:Android逆向工程-修改smail源码
author: Zhusong
layout: post
footer: true
post_list: "category"
category: Android逆向
date: 2020-2-12
excerpt: "01:Android逆向工程-修改smail源码"
abstract: ""
---

## 问题

在我们反编译apk之后, 再重新打包并签名之后, 打开应用闪退, 这是应用针对签名再次做了一次校验, 如果签名不对, 就关闭应用

## 思路

那么我们的思路也很简单, 找到判断的地方, 修改smail源码, 跳过这个签名的判断

## 步骤
1. 使用[apktool](<https://ibotpeaches.github.io/Apktool/>)反编译apk, 得到反编译后的文件夹    

	
	```
	apktool d app-release.apk
	```
	
2. 查看AndroidManifest.xml, 查看apk的应用类与启动类  

	```
	<application
        android:allowBackup="true"
        android:icon="@drawable/ic_launcher"
        android:label="@string/app_name"
        android:supportsRtl="true"
        android:name="cn.com.lasong.patch.Application" # 应用类
        android:theme="@style/AppTheme">
        # 启动类
        <activity android:name=".MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
	```

3. 查看apk的Java代码, 方法很多
	1. 	最简单的, [jadx-gui](https://github.com/skylot/jadx), 可以查看apk/dex/jar代码, 因为不是直接的应用程序, 每次打开会占用终端, 所以写了个脚本, 结合Alfred可以快速启动

			```shell
			#!/bin/sh
			nohup jadx-gui > /dev/null 2>&1 &
			```
		
	2. [dex2jar](https://github.com/pxb1988/dex2jar) & [JD-GUI](http://java-decompiler.github.io/), 使用dex2jar导出jar包, 然后用JD-GUI查看jar包源码  
		```
		d2j-jar2dex.sh app-release.apk
		```  
4. 找到应用类与启动类, 查看源码, 找到作为判断的地方, 这里使用jadx-gui演示  

	<img src="{{site.assets_path}}/img/android/img-android-jadx-gui-java.png" width="80%">

5. 切换到smail, 找到onCreate方法, 在一步步跟踪, 找到判断条件的地方
	
	5.1 smail代码调试  
		
	* 拷贝smail文件夹 Android Stuido 项目中
	* 工具栏下拉的Edit Configurations
	* 点击+号选择Remote
	* 配置Remote

		```
		Name: smail debug (自己喜欢的名字)
		Port: 8700
		JVM: -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=8700
		(改了端口默认就是这个)
		module: smail文件夹
		```   
	* Debug模式启动应用程序

		```
		adb shell am start -D -n 包名/Launcher类
		```
		
	* 找到应用进程ID

		```
		adb shell ps | grep 包名
		```
	
	* 绑定调试程序到
		
		```
		adb forward tcp:8700 jdwp:2835(上一步找到的进程ID)
		```
		
	* 工具栏下拉的Edit Configurations的位置, 选择我们新建的Remote配置
	* 运行菜单栏Run->Debug "smail debug"
	* 开始调试smail代码
	
	<img src="{{site.assets_path}}/img/android/img-android-jadx-gui-smail.png" width="80%">  

6.	修改, 我们自己签名的肯定跟原包的签名不一样, 那我们就会执行finish, 我们把这个条件改成反向的, 不就跳过这个判断了嘛, 使用文本编辑软件, 修改**if-eqz**为**if-nez**, 保存文件  

7.	重新打包签名, 参照上篇[00:ANDROID逆向工程-APKTOOL重建失败](</android-reverse-apktool-no-resource-found>)