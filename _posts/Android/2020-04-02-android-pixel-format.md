---
title: 04:Android多媒体-YUV & RGB
author: Zhusong
layout: post
footer: true
category: Android
date: 2020-04-02
excerpt: "04:Android多媒体-YUV & RGB"
abstract: ""
---

# YUV & RGB

## RGB

就是图片里经常会提到的三原色。JPEG(24bit真彩色)跟PNG的区别就是PNG有多种格式, 并且PNG多了透明通道Alpha。

## YUV

同样是一种颜色编码方式, “Y”表示灰度值，明亮程度；而“U”和“V” 表示色彩信息代表了颜色的色调Cr(V)和饱和度Cb（U）。没有UV就是黑白色。这种方式是为了兼容黑白电视机。

# YUV的格式

## 存储格式
* Packed Format

每个像素点的 Y、U、V 是连续交错存储的。把YUV分量打包到一块。比如YUYV YUYV(YUV422中的YUYV)。

* Planar Format

先连续存储Y分量, 再存储U分量, 最后存储V分量。比如YYYY UUUU VVVV(YUV444p)。


这个只是数据的存储方式上的差异。

## 常见的采样方式

由于人对UV的敏感程度小于Y, 所以为了应对各种场景采用了不同的UV分类。

* YUV444 
	* YUV444p: Y1Y2Y3Y4 U1U2U3U4 V1V2V3V4

* YUV422
	* YUV422p: Y1Y2Y3Y4 U1U2 V1V2
	* YUYV: U1Y1V1Y2 U2Y3V2Y4
	* YVYU: V1Y1U1Y2 V2Y3U2Y4

> Y1Y2共用U1V1 Y3Y4共用U2V2

* YUV420
	* YUV420p
		* YV12: YYYYYYYY VV UU
		* YU12(I420): YYYYYYYY UU VV 
	* YUV420sp
		* NV21: YYYYYYYY VU VU

			> Android中的默认模式

		* NV12: YYYYYYYY UV UV

			> IOS中的默认模式

>  Y1Y2Y3Y4共用U1V1, YUV420p 与 YUV420sp差别只是UV分量的顺序。


# RGB与YUV转换公式

## RGB to YUV

```python
Y = 0.257R+0.504G+0.098B+16  
V = 0.439R−0.368G−0.071B+128  
U = −0.148R−0.291G+0.439B+128  
```

## YUV to RGB

```python
B = 1.164(Y−16)+2.018(U−128)  
G = 1.164(Y−16)−0.813(V−128)−0.391(U−128)  
R = 1.164(Y−16)+1.596(V−128)  
```

> 注意在上面的式子中，RGB 的范围是 [0,255][0,255]，Y 的范围是 [16,235][16,235] ，UV 的范围是 [16,239][16,239]。 如果计算结果超出这个范围就截断处理。


# 参考地址

Android原始视频格式YUV，NV12,NV21,YV12，YU12(I420)  
<https://blog.csdn.net/u010126792/article/details/86593199>

一文理解 YUV  
<https://zhuanlan.zhihu.com/p/75735751>

YUV  
<https://zh.wikipedia.org/wiki/YUV>

YUV 格式与 RGB 格式的相互转换公式及C++ 代码  
<https://blog.csdn.net/liyuanbhu/article/details/68951683>