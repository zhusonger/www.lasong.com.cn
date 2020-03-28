---
title: 00:字节码class文件的结构
author: Zhusong
layout: post
footer: true
category: Java
date: 2020-3-19
excerpt: "00:字节码class文件的结构"
abstract: ""
---

# 说明

|字符|说明|
|:---:|:---:|
|u1|1个字节无符号数|
|u2|2个字节无符号数|
|ux|x个字节无符号数|
|cp\_info|常量池结构|
|field\_info|字段结构|
|method\_info|方法结构|
|attribute\_info|属性结构|

# Class文件结构

|类型|名称|数量|说明|
|:---:|:---:|:---:|:---:|
|u4|magic|1|魔数, 固定4字节0xCAFEBABE
|u2|minor_version|1|次版本号, 比如1.6.1的.1部分
|u2|major_version|1|主版本号, 比如1.6.1的1.6部分, 当然不是1.6, 是跟版本对应的数字。比如1.6.0是50
|u2|constant\_pool\_count|1|常量池个数
|cp\_info|constant\_pool| constant\_pool\_count-1|常量池, 第一个是预留的, 代表不引用任何常量, 所以常量表索引是从1开始的
|u2|access\_flags|1|表示这个类或接口的访问标志,如果是接口, 会有ACC_INTERFACE标志, 枚举有ACC_ENUM等标志
|u2|this\_class|1|类索引, 从常量池中找到当前类对应的字面量
|u2|super\_class|1|父类索引, 从常量池中找到当前类父类对应的字面量, 这个一般都有, 除非是java.lang.Object 
|u2|interface\_count|1|表示当前类实现的接口个数, 如果为0, 后面的interface字段就不存在
|u2|interfaces|interface_count|实现接口的字面量索引, 从常量表中找
|u2|field\_count|1|字段个数, 用于描述类或接口的全局变量, 不包括方法内的局部变量
|field\_info|fields|field\_count|字段表, 包含访问标志, 简单名称与字段描述符(比如int描述符是I, 在JNI开发中也经常会应用到)等, 从常量池中找, 还有个特殊的, 就是final修饰的全局变量, 会在attribue属性里包含一个ConstantValue代表默认值。
|u2|method\_count|1|当前类或接口的方法个数, 包括构造方法,公有和私有方法, 不包括父类的方法
|method\_info|methods|method\_count|方法表, 跟field\_info的结构一样, 区别就是访问标志。这里系统还会自动添加的构造器方法\<init\>和类构造器方法\<clinit\>, 代码是在method\_info的attribue属性里, 这个具体可以看下面给出的图。
|u2|attribue\_count|1|扩展属性个数
|attribute\_info|attributes|attribue\_count|扩展属性配置, 在JDK给出新特性的时候, 会在这里扩展。

# method\_info

![1]({{site.assets_path}}/img/java/java_class_method.png){:width="60%"}

![2]({{site.assets_path}}/img/java/java_class_method_full.png)

# 参考

深入理解Java Class文件格式（九）  
<https://blog.csdn.net/zhangjg_blog/article/details/22432599>