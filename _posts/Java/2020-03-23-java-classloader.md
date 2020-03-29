---
title: 04:类加载器ClassLoader
author: Zhusong
layout: post
footer: true
category: Java
date: 2020-3-23
excerpt: "04:类加载器ClassLoader"
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
（3）在内存中生成一个代表这个类的Class对象，作为方法区中这些数据的访问入口。   
>
相对于类加载的其他阶段而言，加载阶段是可控性最强的阶段，因为程序员可以使用系统的类加载器加载，还可以使用自己的类加载器加载。我们在后面会详细介绍这个类加载器。在这里我们只需要知道类加载器的作用就是上面虚拟机需要完成的三件事，仅此而已就好了。  
> 
> 这里的这个运行时数据结构,没有具体限制, 由虚拟机自己来实现, 生成java.lang.Class对象, 并没有说明是放在堆还是方法区中, 由于Class属于比较稳定的, 不易被回收的, 一般的实现就是放在方法区的。
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
注意，在上面value是被static所修饰的准备阶段之后是0，但是如果同时被final和static修饰准备阶段之后就是1了。我们可以理解为static final在编译期就将结果放入调用它的类的常量池中了。这里利用的是attribute里的ConstantValue字段。
> 
4、解析   
解析阶段主要是虚拟机将常量池中的符号引用转化为直接引用的过程。什么是符号引用和直接引用呢？ 
> 
符号引用：以一组符号来描述所引用的目标，可以是任何形式的字面量，只要是能无歧义的定位到目标就好，就好比在班级中，老师可以用张三来代表你，也可以用你的学号来代表你，但无论任何方式这些都只是一个代号（符号），这个代号指向你（符号引用）  
>
直接引用：直接引用是可以指向目标的指针、相对偏移量或者是一个能直接或间接定位到目标的句柄。和虚拟机实现的内存有关，不同的虚拟机直接引用一般不同。  
解析动作主要针对类或接口、字段、类方法、接口方法、方法类型、方法句柄和调用点限定符7类符号引用进行。  
这里不是很好理解, 下面再通过代码说明一下
>
解析发生的时间没有规定, 只要求固定的JVM指令前进行解析  
解析时间由虚拟机自行决定, 可以类在加载时就全部解析, 也可以用到的时候再去解析  
解析前与解析完之后指令也会有改变, 表示已经解析过了  
invokevirtual => invokevirtual_quick
>
>
在之前的[01:注解ANNOTAION(@INTERFACE)&标记接口](java-anotation/)里有张图   
> ![3]({{site.assets_path}}/img/java/java_class_instruction.png){:width="60%"}      
> 
> 这里有一个常量池(Constant Pool), 在编译成字节码的时候, 还不知道具体的内存分配地址, 所以这里是以符号替代的。即符号引用。   
> 比如当我们使用到某个方法时, 会把字符根据规则一步步查找, 比如#1, 就定位到#1, 原本是一个字符串, 那比如我们在类加载的时候给它分配了一个地址, 如0x000001, 那这里就直接替换为 #1 0x000001, 可以直接得到字符串在内存中所在的位置。
> 
> 5、初始化\<clinit\>   
> 这个方法由虚拟机收集 __类中类变量__ 所有的赋值以及 __静态语句块__ 生成。 他的顺序是根据代码中的顺序决定的。
> 
这是类加载机制的最后一步，在这个阶段，java程序代码才开始真正执行。我们知道，在准备阶段已经为类变量赋过一次 __初始值__ 。在初始化阶端，程序员可以根据自己的需求来赋值了。一句话描述这个阶段就是执行类构造器<clinit>()方法的过程。 关于<clinit>与<init>的区别参照这篇文章 
 
<https://blog.csdn.net/u013309870/article/details/72975536>
>
在初始化阶段，主要为类的静态变量赋予正确的初始值，以及执行静态代码, JVM负责对类进行初始化，主要对类变量进行初始化。在Java中对类变量进行初始值设定有两种方式：

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



## 符号引用与直接引用
首先通过javap查看一下字节码 以及 Java源码, 先过一下, 下面仔细说

```java
// Java文件
public class TestReference {
    private final String globalFinalVariable = "不可变类变量";
    private String globalVariable = "可变类变量";
    private int globalVariableInt = 1;
    private int globalVariableInt2 = 127;
    private int globalVariableInt3 = 32767;
    private int globalVariableInt4 = 32768;

    private float globalVariableFloat = 5.0f;

    private boolean globalVariableBoolean = false;
    private char globalVariableChar = 'a';

    private static int staticVariable = 32768;
    private List<Integer> globalVariableList = new ArrayList<>();
    public TestReference() {
    }

    public TestReference(String string) {
        this.globalVariable = string;
        globalVariableList.add(globalVariableInt);
        globalVariableList.add(globalVariableInt2);
        globalVariableList.add(globalVariableInt3);
        globalVariableList.add(globalVariableInt4);
    }

    public int test(int a) {
        return a;
    }
    public static void main(String[] args) {
        String localVariable = "方法体局部变量";

        System.out.println("说明符号引用与直接引用");
    }
}

// Class文件
public class cn.com.lasong.leetcode.TestReference
  minor version: 0
  major version: 52
  flags: ACC_PUBLIC, ACC_SUPER
Constant pool:
   #1 = Methodref          #26.#59        // java/lang/Object."<init>":()V
   #2 = String             #60            // 不可变类变量
   #3 = Fieldref           #25.#61        // cn/com/lasong/leetcode/TestReference.globalFinalVariable:Ljava/lang/String;
   #4 = String             #62            // 可变类变量
   #5 = Fieldref           #25.#63        // cn/com/lasong/leetcode/TestReference.globalVariable:Ljava/lang/String;
   #6 = Fieldref           #25.#64        // cn/com/lasong/leetcode/TestReference.globalVariableInt:I
   #7 = Fieldref           #25.#65        // cn/com/lasong/leetcode/TestReference.globalVariableInt2:I
   #8 = Fieldref           #25.#66        // cn/com/lasong/leetcode/TestReference.globalVariableInt3:I
   #9 = Integer            32768
  #10 = Fieldref           #25.#67        // cn/com/lasong/leetcode/TestReference.globalVariableInt4:I
  #11 = Float              5.0f
  #12 = Fieldref           #25.#68        // cn/com/lasong/leetcode/TestReference.globalVariableFloat:F
  #13 = Fieldref           #25.#69        // cn/com/lasong/leetcode/TestReference.globalVariableBoolean:Z
  #14 = Fieldref           #25.#70        // cn/com/lasong/leetcode/TestReference.globalVariableChar:C
  #15 = Class              #71            // java/util/ArrayList
  #16 = Methodref          #15.#59        // java/util/ArrayList."<init>":()V
  #17 = Fieldref           #25.#72        // cn/com/lasong/leetcode/TestReference.globalVariableList:Ljava/util/List;
  #18 = Methodref          #73.#74        // java/lang/Integer.valueOf:(I)Ljava/lang/Integer;
  #19 = InterfaceMethodref #75.#76        // java/util/List.add:(Ljava/lang/Object;)Z
  #20 = String             #77            // 方法体局部变量
  #21 = Fieldref           #78.#79        // java/lang/System.out:Ljava/io/PrintStream;
  #22 = String             #80            // 说明符号引用与直接引用
  #23 = Methodref          #81.#82        // java/io/PrintStream.println:(Ljava/lang/String;)V
  #24 = Fieldref           #25.#83        // cn/com/lasong/leetcode/TestReference.staticVariable:I
  #25 = Class              #84            // cn/com/lasong/leetcode/TestReference
  #26 = Class              #85            // java/lang/Object
  #27 = Utf8               globalFinalVariable
  #28 = Utf8               Ljava/lang/String;
  #29 = Utf8               ConstantValue
  #30 = Utf8               globalVariable
  #31 = Utf8               globalVariableInt
  #32 = Utf8               I
  #33 = Utf8               globalVariableInt2
  #34 = Utf8               globalVariableInt3
  #35 = Utf8               globalVariableInt4
  #36 = Utf8               globalVariableFloat
  #37 = Utf8               F
  #38 = Utf8               globalVariableBoolean
  #39 = Utf8               Z
  #40 = Utf8               globalVariableChar
  #41 = Utf8               C
  #42 = Utf8               staticVariable
  #43 = Utf8               globalVariableList
  #44 = Utf8               Ljava/util/List;
  #45 = Utf8               Signature
  #46 = Utf8               Ljava/util/List<Ljava/lang/Integer;>;
  #47 = Utf8               <init>
  #48 = Utf8               ()V
  #49 = Utf8               Code
  #50 = Utf8               LineNumberTable
  #51 = Utf8               (Ljava/lang/String;)V
  #52 = Utf8               test
  #53 = Utf8               (I)I
  #54 = Utf8               main
  #55 = Utf8               ([Ljava/lang/String;)V
  #56 = Utf8               <clinit>
  #57 = Utf8               SourceFile
  #58 = Utf8               TestReference.java
  #59 = NameAndType        #47:#48        // "<init>":()V
  #60 = Utf8               不可变类变量
  #61 = NameAndType        #27:#28        // globalFinalVariable:Ljava/lang/String;
  #62 = Utf8               可变类变量
  #63 = NameAndType        #30:#28        // globalVariable:Ljava/lang/String;
  #64 = NameAndType        #31:#32        // globalVariableInt:I
  #65 = NameAndType        #33:#32        // globalVariableInt2:I
  #66 = NameAndType        #34:#32        // globalVariableInt3:I
  #67 = NameAndType        #35:#32        // globalVariableInt4:I
  #68 = NameAndType        #36:#37        // globalVariableFloat:F
  #69 = NameAndType        #38:#39        // globalVariableBoolean:Z
  #70 = NameAndType        #40:#41        // globalVariableChar:C
  #71 = Utf8               java/util/ArrayList
  #72 = NameAndType        #43:#44        // globalVariableList:Ljava/util/List;
  #73 = Class              #86            // java/lang/Integer
  #74 = NameAndType        #87:#88        // valueOf:(I)Ljava/lang/Integer;
  #75 = Class              #89            // java/util/List
  #76 = NameAndType        #90:#91        // add:(Ljava/lang/Object;)Z
  #77 = Utf8               方法体局部变量
  #78 = Class              #92            // java/lang/System
  #79 = NameAndType        #93:#94        // out:Ljava/io/PrintStream;
  #80 = Utf8               说明符号引用与直接引用
  #81 = Class              #95            // java/io/PrintStream
  #82 = NameAndType        #96:#51        // println:(Ljava/lang/String;)V
  #83 = NameAndType        #42:#32        // staticVariable:I
  #84 = Utf8               cn/com/lasong/leetcode/TestReference
  #85 = Utf8               java/lang/Object
  #86 = Utf8               java/lang/Integer
  #87 = Utf8               valueOf
  #88 = Utf8               (I)Ljava/lang/Integer;
  #89 = Utf8               java/util/List
  #90 = Utf8               add
  #91 = Utf8               (Ljava/lang/Object;)Z
  #92 = Utf8               java/lang/System
  #93 = Utf8               out
  #94 = Utf8               Ljava/io/PrintStream;
  #95 = Utf8               java/io/PrintStream
  #96 = Utf8               println
{
  public cn.com.lasong.leetcode.TestReference();
    descriptor: ()V
    flags: ACC_PUBLIC
    Code:
      stack=3, locals=1, args_size=1
         0: aload_0
         1: invokespecial #1                  // Method java/lang/Object."<init>":()V
         4: aload_0
         5: ldc           #2                  // String 不可变类变量
         7: putfield      #3                  // Field globalFinalVariable:Ljava/lang/String;
        10: aload_0
        11: ldc           #4                  // String 可变类变量
        13: putfield      #5                  // Field globalVariable:Ljava/lang/String;
        16: aload_0
        17: iconst_1
        18: putfield      #6                  // Field globalVariableInt:I
        21: aload_0
        22: bipush        127
        24: putfield      #7                  // Field globalVariableInt2:I
        27: aload_0
        28: sipush        32767
        31: putfield      #8                  // Field globalVariableInt3:I
        34: aload_0
        35: ldc           #9                  // int 32768
        37: putfield      #10                 // Field globalVariableInt4:I
        40: aload_0
        41: ldc           #11                 // float 5.0f
        43: putfield      #12                 // Field globalVariableFloat:F
        46: aload_0
        47: iconst_0
        48: putfield      #13                 // Field globalVariableBoolean:Z
        51: aload_0
        52: bipush        97
        54: putfield      #14                 // Field globalVariableChar:C
        57: aload_0
        58: new           #15                 // class java/util/ArrayList
        61: dup
        62: invokespecial #16                 // Method java/util/ArrayList."<init>":()V
        65: putfield      #17                 // Field globalVariableList:Ljava/util/List;
        68: return
      LineNumberTable:
        line 27: 0
        line 13: 4
        line 14: 10
        line 15: 16
        line 16: 21
        line 17: 27
        line 18: 34
        line 20: 40
        line 22: 46
        line 23: 51
        line 26: 57
        line 28: 68

  public cn.com.lasong.leetcode.TestReference(java.lang.String);
    descriptor: (Ljava/lang/String;)V
    flags: ACC_PUBLIC
    Code:
      stack=3, locals=2, args_size=2
         0: aload_0
         1: invokespecial #1                  // Method java/lang/Object."<init>":()V
         4: aload_0
         5: ldc           #2                  // String 不可变类变量
         7: putfield      #3                  // Field globalFinalVariable:Ljava/lang/String;
        10: aload_0
        11: ldc           #4                  // String 可变类变量
        13: putfield      #5                  // Field globalVariable:Ljava/lang/String;
        16: aload_0
        17: iconst_1
        18: putfield      #6                  // Field globalVariableInt:I
        21: aload_0
        22: bipush        127
        24: putfield      #7                  // Field globalVariableInt2:I
        27: aload_0
        28: sipush        32767
        31: putfield      #8                  // Field globalVariableInt3:I
        34: aload_0
        35: ldc           #9                  // int 32768
        37: putfield      #10                 // Field globalVariableInt4:I
        40: aload_0
        41: ldc           #11                 // float 5.0f
        43: putfield      #12                 // Field globalVariableFloat:F
        46: aload_0
        47: iconst_0
        48: putfield      #13                 // Field globalVariableBoolean:Z
        51: aload_0
        52: bipush        97
        54: putfield      #14                 // Field globalVariableChar:C
        57: aload_0
        58: new           #15                 // class java/util/ArrayList
        61: dup
        62: invokespecial #16                 // Method java/util/ArrayList."<init>":()V
        65: putfield      #17                 // Field globalVariableList:Ljava/util/List;
        68: aload_0
        69: aload_1
        70: putfield      #5                  // Field globalVariable:Ljava/lang/String;
        73: aload_0
        74: getfield      #17                 // Field globalVariableList:Ljava/util/List;
        77: aload_0
        78: getfield      #6                  // Field globalVariableInt:I
        81: invokestatic  #18                 // Method java/lang/Integer.valueOf:(I)Ljava/lang/Integer;
        84: invokeinterface #19,  2           // InterfaceMethod java/util/List.add:(Ljava/lang/Object;)Z
        89: pop
        90: aload_0
        91: getfield      #17                 // Field globalVariableList:Ljava/util/List;
        94: aload_0
        95: getfield      #7                  // Field globalVariableInt2:I
        98: invokestatic  #18                 // Method java/lang/Integer.valueOf:(I)Ljava/lang/Integer;
       101: invokeinterface #19,  2           // InterfaceMethod java/util/List.add:(Ljava/lang/Object;)Z
       106: pop
       107: aload_0
       108: getfield      #17                 // Field globalVariableList:Ljava/util/List;
       111: aload_0
       112: getfield      #8                  // Field globalVariableInt3:I
       115: invokestatic  #18                 // Method java/lang/Integer.valueOf:(I)Ljava/lang/Integer;
       118: invokeinterface #19,  2           // InterfaceMethod java/util/List.add:(Ljava/lang/Object;)Z
       123: pop
       124: aload_0
       125: getfield      #17                 // Field globalVariableList:Ljava/util/List;
       128: aload_0
       129: getfield      #10                 // Field globalVariableInt4:I
       132: invokestatic  #18                 // Method java/lang/Integer.valueOf:(I)Ljava/lang/Integer;
       135: invokeinterface #19,  2           // InterfaceMethod java/util/List.add:(Ljava/lang/Object;)Z
       140: pop
       141: return
      LineNumberTable:
        line 30: 0
        line 13: 4
        line 14: 10
        line 15: 16
        line 16: 21
        line 17: 27
        line 18: 34
        line 20: 40
        line 22: 46
        line 23: 51
        line 26: 57
        line 31: 68
        line 32: 73
        line 33: 90
        line 34: 107
        line 35: 124
        line 36: 141

  public int test(int);
    descriptor: (I)I
    flags: ACC_PUBLIC
    Code:
      stack=1, locals=2, args_size=2
         0: iload_1
         1: ireturn
      LineNumberTable:
        line 39: 0

  public static void main(java.lang.String[]);
    descriptor: ([Ljava/lang/String;)V
    flags: ACC_PUBLIC, ACC_STATIC
    Code:
      stack=2, locals=2, args_size=1
         0: ldc           #20                 // String 方法体局部变量
         2: astore_1
         3: getstatic     #21                 // Field java/lang/System.out:Ljava/io/PrintStream;
         6: ldc           #22                 // String 说明符号引用与直接引用
         8: invokevirtual #23                 // Method java/io/PrintStream.println:(Ljava/lang/String;)V
        11: return
      LineNumberTable:
        line 42: 0
        line 44: 3
        line 45: 11

  static {};
    descriptor: ()V
    flags: ACC_STATIC
    Code:
      stack=1, locals=0, args_size=0
         0: ldc           #9                  // int 32768
         2: putstatic     #24                 // Field staticVariable:I
         5: return
      LineNumberTable:
        line 25: 0
}
SourceFile: "TestReference.java"
```

在字节码文件中, 会记录类的所有信息, 这里简单看下包括哪些, 不是这里要说的重点

* 版本信息: minor version, major version
* 常量池Constant pool:
	* 符号引用: 
		* Class 类或接口的符号索引 #15
		* Fieldref 字段的符号索引  #17
		* MethodRef 方法的符号索引 #16
		* InterfaceMethodref 接口中方法的符号索引(如List.add) #19
		* NameAndType 之前几个符号部分引用, 就是进一步细分, 最后都是找到UTF8字符串

	* 字面量
		* Integer/Float/Long/Double/String 对应基本类型的字面量 #2

			> 当int取值-1~5采用iconst指令，取值-128~127采用bipush指令，取值-32768~32767采用sipush指令，取值-2147483648~2147483647采用 ldc 指令。  
			> 这里有个关键, 比如Integer, 不是我定义了int globalVariableInt = 1;  
			> 这里就会生成一个Integer 1的字面量, 而是现有的机器指令不能操作的范围, 才会创建.
			> 具体机器指令 参照 [JVM 指令集整理](https://juejin.im/entry/588085221b69e60059035f0a)
		* Boolean/Char/Byte 这些值范围小于等于机器操作码可以直接操作的范围 就不再另外定义字面量了
	* UTF8编码的字符串

符号引用我们看到了那些MefthodRef(#1), Fieldref(#5), 那直接引用是什么呢, 直接引用就是之间/间接指向具体的内存地址, 因为在编译成字节码之后, 还只是一个抽象化的"类", 只有经过 __加载__ 后才存在与内存中, 解析的步骤就是把这些符号引用, 指向分配完内存的地址。变成直接引用。


拿#5来说

```
#5 = Fieldref           #25.#63        // cn/com/lasong/leetcode/
TestReference.globalVariable:Ljava/lang/String;
#25 = Class              #84            // cn/com/lasong/leetcode/TestReference
#84 = Utf8               cn/com/lasong/leetcode/TestReference
#63 = NameAndType        #30:#28        // globalVariable:Ljava/lang/String;
#28 = Utf8               Ljava/lang/String;
#30 = Utf8               globalVariable

#5是一个字段的符号引用, 假设这个字段需要被使用了, 会解析这个字段


不考虑之前class的解析, 假设这里class已经解析完了
即#25已经解析成直接引用

那在解析globalVariable时候,

我们继续分析#63 得到的是
NameAndType        #30:#28
这里还是符号引用, 我们继续找到#30和#28
#28 = Utf8               Ljava/lang/String;
#30 = Utf8               globalVariable
发现他们是Utf8, 这个在类加载时, 会被加载到字符串常量池中
那#63就可以相应的替换成
#63 = 0x0001:0x0002
#5 = class_addr.0x0001:0x0002

那在下次取globalVariable(#5 class_addr.0x0001:0x0002)就不需要要再次查询
直接返回结果即可

理解是这么理解的, 具体到虚拟机就是对应的结构的指针。
```

### 字符串常量池

|内存地址|字符串|
|---|---|
|0x0001|Ljava/lang/String;|
|0x0002|globalVariable|

	
# 类加载器

类加载器主要有两类: 一类是系统提供的, 一类是自定义类加载器。

## 系统类加载器 

* Bootstrap ClassLoader: 最顶层的类加载器, 由C++/Java实现, Java最后还是会通过JNI调用到C++,是虚拟机的一部分, 只加载核心库(\<JAVA_HOME\>/jre/lib), 出于安全考虑, Bootstrap类加载器只加载java,javax,sun开头的类。所有类的父类Object就是由Bootstrap类加载器加载的。但是获取getClassLoader时返回空。

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

```java
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
ContextLoader是一个破坏双亲委托模型的方式, 但是并不是破坏双亲委托模型就是不好的, 目前来说发展火热的模块化框架OSGi就是多个 __平级的自定义类加载器__ 来实现的。

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
* 创建一个定时任务检测字节码文件修改时间, 如果修改了, 使用新的类加载器, 创建新的class类来创建新的对象  
	
	> 注意: 这里需要传入父加载器类, 否则默认使用的是当前应用的AppClassLoader, 这样加载应用内的类时, 会先从AppClassLoader查找, 不会执行自定义类加载器的findClass方法。可以通过getParent来获取ExtClassLoader。   
	>
	> new ClassLoader() -> new Class -> new ClassInstance  
	> 一个类Class是否相同, 是由ClassLoader与类全限定名共同决定的  
	>
	> cn.com.lasong.MyClass在ClassLoaderA与ClassLoaderB的parent的路径里都不存在  
	> 只有自定义类加载器可以加载  
	>
	> ```
	> ClassLoaderA ALoader = new ClassLoaderA();
	> ClassLoaderB BLoader = new ClassLoaderB();
	> Class<?> AClz = ALoader.loadClass("cn.com.lasong.MyClass");
	> Class<?> BClz = BLoader.loadClass("cn.com.lasong.MyClass");
	> AClz == BClz ? ===> false
	> ```
* 定义另一个定时任务去执行类的方法, 在不关闭应用的情况下, 会发现执行的结果发生了变化。 

## 模块化
OSGi（开放服务网关协议，Open Service Gateway Initiative）技术是Java动态化模块化系统的一系列规范。 OSGi一方面指维护OSGi规范的OSGI官方联盟，另一方面指的是该组织维护的基于Java语言的服务（业务）规范。 简单来说，OSGi可以认为是Java平台的模块层。  

实现方式就是通过不同的自定义类加载器来实现Java动态化模块。

## 代码加密
Java代码被反编译是经常会碰到的事情, 如果是一个商业级的Java程序, 如果轻易就被别人拿到代码, 那损失是很严重的。

一种保护破解的方式就是在生成字节码文件后, 再次对字节码内容进行加密, 比如在每2个字节后插入一个字节, 然后在使用的时候, 使用提供的自定义类加载器去解密, 每2个字节去除1个字节, 重新生成一个正确的字节码数组，交给自定义类加载器加载。



# Android类加载器

* BootClassLoader  
	Android中是用Java实现的BootClassLoader, 调用VMClassLoader类的包装类, 就是虚拟器启动时调用的, 加载系统类, 跟之前介绍的虚拟机规范里定义Bootstrap ClassLoader的一样. 在android中加载/system/framework/core-libart.jar核心库。

* BaseDexClassLoader	
	* PathClassLoader(SystemClassLoader)  
	在静态类SystemClassLoader里返回的单例 类加载器, 还可以通过ClassLoader.getSystemClassLoader()获取到系统应用层级(Launcher)的类加载器。它不是系统类加载器, 只是它的路径是".", 在SDCard上一层目录。
	
	```
	static private class SystemClassLoader {
        public static ClassLoader loader = ClassLoader.createSystemClassLoader();
    }
    
    /**
     * Encapsulates the set of parallel capable loader types.
     */
    private static ClassLoader createSystemClassLoader() {
        String classPath = System.getProperty("java.class.path", ".");
        String librarySearchPath = System.getProperty("java.library.path", "");

        // String[] paths = classPath.split(":");
        // URL[] urls = new URL[paths.length];
        // for (int i = 0; i < paths.length; i++) {
        // try {
        // urls[i] = new URL("file://" + paths[i]);
        // }
        // catch (Exception ex) {
        // ex.printStackTrace();
        // }
        // }
        //
        // return new java.net.URLClassLoader(urls, null);

        // TODO Make this a java.net.URLClassLoader once we have those?
        return new PathClassLoader(classPath, librarySearchPath, BootClassLoader.getInstance());
    }
	```
	
	* PathClassLoader
		代表着当前应用的类加载器
	* DexClassLoader  
		辅助加载Dex文件的类加载器。

# Android类加载器的关系
```
// BootClassLoader 启动加载  单例 加载/system/framework/core-libart.jar
ClassLoader bootClassLoader = MainActivity.class.getClassLoader().getParent();
System.out.println(bootClassLoader);

// PathClassLoader 系统路径 单例 父类BootClassLoader dex目录. (sdcard上级目录) native path elements 目录 /vendor/lib & /system/lib
// 父类是BootClassLoader
ClassLoader systemClassLoader = ClassLoader.getSystemClassLoader();
System.out.println(systemClassLoader);

// PathClassLoader 应用路径 dex目录 /data/app/cn.com.lasong-2/base.apk
// native目录: nativeLibraryDirectories 应用本地库(发现使用的还是arm文件夹)
// native path elements系统路径加上 应用包内的 lib/armeabi-v7a 和 包文件目录下的lib/arm
// 这里对动态库的优化就是 解析应用包时, 把动态库放到手机框架下的文件夹下(如我的模拟器架构是arm), 如果找不到, 再到应用包内取找
// 父类是BootClassLoader
// 这个是插件化的根本, 使用这个类加载器加载额外的应用包内的类, 再加上处理生命周期
ClassLoader appClassLoader = MainActivity.class.getClassLoader();
System.out.println(appClassLoader);
```

|类加载器|
|---|
| BootClassLoader |	
| PathClassLoader |	

# 参考链接
  
Java中init和clinit区别完全解析   
<https://blog.csdn.net/u013309870/article/details/72975536>

Java类加载机制，你理解了吗？  
<https://baijiahao.baidu.com/s?id=1636309817155065432&wfr=spider&for=pc>

自定义类加载器   
<https://www.jianshu.com/p/6d08135c8e28>

符号引用和直接引用，解析和分派  
<https://blog.csdn.net/u010386612/article/details/80105951>   

JVM 指令集整理  
<https://juejin.im/entry/588085221b69e60059035f0a>

Java使用自定义类加载器实现热部署  
<https://www.cnblogs.com/yuanyb/p/12066388.html>

OSGi  
<https://zh.wikipedia.org/wiki/OSGi>