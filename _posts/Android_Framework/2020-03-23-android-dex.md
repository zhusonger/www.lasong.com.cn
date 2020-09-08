---
title: 00:Android 虚拟机Dalvik & ART
author: Zhusong
layout: post
footer: true
category: Android Framework
date: 2020-3-23
excerpt: "00:Android 虚拟机Dalvik & ART"
abstract: ""
---

# 源码

Android源码  
<https://android.googlesource.com/>

<https://www.androidos.net.cn/sourcecode>

Android通用内核代码  
<https://android.googlesource.com/kernel/common/>

Bootlin Linux系统源码查看  
<https://elixir.bootlin.com/linux/latest/source>


# 一: Android虚拟机

## Dalvik
Android虚拟机Dalvik是Google是为了移动设备平台而开发的, 它可以支持转换为.dex(Dalvik Executable)格式的Java应用程序运行。.dex格式是专为Dalvik设计的一种压缩格式，适合内存和处理器速度有限的系统。Dalvik 经过优化，允许在有限的内存中同时运行多个虚拟机的实例，并且每一个Dalvik 应用作为一个独立的Linux 进程执行。独立的进程可以防止在虚拟机崩溃的时候所有程序都被关闭。

很长时间以来，Dalvik虚拟机一直被用户指责为拖慢安卓系统运行速度不如IOS的根源。

2014年6月25日，Android L 正式亮相于召开的谷歌I/O大会，Android L 改动幅度较大，谷歌将直接删除Dalvik，代替它的是传闻已久的ART。

## ART
Android Runtime (ART) 是 Android 上的应用和部分系统服务使用的托管式运行时。ART 及其前身 Dalvik 最初是专为 Android 项目打造的。作为运行时的 ART 可执行 Dalvik 可执行文件并遵循 Dex 字节码规范。

ART 和 Dalvik 是运行 Dex 字节码的兼容运行时，因此针对 Dalvik 开发的应用也能在 ART 环境中运作。不过，Dalvik 采用的一些技术并不适用于 ART。有关最重要问题的信息，请参阅在 Android Runtime (ART) 上验证应用行为。

[官方ART的更多功能与优化](https://source.android.google.cn/devices/tech/dalvik?hl=zh-tw)

ART就是Dalvik的优化版本的虚拟机, 就跟Java虚拟机也在一直更新换代一样, ART也是Android虚拟机更新的一个更好的虚拟机版本。

# 二: Dex
为什么需要这个新的格式呢, 因为Java字节码每个文件只对应1个类, 读取文件的IO操作较多, 而且相对来说, 字节码文件还是太大了, 在移动平台上内存紧张, 所以又定义了这个dex文件格式, 对class文件再进一步压缩生成dex文件。

记录整个工程中所有类的信息都保存在了dex文件中。

可以通过dx二进制文件进行生成, 并进入adb shell命令后执行

```
dalvikvm -cp xxx.dex classname
```

# 三: Dex的格式

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

# 四: Dex文件与Class文件的异同

## 不同
* 一个Dex包含了所有的类信息, 而Class只有1个类的信息
* 每个class文件都有header, Constant Pool等结构, 一个class对应一个结构体, 1个jar包会包含很多class, 就包含了很多一样的结构体, 而dex就是一整个结构体, 所有类的信息都包含在header, string_ids等结构体中
* dex被Dalvik虚拟机加载, class被java虚拟机加载

## 相同
* 都是8位二进制文件
* dex也是从class压缩进一步得到的, 根源相同

# 五: Java虚拟机Class文件结构

[00:字节码CLASS文件的结构](/java-class)

# 六: Android中65535

## 原因
在Android开发中, 我们经常会碰到, 解决大部分人都知道, 通过ProGuard进行压缩优化, 再不行就是分包。但是原因究竟是什么呢？


首先看报错的位置
[MemberIdsSection.java](https://android.googlesource.com/platform/dalvik/+/c7daf65/dx/src/com/android/dx/dex/file/MemberIdsSection.java)

在生成dex的时候, 会检测每一项的数量, 如果生成的数量超过了DexFormat.MAX\_MEMBER\_IDX, 就会抛出异常。

所以从这里看, 并不是只针对方法的, 所有的类型, 类的字段、类的方法、类、接口, 只要超过都会抛出异常, 只是方法更加容易达到条件抛出而已。 

```java
/** {@inheritDoc} */
@Override
protected void orderItems() {
    int idx = 0;

    if (items().size() > DexFormat.MAX_MEMBER_IDX + 1) {
        throw new DexException(Main.TO_MANY_ID_ERROR_MESSAGE);
    }
    for (Object i : items()) {
        ((MemberIdItem) i).setIndex(idx);
        idx++;
    }
}
```

那这个DexFormat.MAX\_MEMBER\_IDX具体的值是多少呢？  
[MAX\_MEMBER\_IDX](https://android.googlesource.com/platform/dalvik/+/refs/heads/master/dx/src/com/android/dex/DexFormat.java)

值是0xFFFF, 16进制中, 1位代表4bit, 所以这里是4x4=16bit, 16位, 计算结果65535

```java
 /**
 * Maximum addressable field or method index.  
 * The largest addressable member is 0xffff, in the "instruction formats" spec   
 * as field@CCCC or  
 * meth@CCCC.  
 */
public static final int MAX_MEMBER_IDX = 0xFFFF;
```
好像到这里我们得到结论了, 但是, 这里只是我们在编译期生成Dex文件的时候做的处理。  
为什么要做这个处理呢？

其实注释里面已经说明了。  
instruction formatsl: 指令格式  
field@CCCC or meth@CCCC: 字段或方法寄存器的位数  
The largest addressable member is 0xffff: 最大的地址是0xffff

好了 到这里应该一目了然了, 这是因为Davlik的虚拟机指令, field和method的地址最大只能到0xffff, 所以在这里就直接处理掉, 省的到Davlik处理的时候出现越界的问题。

[字节码格式](https://source.android.google.cn/devices/tech/dalvik/dalvik-bytecode?hl=zh-tw)搜索invoke 看到如下的说明

![1]({{site.assets_path}}/img/android/android-instruction.png){:width="90%"}

出现这个问题的根本原因还是因为, Android把字节码文件压缩成一个Dex文件, 把所有的字节码的方法、字段等都集中到一个文件了。

PathClassLoader和DexClassLaoder都是继承自BaseDexClassLoader, 实现都在这里, 所以我们从它开始分析。

在分析之前, 最好了解下Java类加载器的机制。  

[04:类加载器CLASSLOADER](/java-classloader)



## Dex的加载过程分析

* 找到[BaseDexClassLoader](https://android.googlesource.com/platform/libcore-snapshot/+/refs/heads/ics-mr1/dalvik/src/main/java/dalvik/system/BaseDexClassLoader.java), 加载类一般是用loadClass, 自定义类重写findClass方法, 我们找到findClass方法

	```java
	@Override
	protected Class<?> findClass(String name) throws ClassNotFoundException {
	    Class clazz = pathList.findClass(name);
	    if (clazz == null) {
	        throw new ClassNotFoundException(name);
	    }
	    return clazz;
	}
	```
	
	发现它调用的[DexPathList](https://android.googlesource.com/platform/libcore-snapshot/+/refs/heads/ics-mr1/dalvik/src/main/java/dalvik/system/DexPathList.java)的findClass方法

* 我们查看[DexPathList](https://android.googlesource.com/platform/libcore-snapshot/+/refs/heads/ics-mr1/dalvik/src/main/java/dalvik/system/DexPathList.java)findClass方法

	```java
	/**
	 * Finds the named class in one of the dex files pointed at by
	 * this instance. This will find the one in the earliest listed
	 * path element. If the class is found but has not yet been
	 * defined, then this method will define it in the defining
	 * context that this instance was constructed with.
	 *
	 * @return the named class or {@code null} if the class is not
	 * found in any of the dex files
	 */
	public Class findClass(String name) {
	    for (Element element : dexElements) {
	        DexFile dex = element.dexFile;
	        if (dex != null) {
	            Class clazz = dex.loadClassBinaryName(name, definingContext);
	            if (clazz != null) {
	                return clazz;
	            }
	        }
	    }
	    return null;
	}
	```

	发现它是遍历一个数组, dexElements, 这个数组后面再说, 数组的一个元素就是一个Dex文件, 发现它调用的是DexFile的loadClassBinaryName方法, 参数就是类的全限定名以及definingContext, definingContext就是BaseDexClassLoader, 就是应用唯一的PathClassLoader

* 继续, 查看[DexFile](https://android.googlesource.com/platform/libcore-snapshot/+/refs/heads/ics-mr1/dalvik/src/main/java/dalvik/system/DexFile.java)的loadClassBinaryName方法

	```java
	/**
	 * See {@link #loadClass(String, ClassLoader)}.
	 *
	 * This takes a "binary" class name to better match ClassLoader semantics.
	 *
	 * @hide
	 */
	public Class loadClassBinaryName(String name, ClassLoader loader) {
	    return defineClass(name, loader, mCookie);
	}
	
	private native static Class defineClass(String name, ClassLoader loader, int cookie);
	```
	
	这里我们来对比下JDK中自带的ClassLoader的defineClass方法
	
	```java
	protected final Class<?> defineClass(String name, byte[] b, int off, int len)
	    throws ClassFormatError
	{
	    return defineClass(name, b, off, len, null);
	}
	```
	
	发现区别了么, JDK下是传入了字节码文件的字节数组, 而Android传入的是个cookie, 这是什么呀, 一头雾水。我们来找下传入的mCookie是哪里赋值的。

* 找到mCookie赋值的位置

	```java
	public DexFile(String fileName) throws IOException {
	    mCookie = openDexFile(fileName, null, 0);
	    mFileName = fileName;
	    guard.open("close");
	    //System.out.println("DEX FILE cookie is " + mCookie);
	}
	
	/*
	 * Open a DEX file.  The value returned is a magic VM cookie.  On
	 * failure, an IOException is thrown.
	 */
	native private static int openDexFile(String sourceName, String outputName,
	    int flags) throws IOException;
	```
	OK, 找到了, 这里就是把Dex文件打开, 其实就是把Dex文件读取到方法区中存储类的元数据信息。并返回一个标志你这个Dex的cookie。那我们加载一个全限定名的类时, 根据cookie去对应的Dex内容去取。

* End   
	我们再来说下dexElements这个数组, 默认情况下, 如果没有分包, 一个应用就一个Dex文件, 同时为了支持扩展, 可以再往里加载更多的Dex文件。跟加载字节码文件一样。同时这也是解决65535的根本。

## 解决

通过上面Dex文件的加载, 我想大部分拥有独立思考能力的小伙伴知道怎么解决65535的问题了吧, 产生的原因是一个Dex归并了所有的方法、字段, 既然装不下了, 我们再创建一个新的Dex文件, 把放不下的方法、字段放进去不就行了么。具体实现就不再分析了。看下Android提供的解决思路。看下MultiDex类的installSecondaryDexes方法即可。很简单明了。

```java
private static void installSecondaryDexes(ClassLoader loader, File dexDir,
        List<? extends File> files)
        throws IllegalArgumentException, IllegalAccessException, NoSuchFieldException,
        InvocationTargetException, NoSuchMethodException, IOException, SecurityException,
        ClassNotFoundException, InstantiationException {
    if (!files.isEmpty()) {
        if (Build.VERSION.SDK_INT >= 19) {
            V19.install(loader, files, dexDir);
        } else if (Build.VERSION.SDK_INT >= 14) {
            V14.install(loader, files);
        } else {
            V4.install(loader, files);
        }
    }
}
```

参考Android提供的解决思路  
<https://developer.android.com/studio/build/multidex?hl=zh-cn>

顺便一提, ART并不是不需要分包, 可以理解成在安装应用的时候, 把字节码直接编译成了机器码, 包含到一个oat文件中。在硬件中其实是支持u4的范围(2^32-1), 所以就不存在65535的问题。

这里涉及到的就是Java虚拟机的执行方式。

* 解释执行
* JIT编译的代码执行

Java虚拟机HotSpot是同时运行的。C++是在运行前把所有的代码都编译成平台代码执行的。Java早期是只有解释执行的, 就是执行一句编译一句平台代码并执行, 这样就会造成运行的时候需要额外的编译步骤,所以在早期造成Java运行速度慢, 随着Java技术的发展。JIT及时编译技术的发展, 解释执行使用平台相关的模板实现。速度已经跟单纯的平台代码接近了。当然无法完全接近。毕竟为了平台兼容性。

那Android虚拟机Dalvik呢, 当然是采用的解释执行啦！为什么呢？

因为解释执行的启动速度快啊！如果采用编译之前, 你打开一个应用, 需要等到你把字节码编译成平台代码。那你就傻等着了。这在现在普遍在做的启动优化这类处理的方向可以看出，这是一种用户体验极差的方式。

但是这样就没有机器平台代码相关的速度优势了。怎么办呢？

ART应运而生。

它的原理是在安装应用的时候, 我先生成机器平台相关的代码, 因为安装的时候可以接受一点等待的。为了以后使用应用的时候爽，我就忍忍吧。

同时, ART还开发了一套[JIT编译器](https://source.android.google.cn/devices/tech/dalvik/jit-compiler?hl=zh-tw), 应用越跑越快了有没有，真棒！

