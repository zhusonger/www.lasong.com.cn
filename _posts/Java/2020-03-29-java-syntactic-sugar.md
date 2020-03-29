---
title: 05:Java语法糖
author: Zhusong
layout: post
footer: true
category: Java
date: 2020-3-29
excerpt: "05:Java语法糖"
abstract: ""
---

# 概念
语法糖是高级语言提供给程序员提高开发效率的方式, 可以理解成我们平时做的封装, 封装里面的内容其实还是基本的Java虚拟机功能。
这里我们介绍2个, 自动装箱/拆箱, 泛型。

# 自动装箱与拆箱
我们都知道, Java提供基本的数据类型, 同时, 对应的, 它有Java类型的封装类。

|基本类型|封装类|描述符|
|:---:|:---:|:---:|
|char|Character|C|
|byte|Byte|B|
|shor|Short|S|
|int|Integer|I|
|long|Long|L|
|float|Float|F|
|double|Double|D|
|boolean|Boolean|Z|
|引用类型||L全限定名;|
|数组||[数组类型, 即上面的其中一种|
|void|void|空|

## Show Me The Code

```java
Integer a = 1;
//0: iconst_1
//1: invokestatic  #14                 // Method java/lang/Integer.valueOf:(I)Ljava/lang/Integer;
//4: astore_1
// 查看字节码, 上面3句就是Integer a = 1;对应的字节码, 发现它自动调用了Integer.valueOf, 这就是自动装箱
Integer b = 2;
Integer c = 3;
Long e = 3l;
int f = a + b; // 0
System.out.println(a == b); // 1
System.out.println(c == (a + b)); // 2
System.out.println(c.equals(a + b)); // 3
System.out.println(e == (a + b)); // 4
System.out.println(e.equals(a + b)); // 5
```
在上面的代码, 我们已经看到的自动装箱, 就是如果对象类型是封装类型, 编译之后就会自动添加上这些代码。那自动拆箱在哪里呢, 自动拆箱的条件是 __运算符__ , 为什么是运算符, 很好理解, 对象跟对象是无法直接运算的, 那只能通过基本类型计算, 这个时候就会自动拆箱。包装类遇到 "==", 只有遇到运算符才会进行拆箱, 否则就是直接比较地址。

下面我们来逐行分析   
0: int f = a + b; a跟b需要进行运算, 所以对a,b拆箱,然后进行栈顶2个元素相加iadd, 由于f是基本类型, 不用进行装箱  
1: a == b;  2个Integer, 没有遇到运算符, 直接比较地址, 由于是不同对象地址, 返回false    
2: c == (a + b) 遇到了运算符, 拆箱相加, 比较运算符"==", c也拆箱, 基本类型比较, 返回true  
3: c.equals(a + b) 遇到了运算符, 拆箱相加, 调用Integer(c)的equals方法, 方法equals的参数是Object, 所以对相加结果进行自动装箱, Integer(7), 传入equals, 根据方法结果返回, 来看下方法, 如果传入的是Integer, 就调用intValue得到基本类型比较。返回true  

```java
// Integer.java
public boolean equals(Object obj) {
    if (obj instanceof Integer) {
        return value == ((Integer)obj).intValue();
    }
    return false;
}
```

4: e == (a + b), 与2相同, 唯一不同的是, e拆箱后得到long类型的3, a + b获得int, 结果再通过一个i2l指令转成long, 再进行比较, 结果相同true  
5: e.equals(a + b) 与3相同, 只是这次调用的是Long(e)的equals方法, 由于a + b得到的结果是int并自动装箱Integer, 不满足Long进行比较的条件,  返回false  

```java
// Long.java
public boolean equals(Object obj) {
    if (obj instanceof Long) {
        return value == ((Long)obj).longValue();
    }
    return false;
}
```

# 泛型与类型擦除

泛型(参数化类型)是JDK1.5新加入的特性, 在Java语言还没有加入泛型之前, 是通过 __Object是所有类型的父类__ 和 __类型强转__来实现类型泛化的。但是这样做的话, 只有 __运行时__ 的虚拟机 与 __程序员__ 才知道具体的类型。如果这样的话, 很多ClassCastException会有转移到运行期, 毕竟程序员也不能保证自己的代码完全正确。

相比于C#中实现的泛型, Java中的泛型是伪泛型, 只存在与源码期。在编译成字节码时已经被擦除了。变成了原生类型(Raw Type), 并且在对应的位置加上了强制类型转换, 其实就是之前由程序猿来保证的类型转换, 现在由编译器根据类型来强制转换，那在源码期的编译器检查的时候, 就能初步的校验, 保证类型正确。

## 泛型的类型

* 泛型类

```java
class MyGeneric<T>  {

}
```

* 泛型接口
```java
interface MyGeneric<T>  {

}
```

* 泛型方法
```java
public <T> void method(T item) {

}
```

## 泛型擦除

Java的泛型在经过前端编译器编译成字节码之后, 都变成了原始数据类型。如下所示

```java
// java
List<String> strings = new ArrayList<String>();
List<Integer> integers = new ArrayList<Integer>();
```

```java
// class
List strings = new ArrayList();
List integers = new ArrayList();
```

虽然Java在编译成字节码之后, 会把代码中的泛型擦除, 但是会在元数据中, 就是字节码加载阶段放在方法区的内容, 通过attribute的Signature属性来保存。
 
签名记录的是泛型的上限, 默认不加就是Object类, 通过extends关键字, 就可以指定泛型的上限。

```java
class MyGeneric<T extends Number>  {

}
```

## 泛型通配符
在使用泛型时, 我们可能不清楚它实际的类型, 那我怎么表示它呢, 这里就引入了通配符《?》,通配符代表的是一个实际类型, 跟Integer, String一样。

```java
class MyGeneric<T> {

  public static void main(String[] args) {
      MyGeneric<String> string = new MyGeneric<String>();
      MyGeneric<Integer> integer = new MyGeneric<Integer>();
      MyGeneric<?> all = string;
      all = integer;
  }

  private T value;
  public void set(T item) {
    value = item;
  }

  public T get() {
    return value;
  }
}
```

## 泛型上限 
当泛型需要一个范围的时候, 比如需要指定泛型的上限, 就添加extends XXX, 那就是指定了这个泛型的最高的父类, 超过它编译器就通不过。会提示 __原因: 推断类型不符合上限__, 在编译阶段就把可能出现的错误规避掉了。类型擦除默认是到java.lang.Object, 如果我们通过extends指定了上限, 就会擦除到上限, 类中只记录到类型上限。

```java
MyGeneric<? extends String> string = new MyGeneric<String>();
```
使用泛型上限可以很方便的get, 取出来的类型肯定是extends后的类型或它的子类。但是还是无法获取到具体的类型。如果需要到具体的可以通过instanceof来进行强转。但是设置的方法就失效了,  因为它只知道是extends的类及它的派生类,  但是具体类型向下有无数种可能, 我们并不清楚。所以无法set。

## 泛型下限
同上, 如果某些场景需要指定泛型的最小范围, 即它的最小类是什么, 就可以通过关键字super 与 通配符来实现。

```java
MyGeneric<? super Number> number = new MyGeneric<Number>();
```

跟上限一样, 下限也有它的问题, 它可以进行方便的set, 因为它知道我设置的类型肯定是super后类及它的父类, 向上的可能性已经确定, 最高到泛型的上限。那只要符合这个范围的类型都可以设置。但是, get的时候就不知道我具体是什么类了。我只知道是上限的子类, 以及super后的类及它的父类, 中间还是有无数种可能, 但是它的最上层的父类还是确定的, 就是泛型的上限。所以get可以取到泛型的上限。

## 上限下限
上面所说的上限下限, 其实还是一个具体的实参, 并不是形参, 是在代码中用来表示一个具体的类, 只是我现在想要的是某个范围内的类型都可以。所以通过这种方式来表达。


# 参考链接

java中的泛型和反射的一些总结  
<https://blog.csdn.net/qq_30675777/article/details/81540758?depth_1-utm_source=distribute.pc_relevant.none-task&utm_source=distribute.pc_relevant.none-task>

Java 泛型 <? super T> 中 super 怎么 理解？与 extends 有何不同？  
<https://www.zhihu.com/question/20400700>