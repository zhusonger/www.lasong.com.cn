---
title: 02:Android Zygote和SystemServer进程的启动流程
author: Zhusong
layout: post
footer: true
category: Android Framework
date: 2020-4-1
excerpt: "02:Android Zygote和SystemServer进程的启动流程"
abstract: ""
---

# 源码

<https://android.googlesource.com/>

Android通用内核代码  
<https://android.googlesource.com/kernel/common/>


Bootlin Linux系统源码查看  
<https://elixir.bootlin.com/linux/latest/source>  

# zygote

受精卵进程。所有的应用进程都是从他fork出去的。启动这个进程主要为应用的进程创建提供更快的支持。

## app_process.cpp

在init进程启动之后, 会首先读取/init.rc。在启动完servicemanager之后。就是启动我们比较关心zygote进程和system-server进程。

zygote它所在的文件路径为/system/bin/app_process。后面为该执行文件的参数。

```sh
# init.zygote32.rc
service zygote /system/bin/app_process -Xzygote /system/bin --zygote --start-system-server
    class main
    priority -20
    user root
    group root readproc reserved_disk
    socket zygote stream 660 root system
    socket usap_pool_primary stream 660 root system
    onrestart write /sys/android_power/request_state wake
    onrestart write /sys/power/state on
    onrestart restart audioserver
    onrestart restart cameraserver
    onrestart restart media
    onrestart restart netd
    onrestart restart wificond
    writepid /dev/cpuset/foreground/tasks
``` 

找到[app_process.cpp](https://android.googlesource.com/platform/frameworks/base/+/refs/tags/android-10.0.0_r32/cmds/app_process/app_main.cpp)。  

--zygote : Start in zygote mode   
以受精卵模式启动, 也就是系统启动是的应用模式   

--start-system-server : Start the system server.   
启动系统服务, 就是常说的SystemServer

--application : Start in application (stand alone, non zygote) mode.   
以应用模式启动, --zygote与--application不能同时设置。我们的应用都是--application。

--nice-name : The nice name for this process.  
就是进程的别名, 我们在不设置的情况下, 默认是包名, 可以通过这个参数修改, 比如ActivityThread启动时设置别名<pre-initialized\>。

>
如果是非zygote进程, 还会跟上main方法入口的全限定类名(the main class name), 并把所有参数传递给main方法。      
>
如果是zygote进程, 就会把所有参数传递给zygote进程的main方法。
>

最后根据是否是受精卵进程来调用不同的Java启动类。

这个runtime是继承AndroidRuntime的一个AppRuntime类。

在app_process的最后调用runtime的start方法。

```c

// app_main.cpp
int main(int argc, char* const argv[])
{
    //...
    // Everything up to '--' or first non '-' arg goes to the vm.
    //
    // The first argument after the VM args is the "parent dir", which
    // is currently unused.
    //
    // After the parent dir, we expect one or more the following internal
    // arguments :
    //
    // --zygote : Start in zygote mode
    // --start-system-server : Start the system server.
    // --application : Start in application (stand alone, non zygote) mode.
    // --nice-name : The nice name for this process.
    //
    // For non zygote starts, these arguments will be followed by
    // the main class name. All remaining arguments are passed to
    // the main method of this class.
    //
    // For zygote starts, all remaining arguments are passed to the zygote.
    // main function.
    //
    // Note that we must copy argument string values since we will rewrite the
    // entire argument block when we apply the nice name to argv0.
    //
    // As an exception to the above rule, anything in "spaced commands"
    // goes to the vm even though it has a space in it.
    // ...
    // 设置别名
    if (!niceName.isEmpty()) {
        runtime.setArgv0(niceName.string(), true /* setProcName */);
    }
    if (zygote) {
        runtime.start("com.android.internal.os.ZygoteInit", args, zygote);
    } else if (className) {
        runtime.start("com.android.internal.os.RuntimeInit", args, zygote);
    }
}
```

## runtime.start

在start方法内, 会创建一个Java虚拟机。zygote会添加额外的参数。其它跟不同应用都一样。

由于我们启动是AppRuntime的start, 所以查看它重写的onVmCreated。

如果是Zygote进程, 就什么都不做。否则会创建一个启动类。

toSlashClassName只是把\.换成/而已。并获取启动类的对象。


```c
// AndroidRuntime.cpp
void AndroidRuntime::start(const char* className, const Vector<String8>& options, bool zygote)
{
    //...
    //创建Java虚拟机实例, 就是创建一个JavaVM对象
    JniInvocation jni_invocation;
    jni_invocation.Init(NULL);
    JNIEnv* env;
    if (startVm(&mJavaVM, &env, zygote, primary_zygote) != 0) {
        return;
    }

    // 如果是Zygote, do nothing
    onVmCreated(env);

    /*
     * Register android functions.
     */
    // 注册gRegJNI所定义的JNI内置函数。比如register_com_android_internal_os_RuntimeInit。
    if (startReg(env) < 0) {
        ALOGE("Unable to register all android natives\n");
        return;
    }
    // 调用传入的Java类 并调用main方法
    char* slashClassName = toSlashClassName(className != NULL ? className : "");
    jclass startClass = env->FindClass(slashClassName);
    if (startClass == NULL) {
        ALOGE("JavaVM unable to locate class '%s'\n", slashClassName);
        /* keep going */
    } else {
        jmethodID startMeth = env->GetStaticMethodID(startClass, "main",
            "([Ljava/lang/String;)V");
        if (startMeth == NULL) {
            ALOGE("JavaVM unable to find main() in '%s'\n", className);
            /* keep going */
        } else {
            env->CallStaticVoidMethod(startClass, startMeth, strArray);

#if 0
            if (env->ExceptionCheck())
                threadExitUncaughtException(env);
#endif
        }
    }
    free(slashClassName);
}
```

## ZygoteInit.main

ZygoteHooks(https://android.googlesource.com/platform/libcore/+/master/dalvik/src/main/java/dalvik/system/ZygoteHooks.java) 调用startZygoteNoThreadCreation是一个native方法。在[runtime.h](https://android.googlesource.com/platform/art/+/master/runtime/runtime.h)内定义。SetZygoteNoThreadSection只是设置了一个flag表示不创建线程。


```java
public static void main(String argv[]) {
    ZygoteServer zygoteServer = null;

    // Mark zygote start. This ensures that thread creation will throw
    // an error.
    // 设置当前不创建线程。
    // 设置了一个flag
    ZygoteHooks.startZygoteNoThreadCreation();

    // Zygote goes into its own process group.
    // 0, 0表示用调用者的进程来设置
    try {
        Os.setpgid(0, 0);
    } catch (ErrnoException ex) {
        throw new RuntimeException("Failed to setpgid(0,0)", ex);
    }

    Runnable caller;
    try {
        // Report Zygote start time to tron unless it is a runtime restart
        if (!"1".equals(SystemProperties.get("sys.boot_completed"))) {
            MetricsLogger.histogram(null, "boot_zygote_init",
                    (int) SystemClock.elapsedRealtime());
        }

        String bootTimeTag = Process.is64Bit() ? "Zygote64Timing" : "Zygote32Timing";
        TimingsTraceLog bootTimingsTraceLog = new TimingsTraceLog(bootTimeTag,
                Trace.TRACE_TAG_DALVIK);
        bootTimingsTraceLog.traceBegin("ZygoteInit");
        RuntimeInit.preForkInit();

        boolean startSystemServer = false;
        String zygoteSocketName = "zygote";
        String abiList = null;
        boolean enableLazyPreload = false;
        for (int i = 1; i < argv.length; i++) {
            // 设置开启system-server
            if ("start-system-server".equals(argv[i])) {
                startSystemServer = true;
            } else if ("--enable-lazy-preload".equals(argv[i])) {
                enableLazyPreload = true;
            } else if (argv[i].startsWith(ABI_LIST_ARG)) {
                abiList = argv[i].substring(ABI_LIST_ARG.length());
            } else if (argv[i].startsWith(SOCKET_NAME_ARG)) {
                zygoteSocketName = argv[i].substring(SOCKET_NAME_ARG.length());
            } else {
                throw new RuntimeException("Unknown command line argument: " + argv[i]);
            }
        }

        final boolean isPrimaryZygote = zygoteSocketName.equals(Zygote.PRIMARY_SOCKET_NAME);

        if (abiList == null) {
            throw new RuntimeException("No ABI list supplied.");
        }

        // In some configurations, we avoid preloading resources and classes eagerly.
        // In such cases, we will preload things prior to our first fork.
        if (!enableLazyPreload) {
            bootTimingsTraceLog.traceBegin("ZygotePreload");
            EventLog.writeEvent(LOG_BOOT_PROGRESS_PRELOAD_START,
                    SystemClock.uptimeMillis());
            preload(bootTimingsTraceLog);
            EventLog.writeEvent(LOG_BOOT_PROGRESS_PRELOAD_END,
                    SystemClock.uptimeMillis());
            bootTimingsTraceLog.traceEnd(); // ZygotePreload
        }

        // Do an initial gc to clean up after startup
        bootTimingsTraceLog.traceBegin("PostZygoteInitGC");
        gcAndFinalize();
        bootTimingsTraceLog.traceEnd(); // PostZygoteInitGC

        bootTimingsTraceLog.traceEnd(); // ZygoteInit

        Zygote.initNativeState(isPrimaryZygote);

        ZygoteHooks.stopZygoteNoThreadCreation();

        zygoteServer = new ZygoteServer(isPrimaryZygote);

        if (startSystemServer) {
            Runnable r = forkSystemServer(abiList, zygoteSocketName, zygoteServer);

            // {@code r == null} in the parent (zygote) process, and {@code r != null} in the
            // child (system_server) process.
            if (r != null) {
                r.run();
                return;
            }
        }

        Log.i(TAG, "Accepting command socket connections");

        // The select loop returns early in the child process after a fork and
        // loops forever in the zygote.
        caller = zygoteServer.runSelectLoop(abiList);
    } catch (Throwable ex) {
        Log.e(TAG, "System zygote died with exception", ex);
        throw ex;
    } finally {
        if (zygoteServer != null) {
            zygoteServer.closeServerSocket();
        }
    }

    // We're in the child process and have exited the select loop. Proceed to execute the
    // command.
    if (caller != null) {
        caller.run();
    }
}
```

https://android.googlesource.com/platform/art/+/master/runtime/runtime.h

zygote就启动com.android.internal.os.ZygoteInit的main方法。
className(就是应用程序)就启动com.android.internal.os.RuntimeInit的main方法。