---
title: 07:Android 开发Gradle插件实现三方源码修改
author: Zhusong
layout: post
footer: true
category: Android
date: 2020-8-13
excerpt: "07:Android 开发Gradle插件实现三方源码修改"
abstract: ""
---

# Android Studio创建Gradle插件项目

## 实现Gradle插件并本地发布

* 新建Library Module项目
* 删除androidTest、test、src/main/*下面的所有文件

	![]({{site.assets_path}}/img/android/plugin_0.png)
	
* 更新build.gradle脚本

	```groovy
	apply plugin: 'groovy'
	apply plugin: 'maven'
	
	dependencies {
	    //gradle sdk
	    implementation gradleApi()
	    //groovy sdk
	    implementation localGroovy()
	}
	
	repositories {
	    jcenter()
	    mavenCentral()
	    google()
	}
	```
* 在src/main目录下新建groovy&resources文件夹

	![]({{site.assets_path}}/img/android/plugin_1.png)
	
* groovy文件夹下, 新建代码包, 如cn.com.lasong
* 添加groovy类, 右键包名->New->File->GreetingPlugin.groovy

	```groovy
	package cn.com.lasong

	import org.gradle.api.Plugin
	import org.gradle.api.Project
	
	class GreetingPlugin implements Plugin<Project> {
	
	    @Override
	    void apply(Project project) {
	        project.task('Hello') {
	            doLast {
	                println "Hello from the GreetingPlugin"
	            }
	        }
	    }
	}
	```
* resources新建META-INF/gradle-plugins文件夹
* gradle-plugins下新建properties配置文件, 文件名就是插件名, 如cn.com.lasong.properties。

	```groovy
	# 插件的使用, 根据properties的名字
	apply plugin: 'cn.com.lasong'
	```
	```groovy
	# cn.com.lasong.properties
	# 指定插件类
	implementation-class=cn.com.lasong.GreetingPlugin
	```

	> __根据文件名就gradle-plugins可以猜到, 这个文件夹下可以创建多个properties文件, 指定不同插件对应的类即可。__

* 发布到本地测试插件, 修改build.gradle, 添加代码, 同步后双击当前模块的uploadArchives任务

	```groovy
	# 这个作为repo定位的包名
	group='cn.com.lasong'
	# 版本号
	version='1.0.0'
	
	uploadArchives {
	    repositories {
	        mavenDeployer {
	        	# 存放路径
	            repository(url: uri('../repo/greeting'))
	        }
	    }
	}
	```
	![](./plugin_2.png)

## 使用本地发布的插件

* 修改项目根目录, 添加插件

	![]({{site.assets_path}}/img/android/plugin_3.png)

* 在其他模块应用并执行任务

	![]({{site.assets_path}}/img/android/plugin_4.png)

* 查看Build下的日志		

	![]({{site.assets_path}}/img/android/plugin_5.png)

#  实现
	
# 参考

* 如何使用Android Studio开发Gradle插件  
<https://blog.csdn.net/sbsujjbcy/article/details/50782830>

* Android Gradle自定义插件开发  
<https://www.jianshu.com/p/da5920905380>