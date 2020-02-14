---
title: 01:Android逆向工程-Apktool重建失败
author: Zhusong
layout: post
footer: true
post_list: "category"
category: Android逆向
date: 2020-2-12
excerpt: "01:Android逆向工程-Apktool重建失败"
abstract: ""
---

## 错误

反编译后重建失败

``` 
# Step1:反编译
$ apktool d jihuang.apk 
I: Using Apktool 2.4.1 on jihuang.apk
I: Loading resource table...
I: Decoding AndroidManifest.xml with resources...
I: Loading resource table from file: /Users/zhusong/Library/apktool/framework/1.apk
I: Regular manifest package...
I: Decoding file-resources...
I: Decoding values */* XMLs...
I: Baksmaling classes.dex...
I: Copying assets and libs...
I: Copying unknown files...
I: Copying original files...

# Step2:重建APK
$ apktool b jihuang
I: Using Apktool 2.4.1
I: Checking whether sources has changed...
I: Checking whether resources has changed...
I: Building resources...
W: /Users/zhusong/Documents/Dev/tools/apktool/jihuang/AndroidManifest.xml:2: error: No resource identifier found for attribute 'compileSdkVersion' in package 'android'
W: 
W: /Users/zhusong/Documents/Dev/tools/apktool/jihuang/AndroidManifest.xml:2: error: No resource identifier found for attribute 'compileSdkVersionCodename' in package 'android'
W: 
brut.androlib.AndrolibException: brut.common.BrutException: could not exec (exit code = 1): [/var/folders/18/6x_rsxv12xsfdgj59pk_bsrc0000gn/T/brut_util_Jar_4883802058732040566.tmp, p, --forced-package-id, 127, --min-sdk-version, 21, --target-sdk-version, 26, --version-code, 60, --version-name, 1.10, --no-version-vectors, -F, /var/folders/18/6x_rsxv12xsfdgj59pk_bsrc0000gn/T/APKTOOL6867855121849667474.tmp, -e, /var/folders/18/6x_rsxv12xsfdgj59pk_bsrc0000gn/T/APKTOOL4775937882521760254.tmp, -0, arsc, -I, /Users/zhusong/Library/apktool/framework/1.apk, -S, /Users/zhusong/Documents/Dev/tools/apktool/jihuang/res, -M, /Users/zhusong/Documents/Dev/tools/apktool/jihuang/AndroidManifest.xml]
```

## 解决方法

1. 进入第一步的目录 /Users/zhusong/Library/apktool

	```
	I: Loading resource table from file: /Users/zhusong/Library/apktool/framework/1.apk
	```

2. 执行

	```shell
	apktool empty-framework-dir --force
	```
3. 回到apk包所在目录, 重新执行

	```
	$ apktool d jihuang.apk 
	I: Using Apktool 2.4.1 on jihuang.apk
	I: Loading resource table...
	I: Decoding AndroidManifest.xml with resources...
	I: Loading resource table from file: /Users/zhusong/Library/apktool/framework/1.apk
	I: Regular manifest package...
	I: Decoding file-resources...
	I: Decoding values */* XMLs...
	I: Baksmaling classes.dex...
	I: Copying assets and libs...
	I: Copying unknown files...
	I: Copying original files...
	
	# zhusong @ zhusongdeMBP in ~/Documents/Dev/tools/apktool [22:29:06] 
	$ apktool b jihuang    
	I: Using Apktool 2.4.1
	I: Checking whether sources has changed...
	I: Smaling smali folder into classes.dex...
	I: Checking whether resources has changed...
	I: Building resources...
	I: Copying libs... (/lib)
	I: Building apk file...
	I: Copying unknown files/dir...
	I: Built apk...
	```

4. 签名

	```
	# 生成签名
	keytool -genkey -alias [别名] -keyalg RSA -validity 2000 -keystore [签名文件名称]
	# 签名apk
	jarsigner -verbose -keystore [keystore路径] -signedjar [签名后文件存放路径] [未签名的文件路径] [keystore别名]

	```

## 官方解答
https://github.com/iBotPeaches/Apktool/issues/1425