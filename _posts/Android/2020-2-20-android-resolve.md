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

# [__Gradle同步问题__](https://www.jianshu.com/p/24a38f8400cc)  

新建项目卡在Gradle sync步骤，通过模拟Android Studio下载Gradle的过程来跳过IDE的下载过程, 因为它比较慢  

解决方式:

* 打开项目的gradle文件夹 => wrapper文件夹 => gradle-wrapper.properties, 拷贝distributionUrl地址   
* 打开浏览器输入distributionUrl地址,自己下载好文件  
* 进入~/.gradle/wrapper/dists/gradle-{版本号}-all/{电脑上的一串符号}/  
* 删除后缀.part文件, 创建空文件gradle-{版本号}-all.zip.ok, 可以去其他文件夹目录拷贝一个, 然后修改名字  
* 拷贝下载的gradle压缩包到当前目录, 并解压
* 重新同步