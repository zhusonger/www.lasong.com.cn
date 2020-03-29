---
title: 01:Java内存模型(JMM) & JVM内存结构 & Java对象模型
author: Zhusong
layout: post
footer: true
category: Java
date: 2020-3-19
excerpt: "01:Java内存模型(JMM) & JVM内存结构 & Java对象模型"
abstract: ""
---

# 零: 概念

* Java内存模型(JMM): 跟Java的 __并发编程__ 有关
* JVM内存结构: 跟Java虚拟机 __运行时区域__ 有关
* Java对象模型: 跟Java对象在虚拟机中 __表现形式__ 有关

# 一: Java内存模型
Java虚拟机规范中试图定义一种Java内存模型(Java Memory Model, JMM)来屏蔽各种硬件和操作系统的内存访问差异, 以实现让Java程序在各种平台下都能达到一致的内存访问效果。

Java内存模式是对硬件内存模型的一种抽象, 所以有很多相似之处, 所以先了解下硬件内存模型的实现。由于CPU处于高速发展的过程, 并且Amdahl定律替换摩尔定律(简单来说就是并行化替换了串行化)来尽量压榨计算机的计算能力, 但是内存的发展较为缓慢, 导致内存的读写跟不上CPU的处理速度, 为了解决这个问题, 在CPU与内存之间引入了高速缓存的概念, 这样就解决了CPU处理与读写的问题。

但是这个还存在另外一个问题, 就是缓存与主内存的一致性, 就引入了“缓存一致性”协议。同时为了尽量利用CPU的计算能力, 处理器就对代码进行乱序执行(Out-Of-Order Execution)优化, 把没有依赖关系的代码进行重组,  但是保证最终的结果与顺序执行的结果在 __单线程情况下__ 一致。

## 硬件内存模型

![1]({{site.assets_path}}/img/java/java_cpu_cache_device.png){:width="60%"}

## Java内存模型

![2]({{site.assets_path}}/img/java/java_jmm.png){:width="60%"}

## 对比
虽然两者看着差不多, 但是Java内存模式对应的工作内存与主内存并没有指明硬件对应的内存位置, 两者没有关系, 只要硬件实现符合Java内存模型的规范即可。

## 重排序
在执行程序时, __为了提高性能，编译器和处理器常常会对指令进行重排序。__ 一般重排序可以分为如下三种：(1)属于编译器重排序，而(2)和(3)统称为处理器重排序。  

这些重排序会导致线程安全的问题，一个很经典的例子就是DCL问题。JMM的编译器重排序规则会禁止一些特定类型的编译器重排序；针对处理器重排序，编译器在生成指令序列的时候会通过插入 __内存屏障指令__ 来禁止某些特殊的处理器重排序。

（1）编译器优化的重排序。编译器在不改变单线程程序语义的前提下，可以重新安排语句的执行顺序；  
（2）指令级并行的重排序。现代处理器采用了指令级并行技术来将多条指令重叠执行。如果不存在数据依赖性，处理器可以改变语句对应机器指令的执行顺序；  
（3）内存系统的重排序。由于处理器使用缓存和读/写缓冲区，这使得加载和存储操作看上去可能是在乱序执行的。  

## 内存间的原子操作

* lock 作用与主内存中的变量,把一个变量标志为 __线程独占__ 的(monitorenter)
* unlock 作用与主内存中的变量,把一个变量从锁定中 __释放__ 出来(monitorexit)
* read 作用与主内存中的变量, 把主内存中的变量的 __值__ 读取到工作内存中, 用于之后的load更新到工作内存的 __副本变量__ 中
* load 作用与工作内存的变量, 把read读取的主内存的变量的 __值__ 加载到工作内存的 __副本变量__ 中
* store 作用与工作内存的变量, 把工作内存的副本变量的 __值__ 保存到主内存中, 用于之后更新主内存的 __变量__ 中
* write 作用与主内存中的变量, 把store操作从工作内存中得到的 __值__ 更新到主内存的 __变量__ 中
* use 作用与工作内存中的变量, 把工作内存中的变量的 __值__ 传递给 __执行引擎__, 当虚拟机遇到一个需要使用变量的 __值__ 的字节码指令时将会执行这个操作
* assign 作用与工作内存中的变量, 它把一个从 __执行引擎__ 收到的 __值__ 赋给工作内存的 __变量__, 每当虚拟机遇到一个给 __变量赋值__ 的字节码指令时将会执行这个操作


## 先行发生原则

用来确定一个访问在并发情况下是否安全。

1）如果一个操作happens-before另一个操作，那么第一个操作的执行结果将对第二个操作可见，而且第一个操作的执行顺序排在第二个操作之前。

2）两个操作之间存在happens-before关系，并不意味着Java平台的具体实现必须要按照happens-before关系指定的顺序来执行。如果重排序之后的执行结果，与按happens-before关系来执行的结果一致，那么这种重排序并不非法（也就是说，JMM允许这种重排序）。

### 具体规则
* 程序次序规则: 在单线程内, 书写在前面的操作会先行发生于后面的操作
* 监视器锁定规则: 一个解锁unlock操作一定发生与一个锁定lock操作

	> 监视器monitorenter对应lock monitorexit对应unlock
	> 到Java代码层级就是synchronized
* volatile规则: 对一个volatile的写操作一定发生与之后发生的读操作(保证了可见性, 读取肯定是最新值)
* 传递性: A操作先行发生于B, B操作先行发生于C, 那A操作一定先行发生于C
* 线程中断规则: 调用interrupt()先行发生于对线程中断的检测isInterrupted()。  
	
	> 由于interrupt方法调用更新了一个volatile修饰的Interruptible对象, 用于更新中断标志位。
	
* 线程启动规则: start方法先行发生于该线程内的所有动作。
* 线程终止规则: 在线程A中, 线程B在调用join方法后, 线程A会等到线程B执行结束, 才会继续执行, 即线程B先行发生于线程B在调用join之后的操作。
	
	> join无参方法就是检测isAlive方法, 如果存活就wait(0)一直等待, 直到线程结束 __自动__ 调用notifyAll释放当前线程对象的锁(因为join方法是synchronized修饰的方法, 所以它的锁就是线程对象)
	
* 对象终结规则: 一个对象的初始化(\<init\>)完成, 先行发生于它的finalize方法。


## 内存屏障

按照内存屏障所起的作用来划分，将内存屏障划分为以下几种。

按照可见性保障来划分。内存屏障可分为 __加载屏障（Load Barrier）__ 和 __存储屏障（Store Barrier）__ 。

* 加载屏障的作用是 __刷新处理器缓存(就是读取主内存中变量的值 更新 到工作内存的副本变量的值)__ ，存储屏障的作用 __冲刷处理器缓存(就是把工作内存的副本变量的值 更新到 主内存中变量的值)__ 。

* Java虚拟机会在 __monitorexit(释放锁)__  对应的机器码指令之后插入一个 __存储屏障(store&write)__ ，这就保障了写线程在释放锁之前在临界区中对共享变量所做的更新对读线程的执行处理器来说是可同步的。相应地，Java 虚拟机会在 __monitorenter(申请锁)__ 对应的机器码指令之后临界区开始之前的地方插入一个 __加载屏障(read&load)__ ，这使得读线程的执行处理器能够将写线程对相应共享变量所做的更新从其他处理器同步到该处理器的高速缓存中。因此，可见性的保障是通过写线程和读线程成对地使用存储屏障和加载屏障实现的。

## 原子性、可见性、有序性

### 原子性
由Java内存模型保证的原子性操作有8个, lock, unlock, read, load, store, write, use, assign。
可以认为基本类型的读写是具备原子性的。

> Java内存模型中定义了一条相对宽松的规则, 允许没有volatile修饰的64位数据读写分为2次32位的操作(猜测是为了32位系统考虑的)。但是它 __强烈建议__ 把它处理成具有原子性的操作, 在商用Java虚拟机都是这么做的。
> 
> 那如果就是没这么做怎么处理呢  
> 1. 使用volatile修饰  
> 2. 读写都用synchronized代码块包裹  
> 3. 使用ReentrantLock的lock, unlock包裹, try-finally

为了保证更大范围的原子性保证, Java内存模型提供的lock & unlock 来保证, 对应的字节码指定就是monitorenter & monitorexit来隐式的调用这2个原子操作, 对应到上层代码的关键字就是synchronized。

### 可见性

可见性是指当一个线程修改了共享变量的值, 其他线程能立即得到这个修改。Java内存模型是通过在变量修改后将新值同步回主内存中, 在变量读取前从主内存中更新变量值这种, 依赖主内存作为传递媒介实现可见性的。

可见性实现的基本方式是通过Java内存模型的主内存来传递变量值的。

* 当写入一个变量的值时, 从工作内存把拷贝变量的值同步回主内存中实现。
* 当读取一个变量的值时, 从主内存刷新变量值, 更新到工作内存中的拷贝变量中。

这里所有的共享变量都是这么做的。那在多线程的情况下, 这种方式就有一个问题, 什么时候去同步回主内存, 什么时候刷新拷贝变量的值。

引入了volatile关键字, 定义了一个规则, 就是对volatile修饰的变量, 当写入一个值时, 立即同步回主内存,  当读取一个值时, 立即刷新拷贝变量的值。注意是 __立即__ 。

如何保证这个立即, 是通过指令集对应的汇编代码中,  插入加载(Load)与保存(Store)内存屏障来实现的。

另外2个关键字, synchronized和final也经常会被用来保障可见性。

* final 它的可见性是由内存语义保障的, 具体在下面对关键字的说明中。final修饰的共享变量, 它的写入只能在构造器中, 不能被重排序的构造器之外, 在写完final修饰的变量之后, 会插入一个Store内存屏障来同步回主内存。这样就保证了在其他地方使用时, final修饰的共享变量一定是已经赋过值。static修饰的类变量, 如果同时声明为final, 就会在类的准备阶段就赋值。

* synchronized 它的可见性时由退出同步块前, 会添加一个unlock指令, 这个指令提供了保存内存屏障的功能。会把synchronized内执行的代码同步回主内存中。



# 二: Java对象布局

| Java对象布局||
|:---:|:---:|
| Mark Word|对象头, 用来保存这个对象的一些信息, 比如锁信息, hashCode, 分代年龄等。
| Kclass|指向这个实例对象对应的类对象的指针
|实例数据|就是对象本身
|对齐数据| 8位对齐, 不满用0补齐, 刚好8位就没有这部分|




### Mark Word

在Java对象布局中, MarkWord(对应C++结构markOop)   
末尾2bit来记录对象锁类型, 如果是可偏向锁, 往前1bit来记录是否是偏向锁(0无锁 1偏向锁)  
另外还包含哈希码(HashCode), GC分代年龄(Generational GC Age)  
这个字段是实现轻量锁和偏向锁的关键

|32/64位剩余位数, 非偏向模式会包含后面那1bit=>|1bit| 2bit|锁状态|
|:---:|:---:|:---:|:---:|
|存储内容|偏向锁|锁标志位|
|对象哈希码, 对象分代年龄|0| 01|无锁|
|偏向线程ID, 偏向时间戳, 对象分代年龄|1| 01|偏向锁|
|指向锁记录的指针|| 00|轻量级锁|
|指向重量级锁的指针|| 10|重量级锁|
|空|| 11|GC标志|

### LockRecord

OpenJDK中LockRecord对象

```c++
// A BasicObjectLock associates a specific Java object with a BasicLock.
// It is currently embedded in an interpreter frame.
class BasicObjectLock VALUE_OBJ_CLASS_SPEC {
 private:
  BasicLock _lock;                        // the lock, must be double word aligned
  oop       _obj;                         // object holds the lock;
};
class BasicLock VALUE_OBJ_CLASS_SPEC {
 private:
  volatile markOop _displaced_header;
};
```
锁记录(LockRecord) 在对象没有被锁定(锁标志位01)时创建。  
备份锁对象目前的Mark Word, 记录在\_displaced_header中, 称作Displaced Mark Word。  
更新这个锁记录的对象, 记录在\_obj中。  

# 三: Java内存结构/内存区域
准确来说, 这应该称作Java虚拟机 __运行时数据区域__ 。这是由Java虚拟机规范里定义的[Run-Time Data Areas](https://docs.oracle.com/javase/specs/jvms/se14/html/jvms-2.html#jvms-2.5)。它把虚拟机运行时的内存分为6块区域。分别为PC寄存器, Java虚拟机栈, 堆, 方法区, 运行时常量池,  本地方法栈。其中运行时常量池是方法区的一部分。

![1]({{site.assets_path}}/img/java/java_java_runtime_data_area.png){:width="60%"}

## 线程私有
* PC寄存器: 用于记录程序运行到哪一条指令了。
* Java虚拟机栈: 用于执行线程的代码, 每一个方法就是一个栈帧, 栈帧中会包含局部变量表, 操作数栈等信息, 方法的调用就是栈帧入栈出栈的过程。
* 本地方法栈: 跟Java虚拟机栈差不多, 只是它是单独负责Native的调用过程。

## 线程公有
* 堆: 所有的对象实例都分配在堆中, 不过随着技术的更迭, 出现了类似栈上分配等技术, 也不是那么绝对。毕竟JVM一直在做优化, 所以思想不要固化, 比如栈上分配就是在栈上分配对象, 这样对象会随着栈帧出栈而被销毁, 减少了GC很大的工作量。
* 方法区: 方法区可以理解成一些比较稳定的内容, 单独开辟出一个空间, 让GC可以少的光顾, 减少GC一部分性能开销。这里存放的有类信息, 常量, 静态变量, JIT编译后的本地机器码等。

# 四: 关键字
## synchronized & ReentrantLock
JDK[0, 1.6)是一个重量级锁, 出现同步问题就直接通过互斥量造成线程阻塞, 同步大师Doug Lea看不下去了, 发明了java.util.concurrent这个包下的同步代码,后面JDK与Doug Lea共同优化, 实现了我们现在的java.util.concurrent。主要是通过CAS(由处理器保证原子性)和Unsafe的方法来实现同步。park&unpark就是通过互斥量来达到阻塞的。跟重量锁方式相同。只是在调用到park之前, 会先进行重入检测、自旋等待等在后面synchronized优化中用到的技术。

在JDK[1.6, -]优化了synchronized, 通过一个锁升级的过程, 优化锁的过程。升级过程如下
无锁 => 偏向锁 => 轻量级锁 => (自旋锁) => 重量级锁


## synchronized

### 偏向锁  

加锁

* 第一次被线程获取时, 更新Mark Word的锁标志位为01, 可偏向模式
* 检测偏向锁标志位是可偏向状态(是01),
	* 如果偏向锁标志位是(0), 就更新为1, 并更新ThreadID为当前线程ID(CAS), 进入同步代码块
	* 如果偏向锁标志位是(1), 就对比当前线程跟记录的ThreadID是否相同
		* 相同线程ID, 直接进入同步代码块
		* 不同线程ID, 撤销偏向锁, 升级锁
* 检测偏向锁标志位不是可偏向状态(不是01)
	* 升级轻量锁锁定

撤销

* 如果偏向锁是当前线程
	* 如果线程不存活/不在同步代码块, 就撤销偏向锁, 偏向锁标志位(0)
	* 否则遍历线程所有的LockRecord 
		* 没有找到当前锁对象的线程, 撤销偏向锁
		* 找到了当前锁对象的线程, 根据顺序获取到最高优先级的锁highest_lock, 并取消它的偏向锁, 再把对象的Mark Word指向这个新的LockRecord, 完成锁的升级
* 如果不是当前线程, 会把撤销操作push到VM Thread, 等到全局安全点进行撤销 


适用于同一个线程反复进入同步代码块, 结束偏向锁同步代码块什么都不需要干, 只有升级的时候需要撤销。
如果很多线程来竞争锁, 偏向锁就是无用, 而且还会有性能消耗, 需要反复的加锁撤销锁, 比如使用线程池来执行任务, 如果不同的任务使用同一个对象作为锁, 那就会反复的加锁撤销, 偏向锁就没有了意义。

原理

当线程第一次获取锁时, 虚拟机会把对象头中的标志位设置为01, 即偏向模式, 同时使用CAS(Compare And Swap)操作把当前线程的ID值更新到对象同的线程ID中, 如果CAS成功, 持有偏向锁的线程, 每次进入这个锁相关的同步代码块时, 虚拟机不需要做任何工作, 效率非常高。

答疑

Q: 如果同一个线程反复获取同步代码块, 直接不加synchronized不是一样么?  
A: 如果这个线程的工作是独立的, 没有任何其他数据共享的, 确实不需要加, 但是更多时候还是需要用到一些共享的变量。那就需要同步的方式尽快同步到主内存或者每次从主内存刷新读取。

### 轻量级锁
轻量级是相对于monitor的传统锁而言的。他并不是代替重量级锁的, 只是在多线程 __交替__ 执行同步代码块, 避免重量级锁的性能消耗, 但是多个线程 __同时__ 进入临界区, 会导致轻量级锁膨胀升级成重量级锁, 所以轻量级锁只是在减轻进入重量级锁的性能消耗, 并不是替换, 可以理解成前置优化。


升级过程:  

* 在进入同步块时, 会创建一个Lock Record, 用来记录Mark Word等信息
* 当有另一个线程去尝试获取锁, 如果是偏向模式, 就撤销偏向锁, 更新为轻量锁, 进行锁升级
* 构建一个无锁的Displaced Mark Word(就是复制锁对象的Mark Word, 再把锁标志位更新成00)更新到LockRecord
* 通过CAS操作尝试将锁对象的Mark Word, 更新为指向Lock Record的指针。
	* 更新成功表示升级轻量锁成功
	* 更新失败先判断是否为重入
		* 如果为重入, 就清除这次重入的LockRecord的Displaced Mark Word, 通过LockRecord作为重入的次数
		* 不为重入, 表示多个线程 __同时__ 竞争同一把锁, 升级成重量级锁
	
### 重量级锁
重量级锁就是阻塞式，通过使用系统互斥量来实现的传统锁。
	
## final

### final域的重排序规则

* 在构造函数内对一个final域的写入，与随后把这个被构造对象的引用赋值给一个引用变量，这两个操作之间不能重排序。
* 初次读一个包含final域的对象的引用，与随后初次读这个final域，这两个操作之间不能重排序。

### 写final域的重排序规则
写final域的重排序规则禁止把final域的写重排序到构造函数之外。这个规则的实现包含下面2个方面：

* JMM禁止编译器把final域的写重排序到构造函数之外。  
编译器会在final域的写之后，构造函数return之前，插入一个StoreStore屏障。这个屏障禁止处理器把final域的写重排序到构造函数之外。写final域的重排序规则可以确保：在对象引用为任意线程可见之前，对象的final域已经被正确初始化过了，而普通域不具有这个保障。

* 读final域的重排序规则  
读final域的重排序规则是，在一个线程中，初次读对象引用与初次读该对象包含的final域，JMM禁止处理器重排序这两个操作（注意，这个规则仅仅针对处理器）。编译器会在读final域操作的前面插入一个LoadLoad屏障。初次读对象引用与初次读该对象包含的final域，这两个操作之间存在间接依赖关系。由于编译器遵守间接依赖关系，因此编译器不会重排序这两个操作。大多数处理器也会遵守间接依赖，也不会重排序这两个操作。但有少数处理器允许对存在间接依赖关系的操作做重排序（比如alpha处理器），这个规则就是专门用来针对这种处理器的。读final域的重排序规则可以确保：在读一个对象的final域之前，一定会先读包含这个final域的对象的引用。

## volatie
volatile通过内存屏障实现原子性以及可见性。
一旦一个共享变量（类的成员变量、 类的静态成员变量） 被 volatile 修饰之后， 那么就具备了两层语义：

* 保证了不同线程对这个变量进行读取时的可见性， 即一个线程修改了某个变量的值， 这新值对其他线程来说是立即可见的。 (volatile 解决了线程间共享变量的可见性问题)。
* 禁止进行指令重排序， 阻止编译器对代码的优化。

### 内存可见性

* 第一： 使用 volatile 关键字会强制将修改的值立即写入主存；
* 第二： 使用 volatile 关键字的话， 当线程 2 进行修改时， 会导致线程 1 的工作内存中缓存变量 stop 的缓存行无效（反映到硬件层的话， 就是 CPU 的 L1或者 L2 缓存中对应的缓存行无效） ；
* 第三： 由于线程 1 的工作内存中缓存变量 stop 的缓存行无效， 所以线程 1再次读取变量 stop 的值时会去主存读取。

### 禁止重排序
volatile 关键字禁止指令重排序有两层意思：

* 当程序执行到 volatile 变量的读操作或者写操作时， 在其前面的操作的更改肯定全部已经进行， 且结果已经对后面的操作可见； 在其后面的操作肯定还没有进行
* 在进行指令优化时， 不能把 volatile 变量前面的语句放在其后面执行，也不能把 volatile 变量后面的语句放到其前面执行。

为了实现 volatile 的内存语义， 加入 volatile 关键字时， 编译器在生成字节码时，
会在指令序列中插入内存屏障， 会多出一个 lock 前缀指令。 内存屏障是一组处理器指令， 解决禁止指令重排序和内存可见性的问题。 编译器和 CPU 可以在保证输出结果一样的情况下对指令重排序， 使性能得到优化。 处理器在进行重排序时是会考虑指令之间的数据依赖性。


# ReentrantLock
单独说下ReentrantLock是因为它的可中断特性。通过方法lockInterruptibly, 当其他线程对阻塞的线程执行interrupt方法, 那相对应的这个线程会被唤醒, 就会继续执行后面的代码, 后面的代码判断如果线程已经中断, 抛出InterruptedException异常。

```
/**
     * Acquires in exclusive interruptible mode.
     * @param arg the acquire argument
     */
    private void doAcquireInterruptibly(int arg)
        throws InterruptedException {
        final Node node = addWaiter(Node.EXCLUSIVE);
        boolean failed = true;
        try {
            for (;;) {
                final Node p = node.predecessor();
                if (p == head && tryAcquire(arg)) {
                    setHead(node);
                    p.next = null; // help GC
                    failed = false;
                    return;
                }
                // 如果获取锁时阻塞, 那就会执行到判断条件里的parkAndCheckInterrupt内
                // 可以看下面方法阻塞的点
              	// 当线程被调用interrupt之后, 这个线程就被唤醒了
              	// 继续执行阻塞的点后面的代码
              	// 然后抛出异常
                if (shouldParkAfterFailedAcquire(p, node) &&
                    parkAndCheckInterrupt())
                    throw new InterruptedException();
            }
        } finally {
            if (failed)
                cancelAcquire(node);
        }
    }
    
    /**
     * Convenience method to park and then check if interrupted
     *
     * @return {@code true} if interrupted
     */
    private final boolean parkAndCheckInterrupt() {
        LockSupport.park(this); // 阻塞的点
        return Thread.interrupted();
    }
```

# 参考

happen-before原则  
<https://blog.csdn.net/ma_chen_qq/article/details/82990603>

synchronized 实现原理与内存屏障   
<https://www.jianshu.com/p/39ecb11d41d7>

死磕Synchronized底层实现  
<https://www.jianshu.com/p/4758852cbff4>

Java final关键字及其内存语义  
<https://juejin.im/post/5c7281b251882562c955f155>

内存屏障  
<https://www.jianshu.com/p/2ab5e3d7e510>

深入理解volatile的内存语义  
<https://juejin.im/post/5a3b7bc6518825128654bd73>