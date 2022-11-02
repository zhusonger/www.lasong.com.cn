---
title: 10:TCP、UDP、HTTP、HTTPS回顾
author: Zhusong
layout: post
category: Server
home_btn: true
btn_text: true
footer: true
maximize: true
date: 2020-11-10
excerpt: "10:TCP、UDP、HTTP、HTTPS回顾"
abstract: ""
---

# 起因

看到一则[新闻](https://baijiahao.baidu.com/s?id=1682852789673837639&wfr=spider&for=pc)

据Android Police报道，证书管理机构Let's Encrypt警告称，计划从2021年1月11日开始，停止对运行7.1.1牛轧糖系统之前的Android版本系统的默认交叉签名认证，2021年9月1日起完全放弃。

就去研究下证书相关的东西, 看着看着发现有一些涉及到TCP、HTTPS的东西, 就先从基础再梳理一遍。



# 概念

这些其实本质上都是一个协议,  都带着P(protocol)。就是双方约定的规则，我们按照这个规则来沟通。以下是OSI模型与TCP/IP模型的关系图。

![]({{site.assets_path}}/img/server/img-server-osi-tcpip.jpg)

## [Socket(套接字)](https://zh.wikipedia.org/wiki/%E7%B6%B2%E8%B7%AF%E6%8F%92%E5%BA%A7)

socket是一种操作系统提供的进程间通信机制。网络中也通过套接字来作为通信基础。

在操作系统中，通常会为应用程序提供一组应用程序接口（API），称为套接字接口（英语：socket API）。应用程序可以通过套接字接口，来使用网络套接字，以进行资料交换。

在套接字接口中，以IP地址及端口组成套接字地址（socket address）。远程的套接字地址，以及本地的套接字地址完成连线后，再加上使用的协议（protocol），这个五元组（five-element tuple），作为套接字对（socket pairs），之后就可以彼此交换资料。

## [TCP](https://zh.wikipedia.org/wiki/%E4%BC%A0%E8%BE%93%E6%8E%A7%E5%88%B6%E5%8D%8F%E8%AE%AE)

TCP(Transmission Control Protocol)传输控制协议，是一种面向连接的、可靠的、基于字节流的传输层通信协议。

通常是由一端（服务器端）打开一个套接字（socket）然后监听来自另一方（客户端）的连接，这就是通常所指的被动打开（passive open）。服务器端被被动打开以后，客户端就能开始创建主动打开（active open）。

之前弄自己服务器的FTP也会配置到这些参数, 被动打开模式。

服务器端执行了listen函数后，就在服务器上创建起两个队列：

SYN队列：存放完成了二次握手的结果。 队列长度由listen函数的参数backlog指定。

ACCEPT队列：存放完成了三次握手的结果。队列长度由listen函数的参数backlog指定。

* 三次握手建立连接

	![]({{site.assets_path}}/img/server/img-server-connect-tcp.png)

	在服务端收到ACK时放入SYN队列,  再次收到ACK移除SYN队列, 加到ACCEPT队列。
	
	服务端在收到ACK并发送ACK-SYN消息后,  如果一定时间没收到客户端ACK, 会按策略重发, 重发策略失败才关闭连接。

	为什么要三次握手? 避免失效的连接请求再次打开 __服务端__ 通道。服务端在接收到第一个ACK的情况就建立连接, 进入ESTABLISHED状态的话, 场景如下会出现刚才所说的问题:
	
	* 客户端发起ACK(1)
	* 网络阻塞, 迟迟没有接收到服务端的SYN
	* 客户端再次发送ACK(2)
	* 服务端接收ACK(1), 建立连接, 进入ESTABLISHED状态
	* 服务端发送SYN到客户端
	* 客户端接收到SYN,  建立连接, 进入ESTABLISHED状态
	* 双方开始通信
	* 客户端处理完成, 关闭通道
	* 服务端接收到关闭请求,关闭通道
	* 重发的ACK(2)到达服务端, 建立连接, 进入ESTABLISHED状态
	
	> 到这里, 服务端就会出现创建了一个通道, 但是无人使用的问题。
	
* 四次握手断开连接

	![]({{site.assets_path}}/img/server/img-server-disconnect-tcp.png)
		
	关闭一侧的连接需要一对 **ACK** 和 **FIN** 。
	
	为什么是 **2MSL** ?
	
	​	> 在这里,  客户端收到服务端的 **FIN** 之后, 会超时等待 __2MSL__ ，然后关闭连接。服务端收到客户端返回的ACK就关闭连接。等待 __2MSL__ 时间主要目的是怕最后一个 __ACK__ 包对方没收到，那么对方在超时后将重发第三次握手的 **FIN** 包，主动关闭端接到重发的 **FIN** 包后可以再发一个 **ACK** 应答包
	
	

## UDP



## HTTP

## HTTPS


## Android上的HTTP&HTTPS协议实现

查看了自己电脑上的sdk的实现, targetApi是28,  在URL的实现里有这么一段代码。

```java
// BEGIN Android-added: Custom built-in URLStreamHandlers for http, https.
/**
 * Returns an instance of the built-in handler for the given protocol, or null if none exists.
 */
private static URLStreamHandler createBuiltinHandler(String protocol)
        throws ClassNotFoundException, InstantiationException, IllegalAccessException {
    URLStreamHandler handler = null;
    if (protocol.equals("file")) {
        handler = new sun.net.www.protocol.file.Handler();
    } else if (protocol.equals("ftp")) {
        handler = new sun.net.www.protocol.ftp.Handler();
    } else if (protocol.equals("jar")) {
        handler = new sun.net.www.protocol.jar.Handler();
    } else if (protocol.equals("http")) {
        handler = (URLStreamHandler)Class.
                forName("com.android.okhttp.HttpHandler").newInstance();
    } else if (protocol.equals("https")) {
        handler = (URLStreamHandler)Class.
                forName("com.android.okhttp.HttpsHandler").newInstance();
    }
    return handler;
}
```

可以看到Android的http&https协议是用的okhttp的。

源码路径在这 

<https://android.googlesource.com/platform/external/okhttp/+/refs/tags/android-vts-9.0_r15/android/main/java/com/squareup/okhttp>

新闻地址

<https://baijiahao.baidu.com/s?id=1682852789673837639&wfr=spider&for=pc>





# 概念

## 对称加密

加密解密用的同一个密钥, 对称加密是最快速、最简单的一种加密方式。加解密速度取决于密钥的大小。这里有一个速度与安全的权衡, 一般小于256bit。

现在使用较多的对称加密有AES和DES。

对称加密的一个最重要的问题是密钥的拦截, 以移动端为例, 如果移动端也使用跟服务端一样的密钥, 当APP被反编译后, 如果很容易就拿到了密钥, 然后使用的常用的加密方式, 就很容易就破解了加密, 那这个加密就相当于形同虚设了。

__最重要的是, 密钥被破解后, 破解者就可以伪造数据了。__

所以要保证密钥的绝对安全。

在网络环境下, 对称加密的安全性还是存在一些不安全性。

## 非对称加密

有公钥和私钥, 公钥加密只能用私钥解密, 私钥加密只能用公钥解密。

常用的非对称加密有RSA。

私钥由创建者持有, 用于加密准备发送的数据。

公钥是创建者提供给其他人使用的密钥, 用于解密创建者发送的加密数据。

还是以移动端为例。

在服务端创建一对密钥, 服务端持有服务端私钥, 移动端持有服务端公钥, 这样移动端就能得到服务端的明文数据了。

--

那还是那个场景, 破解者还是破解成功, 可以拿到移动端所有的信息。

* 移动端接收数据 

	破解者拿到了移动端存储的服务端公钥, 那他现在可以窃取服务端发送过来的数据了。但是他 __无法篡改服务端返回的数据__ 因为他没有服务端私钥, 除非攻破服务器拿到私钥。但是他可以 __抓包查看服务端返回的数据__ 。

* 移动端发送数据

	同样, 移动端通过服务端的公钥加密后, 发送给服务端, 服务端用私钥进行解密。他还是 __无法获取发送给服务端的数据__  , 因为移动端不存在可以解密的公钥。 __可以抓包篡改__ ，但不知道移动端发给服务端的是什么内容,  __不确定返回的是什么, 篡改的内容也就不那么容易了。__
	

这两个场景攻破的难点都在服务端, 服务端的攻破难度可以APP的破解困难多了。

这里都是悲观情况下, 移动端的密钥都被破解的情况, 实际上, 再把移动端的密钥存储弄得更复杂一些, 比如把移动端的密钥放在so库, 难度就又上去了。

## MD5

MD5是一个单向的加密, 加密之后不可逆。常用于校验是否发生修改, 通过MD5来确保是原始信息。

## 对称与非对称的组合使用

由于非对称加密的复杂性, 速度相对于对称较慢, 数据量大就更明显了, 这里就可以用一种策略达到更好的隐私性与性能。

移动端每次发送数据, 流程如下:

* 移动端
	*  随机生成一个对称密钥
	*  使用对称密钥加密数据(速度较快)
	*  服务端公钥加密对称密钥(对称密钥的数据量较小, 比总数据加密要快)
* 服务端 
	*  服务端接收到数据后, 使用私钥解密得到对称密钥
	*  用对称密钥解密数据得到明文参数

# SSL签名申请

## 概念

* 数字证书认证机构（英语：Certificate Authority，缩写为CA）, 数字证书发放和管理的机构
* 根证书是CA认证中心给自己颁发的证书,是信任链的起始点。安装根证书意味着对这个CA认证中心的信任。
* 

## 生成CSR




# 文章链接
<https://blog.csdn.net/xiaofei0859/article/details/70740483>
<https://blog.csdn.net/u012438830/article/details/89045609>
<https://www.cnblogs.com/renhui/p/11122284.html>
<https://www.cnblogs.com/jfzhu/p/4020928.html>
<https://blog.csdn.net/lwwl12/article/details/80691746>
<https://www.cnblogs.com/xdyixia/p/11610102.html>

