---
title: 01:注解Annotaion(@interface)&标记接口
author: Zhusong
layout: post
footer: true
category: Java
date: 2020-3-19
excerpt: "01:注解Annotaion(@interface)&标记接口"
abstract: ""
---

# 概念
__标记接口(Marker Interface):__ 没有任何实现, 只是做一个抽象, 用于标记一类行为或对象, 比如Serializable, 实现或继承了Serializable就标记它是 ‘可序列化’ 的

```java
/*
 * @author  unascribed
 * @see java.io.ObjectOutputStream
 * @see java.io.ObjectInputStream
 * @see java.io.ObjectOutput
 * @see java.io.ObjectInput
 * @see java.io.Externalizable
 * @since   JDK1.1
 */
public interface Serializable {
}
```

__注解(Annotation):__ 功能其实跟标记接口类似, 但是是从JDK1.5才开始支持的, 在我们现在的开发中, 基本都是使用这个来实现标记的功能。

## Target && Retention

首先打开经常会看到的系统提供的注解(@Override)

```java
/*
* @author  Peter von der Ah&eacute;
 * @author  Joshua Bloch
 * @jls 9.6.1.4 @Override
 * @since 1.5
 */
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.SOURCE)
public @interface Override {
}
```

可以看到注释的定义方式 *@interface* , 发现它上面还有另外2个注解 *@Target* 和 *@Retention* , 我们再看看他们是什么意思


```java
/*
 *
 * @since 1.5
 * @jls 9.6.4.1 @Target
 * @jls 9.7.4 Where Annotations May Appear
 */
@Documented
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.ANNOTATION_TYPE)
public @interface Target {
    /**
     * Returns an array of the kinds of elements an annotation type
     * can be applied to.
     * @return an array of the kinds of elements an annotation type
     * can be applied to
     */
    ElementType[] value();
}

/*
 *
 * @author  Joshua Bloch
 * @since 1.5
 * @jls 9.6.3.2 @Retention
 */
@Documented
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.ANNOTATION_TYPE)
public @interface Retention {
    /**
     * Returns the retention policy.
     * @return the retention policy
     */
    RetentionPolicy value();
}
```

### Target
首先来看Target, 发现它本身也是一个注解, 但是它还是用自己标记了自己, 这个还是有点意思的=。=, 这个属性表示这个注释适用的范围, 比如FIELD(字段), METHOD(方法)等, 并不是唯一的, 他可以支持一个注解支持类型的数组

这个根据需要确定支持哪些范围, FIELD, METHOD, PARAMETER, CONSTRUCTOR是我们平常用的比较多的

进入ElementType看一下有哪些类型


```java
/*
 * @author  Joshua Bloch
 * @since 1.5
 * @jls 9.6.4.1 @Target
 * @jls 4.1 The Kinds of Types and Values
 */
public enum ElementType {
    /** Class, interface (including annotation type), or enum declaration */
    TYPE,

    /** Field declaration (includes enum constants) */
    FIELD,

    /** Method declaration */
    METHOD,

    /** Formal parameter declaration */
    PARAMETER,

    /** Constructor declaration */
    CONSTRUCTOR,

    /** Local variable declaration */
    LOCAL_VARIABLE,

    /** Annotation type declaration */
    ANNOTATION_TYPE,

    /** Package declaration */
    PACKAGE,

    /**
     * Type parameter declaration
     *
     * @since 1.8
     */
    TYPE_PARAMETER,

    /**
     * Use of a type
     *
     * @since 1.8
     */
    TYPE_USE
}
```

### Retention

再来看Retention, 他也是个注解, 他的含义是一个这个注解的保留策略,什么意思呢.
一个Java代码到计算机运行的字节码可以分为3个过程

```
Java源文件(.java文件) ---> Java字节码文件(.class文件) ---> 内存中的字节码。

分别对应着SOURCE --> CLASS --> RUNTIME
```


```java
 /*
 * @author  Joshua Bloch
 * @since 1.5
 */
public enum RetentionPolicy {
    /**
     * Annotations are to be discarded by the compiler.
     */
    SOURCE,

    /**
     * Annotations are to be recorded in the class file by the compiler
     * but need not be retained by the VM at run time.  This is the default
     * behavior.
     */
    CLASS,

    /**
     * Annotations are to be recorded in the class file by the compiler and
     * retained by the VM at run time, so they may be read reflectively.
     *
     * @see java.lang.reflect.AnnotatedElement
     */
    RUNTIME
}
```

* SOURCE  
只在源码级别保留, 到class就移除了,对应就是Java源文件阶段, 它主要是为了让编译期在编译成.class之前检查代码的正确性, 比如Override会检查参数, 方法名, 返回值是不是正确，在生成字节码文件之前, 对基础的语法、要求进行检测, 减少在生成字节码的过程中出现的错误。

* CLASS  
字节码级别保留, 字节码文件是与平台无关的, 它是一种8位字节的二进制流文件(图2), 由Java源码编译器来生成(图1), 是JVM所 **认识** 的指令集(图3).
	 
	可以通过jdk提供的javap来查看指令集
	
	```shell
	javap -v -p xxx.class
	```
	图1  
	![1]({{site.assets_path}}/img/java/java_compiler_class.jpeg){:width="60%"}
		
		
	图2  
	![2]({{site.assets_path}}/img/java/java_class_hex.png){:width="60%"}  
  
   图3   
	![3]({{site.assets_path}}/img/java/java_class_instruction.png){:width="60%"} 

  
* RUNTIME:
运行时仍然保留, 如果是定义这个, 就可以在运行时, 通过反射的方式获取到注解, SOURCE&CLASS到运行时其实已经被移除了。

* 保留范围   
SOURCE < CLASS < RUNTIME  

# 参考链接
  
字节码介绍  
 <https://www.jianshu.com/p/247e2475fc3a>

编译与执行过程  
	<https://www.cnblogs.com/fengyiliang/p/10030092.html>

JVM指令集  
<https://juejin.im/entry/588085221b69e60059035f0a>
<https://docs.oracle.com/javase/specs/jvms/se9/html/jvms-6.html>