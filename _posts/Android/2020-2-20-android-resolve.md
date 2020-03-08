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

解决方式:

* 打开项目的gradle文件夹 => wrapper文件夹 => gradle-wrapper.properties, 拷贝distributionUrl地址   
* 打开浏览器输入distributionUrl地址,自己下载好文件  
* 进入~/.gradle/wrapper/dists/gradle-{版本号}-all/{电脑上的一串符号}/  
* 删除后缀.part文件, 创建空文件gradle-{版本号}-all.zip.ok, 可以去其他文件夹目录拷贝一个, 然后修改名字  
* 拷贝下载的gradle压缩包到当前目录, 并解压
* 重新同步

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


	
	