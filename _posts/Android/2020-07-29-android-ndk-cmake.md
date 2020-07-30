---
title: 05:Android JNI开发-CMake的使用
author: Zhusong
layout: post
footer: true
category: Android
date: 2020-7-29
excerpt: "05:Android JNI开发-CMake的使用"
abstract: ""
---

# CMake

CMake(Cross platform Make)是一个开源的跨平台自动化建构系统，用来管理软件建置的程序，并不依赖于某特定编译器，并可支持多层目录、多个应用程序与多个库。

# NDK中的使用
在Android Studio中现在使用CMake的方式来编译C/C++代码成动态库。所以需要用到这个。主要改动的地方就2个, 一个是build.gradle配置CMake的路径。然后就是编写CMakeLists.txt内容了。

# 最简单的CMake

## build.gradle配置

```go
android {
	defaultConfig {
        minSdkVersion rootProject.ext.minSdkVersion
        targetSdkVersion rootProject.ext.targetSdkVersion
        versionCode 1
        versionName "1.0"

        testInstrumentationRunner "androidx.test.runner.AndroidJUnitRunner"
        consumerProguardFiles 'consumer-rules.pro'

	// 指定需要的CPU架构
        ndk {
            abiFilters /*'armeabi',*/ 'armeabi-v7a', 'arm64-v8a'
        }
    }
    
   externalNativeBuild {
        cmake {
        	// CMakeLists.txt文件路径
            path "src/main/cpp/CMakeLists.txt"
        }
    }
}
```

## CMakeLists.txt

### 纯源码

```shell
# 有关使用CMake在Android Studio的更多信息,请阅读文档:https://d.android.com/studio/projects/add-native-code.html

# 设置CMake的最低版本构建本机所需库
cmake_minimum_required(VERSION 3.4.1)


# 二进制码剥除
set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} -s")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -s")

# 创建并命名库，将其设置为静态的
# 或共享，并提供其源代码的相对路径。
# 你可以定义多个library库，并使用CMake来构建。
# Gradle会自动将包共享库关联到你的apk程序。

add_library( # 设置库的名称
        resample
        # 将库设置为共享库。
        SHARED
        # 为源文件提供一个相对路径。
        resample/resample.c
        resample/resample_helper.c
        )

# 搜索指定预先构建的库和存储路径变量。因为CMake包括系统库搜索路径中默认情况下,只需要指定想添加公共NDK库的名称，在CMake验证库之前存在完成构建
find_library( # 设置path变量的名称
        log-lib
        # 在CMake定位前指定的NDK库名称
        log)

# 指定库CMake应该链接到目标库中，可以链接多个库，比如定义库，构建脚本，预先构建的第三方库或者系统库
target_link_libraries( # 指定目标库
        resample
        # 目标库到日志库的链接 包含在NDK
        ${log-lib})
```

### 引用其他动态库

```shell
# 有关使用CMake在Android Studio的更多信息,请阅读文档:https://d.android.com/studio/projects/add-native-code.html

# 设置CMake的最低版本构建本机所需库
cmake_minimum_required(VERSION 3.4.1)


# 二进制码剥除
set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} -s")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -s")

# 添加ffmpeg重采样库
set(JNI_LIBS_DIR ${CMAKE_SOURCE_DIR}/../jniLibs)
message ("JNI_LIBS_DIR=${JNI_LIBS_DIR}")

# 添加导入的自定义动态库
add_library(avutil # 设置库的名称
        SHARED # 库类型为动态库
        IMPORTED )
# 设置自定义动态库的位置        
set_target_properties(
	 	# 需要设置的库名, add_library中指定的名称
        avutil 
        # 设置属性
        PROPERTIES 
        # 设置导入的动态库路径
        IMPORTED_LOCATION ${JNI_LIBS_DIR}/${ANDROID_ABI}/libavutil.so 
)

add_library(swresample
        SHARED
        IMPORTED )
set_target_properties(swresample
        PROPERTIES IMPORTED_LOCATION ${JNI_LIBS_DIR}/${ANDROID_ABI}/libswresample.so )

# 引入头文件
include_directories( ${JNI_LIBS_DIR}/includes)

# 创建并命名库，将其设置为静态的
# 或共享，并提供其源代码的相对路径。
# 你可以定义多个library库，并使用CMake来构建。
# Gradle会自动将包共享库关联到你的apk程序。

add_library( # 设置库的名称
        resample
        # 将库设置为共享库。
        SHARED
        # 为源文件提供一个相对路径。
        resample/resample.c
        resample/resample_helper.c
        )

# 搜索指定预先构建的库和存储路径变量。因为CMake包括系统库搜索路径中默认情况下,只需要指定想添加公共NDK库的名称，在CMake验证库之前存在完成构建
find_library( # 设置path变量的名称
        log-lib
        # 在CMake定位前指定的NDK库名称
        log)
# 指定库CMake应该链接到目标库中，可以链接多个库，比如定义库，构建脚本，预先构建的第三方库或者系统库
target_link_libraries( # 指定目标库
        resample
        # 目标库到日志库的链接 包含在NDK
        avutil swresample
        ${log-lib})

```

# 包体过大的问题
在我做的时候, 觉得代码没多少, 动态库有点大, 查找了下, 加入以下片段   

```shell
# 二进制码剥除
set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} -s")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -s")
```

# 参考

<https://blog.csdn.net/wanghao200906/article/details/79153172>

<https://developer.android.com/studio/projects/configure-cmake?hl=zh-cn>

<http://crash.163.com/#news/!newsId=24>

<http://huqi.tech/index.php/2018/10/28/ndk_cmake/>