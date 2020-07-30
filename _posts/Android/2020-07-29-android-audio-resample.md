---
title: 06:Android音频-PCM重采样
author: Zhusong
layout: post
footer: true
category: Android
date: 2020-7-29
excerpt: "06:Android音频-PCM数据重采样"
abstract: ""
---

# 需求
在做音频方面的功能时, 经常会碰到不同的采样率、声道数，所以就需要做重采样。最开始使用speexdst来实现重采样, 但好像效率不是特别高, 而且开始实现的有缺陷, 是全局的, 导致只能同时使用一个。

目前是改用ffmpeg的重采样(swresample)来实现, 并且调整成独立沙盒, 每个实例有一个唯一的handle。为了最简单且后续更新代码方便, 没有去抽取代码, 而是用ffmpeg打包的**libswresample.so**和**libavutil.so(swresample依赖库)**来做。

ffmpeg重采样可以直接实现单双声道的转换, 在测试过程发现**双声道转单声道会有损耗**, 导致还原回双声道时效果没有原音频细腻, 应该只是相同频谱复制了一份。

# 开源库

<https://github.com/zhusonger/androidz_media>

# 理论知识
PCM 即脉冲编码调制(Pulse Code Modulation)。   
采样率: 在数据角度来说就是单位时间内有多少个数值。  
从Audacity可以看出区别。 上面的是44.1khz, 下面的是8K, 可以看到点的间隔。   
![]({{site.assets_path}}/img/android/resample_rate.png)

PCM的存放方式是LRLRLR的方式。  
在FFMPEG里自己定义了一种新的便于计算的存储方式LLLLRRRR。

# [FFMPEG的编译](https://ffmpeg.org/)

* 下载FFMPEG

```
git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg
```

* 创建编译脚本

只要修改NDK_PATH为自己的NDK目录  
细节部分在脚本内的注释

[ffmpeg-4.2.1编译参数-中文](https://juejin.im/post/5e29683be51d45028e46771d)


```shell
#!/usr/bin/env bash

NDK_PATH=~/Documents/Dev/android-sdk-macosx/ndk-bundle
HOST_PLATFORM_WIN=darwin-x86_64
HOST_PLATFORM=$HOST_PLATFORM_WIN
API=29

TOOLCHAINS="$NDK_PATH/toolchains/llvm/prebuilt/$HOST_PLATFORM"
SYSROOT="$NDK_PATH/toolchains/llvm/prebuilt/$HOST_PLATFORM/sysroot"
CFLAG="-D__ANDROID_API__=$API -Os -fPIC -DANDROID "
LDFLAG="-lc -lm -ldl -llog "

PREFIX=android-build

CONFIG_LOG_PATH=${PREFIX}/log
COMMON_OPTIONS=
CONFIGURATION=

build() {
  APP_ABI=$1
  echo "======== > Start build $APP_ABI"
  case ${APP_ABI} in
  armeabi-v7a)
    ARCH="arm"
    CPU="armv7-a"
    MARCH="armv7-a"
    TARGET=armv7a-linux-androideabi
    CC="$TOOLCHAINS/bin/$TARGET$API-clang"
    CXX="$TOOLCHAINS/bin/$TARGET$API-clang++"
    LD="$TOOLCHAINS/bin/$TARGET$API-clang"
    CROSS_PREFIX="$TOOLCHAINS/bin/arm-linux-androideabi-"
    EXTRA_CFLAGS="$CFLAG -mfloat-abi=softfp -mfpu=vfp -marm -march=$MARCH "
    EXTRA_LDFLAGS="$LDFLAG"
    EXTRA_OPTIONS="--enable-neon --cpu=$CPU "
    ;;
  arm64-v8a)
    ARCH="aarch64"
    TARGET=$ARCH-linux-android
    CC="$TOOLCHAINS/bin/$TARGET$API-clang"
    CXX="$TOOLCHAINS/bin/$TARGET$API-clang++"
    LD="$TOOLCHAINS/bin/$TARGET$API-clang"
    CROSS_PREFIX="$TOOLCHAINS/bin/$TARGET-"
    EXTRA_CFLAGS="$CFLAG"
    EXTRA_LDFLAGS="$LDFLAG"
    EXTRA_OPTIONS=""
    ;;
  x86)
    ARCH="x86"
    CPU="i686"
    MARCH="i686"
    TARGET=i686-linux-android
    CC="$TOOLCHAINS/bin/$TARGET$API-clang"
    CXX="$TOOLCHAINS/bin/$TARGET$API-clang++"
    LD="$TOOLCHAINS/bin/$TARGET$API-clang"
    CROSS_PREFIX="$TOOLCHAINS/bin/$TARGET-"
    EXTRA_CFLAGS="$CFLAG -march=$MARCH -mtune=intel -mssse3 -mfpmath=sse -m32"
    EXTRA_LDFLAGS="$LDFLAG"
    EXTRA_OPTIONS="--cpu=$CPU "
    ;;
  x86_64)
    ARCH="x86_64"
    CPU="x86-64"
    MARCH="x86_64"
    TARGET=$ARCH-linux-android
    CC="$TOOLCHAINS/bin/$TARGET$API-clang"
    CXX="$TOOLCHAINS/bin/$TARGET$API-clang++"
    LD="$TOOLCHAINS/bin/$TARGET$API-clang"
    CROSS_PREFIX="$TOOLCHAINS/bin/$TARGET-"
    EXTRA_CFLAGS="$CFLAG -march=$CPU -mtune=intel -msse4.2 -mpopcnt -m64"
    EXTRA_LDFLAGS="$LDFLAG"
    EXTRA_OPTIONS="--cpu=$CPU "
    ;;
  esac

  echo "-------- > Start clean workspace"
  make clean

  echo "-------- > Start build configuration"
  CONFIGURATION="$COMMON_OPTIONS"
  CONFIGURATION="$CONFIGURATION --logfile=$CONFIG_LOG_PATH/config_$APP_ABI.log"
  CONFIGURATION="$CONFIGURATION --prefix=$PREFIX"
  CONFIGURATION="$CONFIGURATION --libdir=$PREFIX/libs/$APP_ABI"
  CONFIGURATION="$CONFIGURATION --incdir=$PREFIX/includes/$APP_ABI"
  CONFIGURATION="$CONFIGURATION --pkgconfigdir=$PREFIX/pkgconfig/$APP_ABI"
  CONFIGURATION="$CONFIGURATION --cross-prefix=$CROSS_PREFIX"
  CONFIGURATION="$CONFIGURATION --arch=$ARCH"
  CONFIGURATION="$CONFIGURATION --sysroot=$SYSROOT"
  CONFIGURATION="$CONFIGURATION --cc=$CC"
  CONFIGURATION="$CONFIGURATION --cxx=$CXX"
  CONFIGURATION="$CONFIGURATION --ld=$LD"
  CONFIGURATION="$CONFIGURATION $EXTRA_OPTIONS"

  echo "-------- > Start config makefile with $CONFIGURATION --extra-cflags=${EXTRA_CFLAGS} --extra-ldflags=${EXTRA_LDFLAGS}"
  ./configure ${CONFIGURATION} \
  --extra-cflags="$EXTRA_CFLAGS" \
  --extra-ldflags="$EXTRA_LDFLAGS"

  echo "-------- > Start make $APP_ABI with -j8"
  make -j10

  echo "-------- > Start install $APP_ABI"
  make install
  echo "++++++++ > make and install $APP_ABI complete."

}

build_all() {

  COMMON_OPTIONS="$COMMON_OPTIONS --target-os=android"
  # --disable-static 与 --enable-shared成对使用  
  # static 表示生产.a静态库 shared表示生成.so动态库  
  COMMON_OPTIONS="$COMMON_OPTIONS --disable-static"
  COMMON_OPTIONS="$COMMON_OPTIONS --enable-shared"
  # COMMON_OPTIONS="$COMMON_OPTIONS --enable-protocols"
  # COMMON_OPTIONS="$COMMON_OPTIONS --disable-protocols"
  COMMON_OPTIONS="$COMMON_OPTIONS --enable-cross-compile"
  COMMON_OPTIONS="$COMMON_OPTIONS --enable-optimizations"
  COMMON_OPTIONS="$COMMON_OPTIONS --disable-debug"
  COMMON_OPTIONS="$COMMON_OPTIONS --enable-small"
  COMMON_OPTIONS="$COMMON_OPTIONS --disable-doc"
  COMMON_OPTIONS="$COMMON_OPTIONS --disable-programs"
  COMMON_OPTIONS="$COMMON_OPTIONS --disable-ffmpeg"
  COMMON_OPTIONS="$COMMON_OPTIONS --disable-ffplay"
  COMMON_OPTIONS="$COMMON_OPTIONS --disable-ffprobe"
  COMMON_OPTIONS="$COMMON_OPTIONS --disable-symver"
  COMMON_OPTIONS="$COMMON_OPTIONS --disable-network"
  COMMON_OPTIONS="$COMMON_OPTIONS --disable-x86asm"
  COMMON_OPTIONS="$COMMON_OPTIONS --disable-asm"

  # 禁用的功能模块 默认是都开启的
  # 这里我只保留了utils和swresample
  COMMON_OPTIONS="$COMMON_OPTIONS --disable-avdevice"
  COMMON_OPTIONS="$COMMON_OPTIONS --disable-avcodec"
  COMMON_OPTIONS="$COMMON_OPTIONS --disable-avformat"
  COMMON_OPTIONS="$COMMON_OPTIONS --disable-swscale"
  COMMON_OPTIONS="$COMMON_OPTIONS --disable-avfilter"
  COMMON_OPTIONS="$COMMON_OPTIONS --enable-fast-unaligned"

  COMMON_OPTIONS="$COMMON_OPTIONS --enable-pthreads"
  # COMMON_OPTIONS="$COMMON_OPTIONS --enable-mediacodec"
  COMMON_OPTIONS="$COMMON_OPTIONS --enable-jni"
  COMMON_OPTIONS="$COMMON_OPTIONS --enable-zlib"
  COMMON_OPTIONS="$COMMON_OPTIONS --enable-pic"
  # COMMON_OPTIONS="$COMMON_OPTIONS --enable-avresample"
  # COMMON_OPTIONS="$COMMON_OPTIONS --enable-decoder=h264"
  # COMMON_OPTIONS="$COMMON_OPTIONS --enable-decoder=mpeg4"
  # COMMON_OPTIONS="$COMMON_OPTIONS --enable-decoder=mjpeg"
  # COMMON_OPTIONS="$COMMON_OPTIONS --enable-decoder=png"
  # COMMON_OPTIONS="$COMMON_OPTIONS --enable-decoder=vorbis"
  # COMMON_OPTIONS="$COMMON_OPTIONS --enable-decoder=opus"
  # COMMON_OPTIONS="$COMMON_OPTIONS --enable-decoder=flac"

  echo "COMMON_OPTIONS=$COMMON_OPTIONS"
  echo "PREFIX=$PREFIX"
  echo "CONFIG_LOG_PATH=$CONFIG_LOG_PATH"

  rm -rf ${PREFIX}
  mkdir -p ${CONFIG_LOG_PATH}

  # 这里是表示需要编译的平台
  #    build $app_abi
  build "armeabi-v7a"
  build "arm64-v8a"
  # build "x86"
  # build "x86_64"
}

echo "-------- Start --------"

build_all

echo "-------- End --------"

```

* 运行脚本

*  复制动态库(android-build/libs)到自己的AS项目中

# 封装调用swresample

* 新建项目
* 拷贝上一步生成的动态库和include头文件(armeabi-v7a/arm64-v8a都可以, 一样的)到jniLibs目录
* 定义Java类

```java
public class Resample {
    // 禁止修改, 由native赋值
    private long nativeSwrContext = 0;
    static {
        System.loadLibrary("avutil");
        System.loadLibrary("swresample");
        System.loadLibrary("resample");
    }

    /**
     * 将dst数据更新为混音后的数据
     * mix还是直接只支持默认均一化合成, 用ffmpeg加入的库比较大
     * @param dst  原音频
     * @param mix  混音音频
     */
    public static native void mix(/*DirectByteBuffer*/ByteBuffer dst, byte[] mix);

    /**
     * 重采样
     * @param src_data   解码源音频字节数据
     * @param src_len  解码源音频字节数据有效数据长度
     * @return  返回实际重采样后的长度
     */
    private native int resample(long nativeSwrContext, byte[] src_data, int src_len);
    public int resample(byte[] src_data, int src_len) {
        return resample(nativeSwrContext, src_data, src_len);
    }

    /**
     * 读取重采样后的数据
     * @param nativeSwrContext
     * @param dst_data 大于等于resample返回长度的字节数组
     * @param dst_len resample返回的字节数组长度
     * @return 返回读取的字节数组长度
     */
    private native int read(long nativeSwrContext, byte[] dst_data, int dst_len);
    public int read(byte[] dst_data, int dst_len) {
        return read(nativeSwrContext, dst_data, dst_len);
    }

    /**
     * 初始化重采样工具类
     * @param src_channel_layout 源音频声道排布 {@link cn.com.lasong.media.AVChannelLayout}
     * @param src_fmt   源音频格式 {@link cn.com.lasong.media.AVSampleFormat}
     * @param src_rate  源音频采样率
     * @param dst_channel_layout 目标音频声道排布
     * @param dst_fmt   目标音频格式
     * @param dst_rate 目标音频采样率
     * @return
     */
    private native int init(long nativeSwrContext, long src_channel_layout, int src_fmt, int src_rate,
                           long dst_channel_layout, int dst_fmt, int dst_rate);
    public int init(long src_channel_layout, int src_fmt, int src_rate,
                    long dst_channel_layout, int dst_fmt, int dst_rate) {
        return init(nativeSwrContext, src_channel_layout, src_fmt, src_rate, dst_channel_layout, dst_fmt, dst_rate);
    }
    /**
     * 销毁重采样工具类
     */
    private native void destroy(long nativeSwrContext);
    public void release() {
        destroy(nativeSwrContext);
    }
}
```

* 在main文件夹下创建cpp文件夹实现JNI调用swresample
* 在cpp文件夹下创建CMakeLists.txt

```cmake
# 有关使用CMake在Android Studio的更多信息,请阅读文档:https://d.android.com/studio/projects/add-native-code.html

# 设置CMake的最低版本构建本机所需库
cmake_minimum_required(VERSION 3.4.1)


# 二进制码剥除
set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} -s")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -s")

# 添加ffmpeg重采样库
set(JNI_LIBS_DIR ${CMAKE_SOURCE_DIR}/../jniLibs)
message ("JNI_LIBS_DIR=${JNI_LIBS_DIR}")

add_library(avutil
        SHARED
        IMPORTED )
set_target_properties(
        avutil
        PROPERTIES IMPORTED_LOCATION ${JNI_LIBS_DIR}/${ANDROID_ABI}/libavutil.so
)

add_library(swresample
        SHARED
        IMPORTED )
set_target_properties(swresample
        PROPERTIES IMPORTED_LOCATION ${JNI_LIBS_DIR}/${ANDROID_ABI}/libswresample.so )

# 引入头文件
include_directories( ${JNI_LIBS_DIR}/includes)
#include_directories(${CPP_SRC_DIR}/resample)
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

* 修改build添加CMake支持

```go
// buildTypes同级
externalNativeBuild {
        cmake {
            path "src/main/cpp/CMakeLists.txt"
        }
    }
```

* 实现Java对应的JNI方法

```c

// init方法, 初始化重采样
JNIEXPORT int JNICALL Java_cn_com_lasong_media_Resample_init
        (JNIEnv *env, jobject thiz, jlong nativeSwrContext, jlong src_channel_layout, jint src_fmt,
         jint src_rate,
         jlong dst_channel_layout, jint dst_fmt, jint dst_rate) {
         	// 1. 获取SwrContext
        SwrContext *swr_ctx = swr_alloc_set_opts(NULL, dst_channel_layout, dst_sample_fmt, dst_rate,
                                     src_channel_layout,
                                     src_sample_fmt, src_rate, 0, NULL);
	// 2. 记录参数
	
	// 3. 创建默认采样数(1024个采样)的输入输出buffer
	// 这个buffer根据需要来, 大了没关系, 小了需要重新申请
	ret = av_samples_alloc_array_and_samples(&ctx->src_buffers, &ctx->src_linesize,
                                         ctx->src_nb_channels,
                                         DEFAULT_NB_SAMPLES, ctx->src_sample_fmt, 0);
	ret = av_samples_alloc_array_and_samples(&ctx->dst_buffers, &ctx->dst_linesize,
                                         ctx->dst_nb_channels,
                                         DEFAULT_NB_SAMPLES, ctx->dst_sample_fmt, 0);

	// 4. 给Java对象设置当前处理的对象地址
	if (nativeSwrContext == 0) {
        	jclass clz = (*env)->GetObjectClass(env, thiz);
        	jfieldID fieldId = (*env)->GetFieldID(env, clz, "nativeSwrContext", "J");
        	// 初始化成功  
		(*env)->SetLongField(env, thiz, fieldId, (jlong) ctx);
    	}                                             
}


// 销毁释放资源
JNIEXPORT void JNICALL Java_cn_com_lasong_media_Resample_destroy
        (JNIEnv *env, jobject thiz, jlong nativeSwrContext) {
    if (nativeSwrContext == 0) {
        return;
    }
    // 将nativeSWContext设置为0，防止重复调用close导致崩溃
    jclass clz = (*env)->GetObjectClass(env, thiz);
    jfieldID fieldId = (*env)->GetFieldID(env, clz, "nativeSwrContext", "J");
    (*env)->SetLongField(env, thiz, fieldId, (jlong) 0);

    SwrContextExt *ctx = (SwrContextExt *) nativeSwrContext;
    swr_ext_free(&ctx);
}

// 重采样, 输入的字节数组, 以及有效音频的字节数组长度
// 长度是因为复用一个大小的字节数组对象, 可能数组中部分是有效的, 其他是无效的情况
JNIEXPORT jint JNICALL Java_cn_com_lasong_media_Resample_resample
        (JNIEnv *env, jobject thiz, jlong nativeSwrContext, jbyteArray src_data, jint src_len) {
        // 1. 计算输入pcm数据的采样数
        // int nb_samples = bytes_len / bytes_per_sample / nb_channels;
        int src_nb_samples = convert_samples(src_len, ctx->src_bytes_per_sample, ctx->src_nb_channels);
        
        // 2. 输入采样数大于当前已分配buffer的采样数, 就重新分配
        
        // 3. 计算目标采样数
        /* compute destination number of samples */
  	int dst_nb_samples = av_rescale_rnd(
            swr_get_delay(ctx->swr_ctx, ctx->src_sample_rate) +
            src_nb_samples, ctx->dst_sample_rate, ctx->src_sample_rate,
            AV_ROUND_UP);
        // 4. 目标采样数大于当前已分配buffer的采样数, 就重新分配
		  
  	// 5. 转换
  	int ret = swr_convert(ctx->swr_ctx, ctx->dst_buffers, dst_nb_samples, (const uint8_t **) ctx->src_buffers, src_nb_samples);          
		
  	// 6. 获取目标重采样后的字节长度
  	int dst_buffer_size = av_samples_get_buffer_size(&ctx->dst_linesize, ctx->dst_nb_channels,
                                                 ret, ctx->dst_sample_fmt, 1);
                                                 
	return  dst_buffer_size;                                                  
}

// 读取重采样后的数据
JNIEXPORT jint JNICALL Java_cn_com_lasong_media_Resample_read
        (JNIEnv *env, jobject thiz, jlong nativeSwrContext, jbyteArray dst_data, jint dst_len) {
    if (nativeSwrContext == 0) {
        return -1;
    }
    SwrContextExt *ctx = (SwrContextExt *) nativeSwrContext;

    jbyte *data = (*env)->GetByteArrayElements(env, dst_data, NULL);

    int ret;
    if (ctx->dst_linesize >= dst_len) {
        memcpy(data, ctx->dst_buffers[0], dst_len);
        ret = dst_len;
    } else {
        memcpy(data, ctx->dst_buffers[0], ctx->dst_linesize);
        ret = ctx->dst_linesize;
    }

    (*env)->ReleaseByteArrayElements(env, dst_data, data, 0);

    return ret;
}
```

* 执行releas任务后得到重采样的动态库**libresample.so**
* 重采样功能的开发
