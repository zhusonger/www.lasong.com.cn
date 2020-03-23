---
title: 00:Android 虚拟机Dalvik
author: Zhusong
layout: post
footer: true
category: Android Framework
date: 2020-3-23
excerpt: "00:Android 虚拟机Dalvik"
abstract: ""
---

# 一: Android虚拟机Dalvik
Android虚拟机Dalvik是Google是为了移动设备平台而开发的, 它可以支持转换为.dex(Dalvik Executable)格式的Java应用程序运行。.dex格式是专为Dalvik设计的一种压缩格式，适合内存和处理器速度有限的系统。Dalvik 经过优化，允许在有限的内存中同时运行多个虚拟机的实例，并且每一个Dalvik 应用作为一个独立的Linux 进程执行。独立的进程可以防止在虚拟机崩溃的时候所有程序都被关闭。

很长时间以来，Dalvik虚拟机一直被用户指责为拖慢安卓系统运行速度不如IOS的根源。

2014年6月25日，Android L 正式亮相于召开的谷歌I/O大会，Android L 改动幅度较大，谷歌将直接删除Dalvik，代替它的是传闻已久的ART。

# Dex
为什么需要这个新的格式呢, 因为Java字节码每个文件只对应1个类, 读取文件的IO操作较多, 而且相对来说, 字节码文件还是太大了, 在移动平台上内存紧张, 所以又定义了这个dex文件格式, 对class文件再进一步压缩生成dex文件。

记录整个工程中所有类的信息都保存在了dex文件中。

可以通过dx二进制文件进行生成, 并进入adb shell命令后执行

```
dalvikvm -cp xxx.dex classname
```

# Dex的格式

* 一种8位字节的二进制文件
* 各个数据按顺序紧密排列, 无间隙
* __整个__ 应用中所有Java源文件都放在一个dex中

| 字段 |  描述 |		大类型 |
| --- | ---   | ---|
|header| 文件头|  文件头: dex整体文件信息, 文件大小, 各个类型的个数与偏移等|
|string_ids| 字符串的索引| 索引区: 字符串/方法/类的符号索引|
|type_ids| 类型的索引|
|proto_ids| 方法原型的索引|
|field_ids| 域的索引|
|method_ids| 方法的索引|
|class_defs| 类的定义去| 数据区:通过索引区的位置、偏移、个数, 得到一个数据数组, 这个的存储结构跟class类似 |
|data| 数据区|
|link_data| 链接数据区|

# Dex文件与Class文件的异同

## 不同
* 一个Dex包含了所有的类信息, 而Class只有1个类的信息
* 每个class文件都有header, Constant Pool等结构, 一个class对应一个结构体, 1个jar包会包含很多class, 就包含了很多一样的结构体, 而dex就是一整个结构体, 所有类的信息都包含在header, string_ids等结构体中
* dex被Dalvik虚拟机加载, class被java虚拟机加载

## 相同
* 都是8位二进制文件
* dex也是从class压缩进一步得到的, 根源相同

# JVM结构

