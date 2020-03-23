---
title: 03:类加载器ClassLoader
author: Zhusong
layout: post
footer: true
category: Java
date: 2020-3-23
excerpt: "03:类加载器ClassLoader"
abstract: ""
---

# 概念
从上篇文章[02:注解处理器&反射](/annotation-processor)中了解到, 从Java源码(.java)到字节码文件(.class), 最后加载到内存中生成java.lang.Class对象表示一个类, 这个加载过程就是由类加载器来实现的。

加载的过程由三个大步骤实现:
加载 => 连接(验证,准备,解析) => 初始化

> 1、加载   
”加载“是”类加机制”的第一个过程，在加载阶段，虚拟机主要完成三件事：   
（1）通过一个类的全限定名来获取其定义的二进制字节流   
（2）将这个字节流所代表的的静态存储结构转化为方法区的运行时数据结构   
（3）在堆中生成一个代表这个类的Class对象，作为方法区中这些数据的访问入口。   
>
相对于类加载的其他阶段而言，加载阶段是可控性最强的阶段，因为程序员可以使用系统的类加载器加载，还可以使用自己的类加载器加载。我们在最后一部分会详细介绍这个类加载器。在这里我们只需要知道类加载器的作用就是上面虚拟机需要完成的三件事，仅此而已就好了。  
>
2、验证   
验证的主要作用就是确保被加载的类的正确性。也是连接阶段的第一步。说白了也就是我们加载好的.class文件不能对我们的虚拟机有危害，所以先检测验证一下。他主要是完成四个阶段的验证：   
（1）文件格式的验证：验证.class文件字节流是否符合class文件的格式的规范，并且能够被当前版本的虚拟机处理。这里面主要对魔数、主版本号、常量池等等的校验（魔数、主版本号都是.class文件里面包含的数据信息、在这里可以不用理解）。   
（2）元数据验证：主要是对字节码描述的信息进行语义分析，以保证其描述的信息符合java语言规范的要求，比如说验证这个类是不是有父类，类中的字段方法是不是和父类冲突等等。   
（3）字节码验证：这是整个验证过程最复杂的阶段，主要是通过数据流和控制流分析，确定程序语义是合法的、符合逻辑的。在元数据验证阶段对数据类型做出验证后，这个阶段主要对类的方法做出分析，保证类的方法在运行时不会做出危害虚拟机安全的事。   
（4）符号引用验证：它是验证的最后一个阶段，发生在虚拟机将符号引用转化为直接引用的时候。主要是对类自身以外的信息进行校验。目的是确保解析动作能够完成。   
>
对整个类加载机制而言，验证阶段是一个很重要但是非必需的阶段，如果我们的代码能够确保没有问题，那么我们就没有必要去验证，毕竟验证需要花费一定的的时间。当然我们可以使用-Xverfity:none来关闭大部分的验证。   
> 3、准备   
准备阶段主要为类变量分配内存并设置初始值。这些内存都在方法区分配。在这个阶段我们只需要注意两点就好了，也就是类变量和初始值两个关键词：  
（1）类变量（static）会分配内存，但是实例变量不会，实例变量主要随着对象的实例化一块分配到java堆中    
（2）这里的初始值指的是数据类型默认值，而不是代码中被显示赋予的值。比如  
>
>	     //在这里准备阶段过后的value值为0，而不是1。赋值为1的动作在初始化阶段。     
>	     public static int value = 1;
>
> 当然还有其他的默认值。
> 
注意，在上面value是被static所修饰的准备阶段之后是0，但是如果同时被final和static修饰准备阶段之后就是1了。我们可以理解为static final在编译期就将结果放入调用它的类的常量池中了。
> 
4、解析   
解析阶段主要是虚拟机将常量池中的符号引用转化为直接引用的过程。什么是符号引用和直接引用呢？ 
> 
符号引用：以一组符号来描述所引用的目标，可以是任何形式的字面量，只要是能无歧义的定位到目标就好，就好比在班级中，老师可以用张三来代表你，也可以用你的学号来代表你，但无论任何方式这些都只是一个代号（符号），这个代号指向你（符号引用）  
>
直接引用：直接引用是可以指向目标的指针、相对偏移量或者是一个能直接或间接定位到目标的句柄。和虚拟机实现的内存有关，不同的虚拟机直接引用一般不同。  
解析动作主要针对类或接口、字段、类方法、接口方法、方法类型、方法句柄和调用点限定符7类符号引用进行。  
这里不是很好理解, 这篇文章讲的很好  
<https://blog.csdn.net/u010386612/article/details/80105951>   
>
在之前的[01:注解ANNOTAION(@INTERFACE)&标记接口](java-anotation/)里有张图   
> ![3]({{site.assets_path}}/img/java/java_class_instruction.png){:width="60%"}      
> 
> 这里有一个常量池(Constant Pool), 在编译成字节码的时候, 还不知道具体的内存分配地址, 所以这里是以符号替代的。即符号引用。   
> 比如当我们使用到某个方法时, 会把字符根据规则一步步查找, 比如#1, 就定位到#1, 原本是一个字符串, 那比如我们在类加载的时候给它分配了一个地址, 如0x000001, 那这里就直接替换为 #1 0x000001, 可以直接得到字符串在内存中所在的位置。
> 注意这里是在需要使用的时候才会去解析, 默认加载后还是跟字节码是一致的。
> 
> 5、初始化   
这是类加载机制的最后一步，在这个阶段，java程序代码才开始真正执行。我们知道，在准备阶段已经为类变量赋过一次值。在初始化阶端，程序员可以根据自己的需求来赋值了。一句话描述这个阶段就是执行类构造器<clinit>()方法的过程。 关于<clinit>与<init>的区别参照这篇文章  
<https://blog.csdn.net/u013309870/article/details/72975536>
>
在初始化阶段，主要为类的静态变量赋予正确的初始值，JVM负责对类进行初始化，主要对类变量进行初始化。在Java中对类变量进行初始值设定有两种方式：

> ①声明类变量是指定初始值  
>	static final int A = 1;  
> ②使用静态代码块为类变量指定初始值  
>	static int A;    
>	static {   
>		A = 1;  
>	}   
>
> 
> JVM初始化<init>步骤
>
> 1、假如这个类还没有被加载和连接，则程序先加载并连接该类  
> 2、假如该类的直接父类还没有被初始化，则先初始化其直接父类  
> 3、假如类中有初始化语句，则系统 __依次__ 执行这些初始化语句  

> 类初始化时机：只有当对类的主动使用的时候才会导致类的初始化，类的主动使用包括以下六种：

> * 创建类的实例，也就是new的方式
> * 访问某个类或接口的静态变量，或者对该静态变量赋值
> * 调用类的静态方法
> * 反射（如 Class.forName(“com.shengsiyuan.Test”)）
> * 初始化某个类的子类，则其父类也会被初始化
> * Java虚拟机启动时被标明为启动类的类（ JavaTest），直接使用 java.exe命令来运行某个主类
> 
> 虚拟机会保证一个类的\<clinit\>()方法在多线程环境中被正确地加锁、同步，如果多个线程同时去初始化一个类，那么只会有一个线程去执行这个类的\<clinit\>()方法，其他线程都需要阻塞等待，直到活动线程执行\<clinit\>()方法完毕。  
> 
> 基于这个原理, 以及上面说的情况下才对类进行的初始化, 就是一种线程安全且是延迟加载实例化单例的一种单例模式, 内部类单例模式
> 
> 
> 好了，到目前为止就是类加载机制的整个过程，但是还有一个重要的概念，那就是类加载器。在加载阶段其实我们提到过类加载器，说是在后面详细说，在这就好好地介绍一下类加载器。


# 类加载器

类加载器主要有两类: 一类是系统提供的, 一类是自定义类加载器。

## 系统类加载器 

* Bootstrap ClassLoader: 最顶层的类加载器, 由C++实现, 是虚拟机的一部分, 只加载核心库(\<JAVA_HOME\>/jre/lib), 出于安全考虑, Bootstrap类加载器只加载java,javax,sun开头的类。所有类的父类Object就是由Bootstrap类加载器加载的。但是获取getClassLoader时返回空。

* Extention ClassLoader: 扩展的类加载器, 加载扩展库(\<JAVA_HOME\>/jre/lib/ext)

* App ClassLoader: 也成为系统加载器, 返回当前应用下的所有类, 继承自URLClassLoader, 读取java.class.path路径下的所有字节码文件。

## 自定义类加载器
* 继承ClassLoader, 重写findClass方法, 这样会遵守类加载器的双亲委托机制。他的构造方法默认是取当前应用系统类加载器, 如果没有定义__java.system.class.loader__, 就使用应用启动的AppClass Loader, 否则使用定义的指定类加载器。

* 继承ClassLoader, 但是重写loadClass方法, 这样会破坏双亲委托机制。推荐都是重写findClass方法。

## 线程上下文类加载器
在核心库中定义了接口, 但是实现是由第三方来实现的(SPI), 比如JDBC, 这个时候就有矛盾点了, Bootstrap类加载器只加载核心类, 第三方实现是由AppClassLoader来加载的, 那它怎么获取到第三方实现的, 双亲委派机制只能向上查找, 并不是往下查找, 为了解决这个问题, 引入了ContextClassLoader,  默认创建的线程都会设置当前线程的contextClassLoader。这里我们看一下Thread的源码

```java
public Thread() {
	// 初始化Thread
    init(null, null, "Thread-" + nextThreadNum(), 0);
}

private void init(ThreadGroup g, Runnable target, String name,
                      long stackSize, AccessControlContext acc) {
    
	// 获取当前线程
    Thread parent = currentThread();
    SecurityManager security = System.getSecurityManager();

    // ...省略
    
    // 这里就是获取当前线程的ContextClassLoader, 在第一个启动的类就是main方法所在的类
    // main方法所在的类使用的类加载器就是App ClassLoader, 在Launcher中创建
    // 所以默认情况下, 新建的线程的ContextClassLoader就是App ClassLoader
    // 即加载了JDBC类的类加载器
    if (security == null || isCCLOverridden(parent.getClass()))
        this.contextClassLoader = parent.getContextClassLoader();
    else
        this.contextClassLoader = parent.contextClassLoader;
    // 省略
    /* Set thread ID */
    tid = nextThreadID();
}

public static void main(String[] args) {
	// 创建一个线程并启动
    Thread thread = new Thread();
    thread.start();
}
```

这里我们看到了什么时候配置了上下文加载器, 那JDBC怎么使用的呢？
再来看DriverManager是怎么加载实现类。  

```
//  Worker method called by the public getConnection() methods.
private static Connection getConnection(
    String url, java.util.Properties info, Class<?> caller) throws SQLException {
    /*
     * When callerCl is null, we should check the application's
     * (which is invoking this class indirectly)
     * classloader, so that the JDBC driver class outside rt.jar
     * can be loaded from here.
     */
     // 这里我们获取调用这个方法的类加载器
     // 这里如果找不到调用者的类加载器, 就使用上下文类加载器
     // 这里的上下文类加载器就是当前线程的, 即App ClassLoader
    ClassLoader callerCL = caller != null ? caller.getClassLoader() : null;
    synchronized(DriverManager.class) {
        // synchronize loading of the correct classloader.
        if (callerCL == null) {
            callerCL = Thread.currentThread().getContextClassLoader();
        }
    }
    //...省略

    for(DriverInfo aDriver : registeredDrivers) {
        // If the caller does not have permission to load the driver then
        // skip it.
        // 这里就是我们用来加载JDBC实现类的方法, 这里传入实现类可以被加载的类加载器
        if(isDriverAllowed(aDriver.driver, callerCL)) {
            //...省略

        } else {
            println("    skipping: " + aDriver.getClass().getName());
        }

    }
}

private static boolean isDriverAllowed(Driver driver, ClassLoader classLoader) {
    boolean result = false;
    if(driver != null) {
        Class<?> aClass = null;
        // 这里传入类的全限定名, 并传入App ClassLoader, 来加载JDBC驱动的实现类。
        try {
            aClass =  Class.forName(driver.getClass().getName(), true, classLoader);
        } catch (Exception ex) {
            result = false;
        }

         result = ( aClass == driver.getClass() ) ? true : false;
    }

    return result;
}
```


# 自定义类加载器实现
* 继承ClassLoader, 创建自定义类加载器类   
* 重写findClass, 通过类名(全限定名)加载字节码文件成字节数组    
* 使用自定义类加载器加载类   

	```java
	public class MyClassLoader extends ClassLoader {
	    public MyClassLoader(ClassLoader parent) {
	        super(parent);
	    }
	
	    public MyClassLoader() {
	        super();
	    }
	
	    @Override
	    protected Class<?> findClass(String name) throws ClassNotFoundException {
	        // TODO 从网络或者本地加载字节码文件, 转换成字节数组
	        byte[] data = new byte[1024];
	        return defineClass(name, data, 0, data.length);
	    }
	}
	
	public static void main(String[] args) {   
		MyClassLoader cl = new MyClassLoader();   
		cl.loadClass("cn.com.lasong.Test");   
	}  
	```
	
# 自定义类加载器的应用

## 热部署
热部署是在Web应用中普遍使用的一种技术, 就是不需要重新启动服务器, 就可以加载最新的代码。他的实现方式就是依靠自定义类加载器。
一种简单的过程:    

* 自定义类加载器, 传入字节码文件的路径, 用于读取字节码文件转换成字节数组  
* 创建一个定时任务检测字节码文件修改时间, 如果修改了, 重新loadClass, 使用新的class类创建新的对象  

	> 注意: 这里需要传入父加载器类, 否则默认使用的是当前应用的AppClassLoader, 这样加载应用内的类时, 会先从AppClassLoader查找, 不会执行自定义类加载器的findClass方法。

* 定义另一个定时任务去执行类的方法, 在不关闭应用的情况下, 会发现执行的结果发生了变化。 


	
# 参考链接
  
Java中init和clinit区别完全解析   
<https://blog.csdn.net/u013309870/article/details/72975536>

Java类加载机制，你理解了吗？  
<https://baijiahao.baidu.com/s?id=1636309817155065432&wfr=spider&for=pc>

自定义类加载器   
<https://www.jianshu.com/p/6d08135c8e28>