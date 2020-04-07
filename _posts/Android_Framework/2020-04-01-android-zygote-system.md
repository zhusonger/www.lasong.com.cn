---
title: 03:Android Zygote和SystemServer进程的启动流程
author: Zhusong
layout: post
footer: true
category: Android Framework
date: 2020-04-03
excerpt: "03:Android Zygote和SystemServer进程的启动流程"
abstract: ""
---

# 源码

<https://android.googlesource.com/>

Android通用内核代码  
<https://android.googlesource.com/kernel/common/>

Libcore  
<https://android.googlesource.com/platform/libcore/>

Bootlin Linux系统源码查看  
<https://elixir.bootlin.com/linux/latest/source>  


# 概述

在上一章中, 我们把Zygote进程的执行文件启动起来了。

这一章我们看看Zygote进程启动之后做了什么。

zygote进程是我们开发的应用父进程, 应用进程都是从他fork出去的。启动这个进程主要为应用的进程创建提供更快的支持。

在init进程启动之后, 会首先读取/init.rc。

然后通过ServiceParser、ActionParser等进行启动进程。

zygote进程它所在的执行文件路径为/system/bin/app_process。后面为该执行文件的参数。


# Zygote

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

这里找到执行文件的源码, 找到[app_process.cpp](https://android.googlesource.com/platform/frameworks/base/+/refs/tags/android-10.0.0_r32/cmds/app_process/app_main.cpp)。  

简单看下它的注释

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


在开始之前, 先告知几个实现。

* [core_jni_helpers.h](https://android.googlesource.com/platform/frameworks/base.git/+/master/core/jni/core_jni_helpers.h) 经常会看到的RegisterMethodsOrDie方法, 就是这个工具类提供的。

    ```c
    static inline int RegisterMethodsOrDie(JNIEnv* env, const char* className,
                                           const JNINativeMethod* gMethods, int numMethods) {
        int res = AndroidRuntime::registerNativeMethods(env, className, gMethods, numMethods);
        LOG_ALWAYS_FATAL_IF(res < 0, "Unable to register native methods.");
        return res;
    }
    ```

* [AndroidRuntime.cpp](https://android.googlesource.com/platform/frameworks/base/+/refs/tags/android-10.0.0_r32/core/jni/AndroidRuntime.cpp) 当前虚拟机的运行时状态。在开始时会把jni接口注册到当前进程中。所有默认注册的jni接口定义在gRegJNI数组中。


## runtime.start

查看[AndroidRuntime.cpp](https://android.googlesource.com/platform/frameworks/base/+/refs/tags/android-10.0.0_r32/core/jni/AndroidRuntime.cpp)的代码实现。

在start方法内, 会创建一个Java虚拟机。zygote会添加额外的参数。其它跟普通应用都一样。

由于我们启动是AppRuntime的start, 所以查看它重写的onVmCreated。

如果是Zygote进程, 就什么都不做。否则会创建一个启动类, 就是我们的Launcher类。

toSlashClassName只是把\.换成/而已。并获取启动类的对象。

这里是首次进入Java世界, 调用[ZygoteInit](https://android.googlesource.com/platform/frameworks/base/+/refs/tags/android-10.0.0_r32/core/java/com/android/internal/os/ZygoteInit.java)的main方法。

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

## ZygoteInit

从C++的世界进入Java的世界。

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
        // 默认使用zygote的socket服务, 主要是处理32位还是64位不同的应用使用不同的进程
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

        // 得到zygote的socket文件描述符
        // 得到USAP(USB Attached SCSI Protocol)的socket的文件描述符
        // 一些初始化, 比如文件挂载,ashmem共享内存初始化, 避免dlopen内存溢出
        Zygote.initNativeState(isPrimaryZygote);
        // 关闭不创建进程的标志位
        ZygoteHooks.stopZygoteNoThreadCreation();

        // 创建Java类
        // 得到USAP的socket文件描述符
        // 创建一个本地socket监听native端创建的服务socket实现进程间通信(zygote&USAP)
        zygoteServer = new ZygoteServer(isPrimaryZygote);

        // 如果需要开启系统服务, 创建系统服务进程。
        if (startSystemServer) {
            // 创建系统进程
            Runnable r = forkSystemServer(abiList, zygoteSocketName, zygoteServer);

            // {@code r == null} in the parent (zygote) process, and {@code r != null} in the
            // child (system_server) process.
            // 在子进程system-server进程执行run后结束
            // 在父进程zygote为null, 跳过
            if (r != null) {
                r.run();
                return;
            }
        }

        Log.i(TAG, "Accepting command socket connections");

        // zygote进程进入循环等待请求
        // 在子进程中会在这里返回, 并继续执行下面的代码
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
    // 在子进程, 执行runnbale
    // We're in the child process and have exited the select loop. Proceed to execute the
    // command.
    if (caller != null) {
        caller.run();
    }
}
```

到这里 zygote进程已经创建完成了。

我们再来看看SystemServer进程是怎么创建的。

# SystemServer

## forkSystemServer
在ZygoteInit的main方法会创建system-server进程。执行方法forkSystemServer创建子进程。

```java
private static Runnable forkSystemServer(String abiList, String socketName,
        ZygoteServer zygoteServer) {
    long capabilities = posixCapabilitiesAsBits(
            OsConstants.CAP_IPC_LOCK,
            OsConstants.CAP_KILL,
            OsConstants.CAP_NET_ADMIN,
            OsConstants.CAP_NET_BIND_SERVICE,
            OsConstants.CAP_NET_BROADCAST,
            OsConstants.CAP_NET_RAW,
            OsConstants.CAP_SYS_MODULE,
            OsConstants.CAP_SYS_NICE,
            OsConstants.CAP_SYS_PTRACE,
            OsConstants.CAP_SYS_TIME,
            OsConstants.CAP_SYS_TTY_CONFIG,
            OsConstants.CAP_WAKE_ALARM,
            OsConstants.CAP_BLOCK_SUSPEND
    );
    /* Containers run without some capabilities, so drop any caps that are not available. */
    StructCapUserHeader header = new StructCapUserHeader(
            OsConstants._LINUX_CAPABILITY_VERSION_3, 0);
    StructCapUserData[] data;
    try {
        data = Os.capget(header);
    } catch (ErrnoException ex) {
        throw new RuntimeException("Failed to capget()", ex);
    }
    capabilities &= ((long) data[0].effective) | (((long) data[1].effective) << 32);

    /* Hardcoded command line to start the system server */
    String args[] = {
            "--setuid=1000",
            "--setgid=1000",
            "--setgroups=1001,1002,1003,1004,1005,1006,1007,1008,1009,1010,1018,1021,1023,"
                    + "1024,1032,1065,3001,3002,3003,3006,3007,3009,3010,3011",
            "--capabilities=" + capabilities + "," + capabilities,
            "--nice-name=system_server",
            "--runtime-args",
            "--target-sdk-version=" + VMRuntime.SDK_VERSION_CUR_DEVELOPMENT,
            "com.android.server.SystemServer",
    };
    ZygoteArguments parsedArgs = null;

    int pid;

    try {
        parsedArgs = new ZygoteArguments(args);
        Zygote.applyDebuggerSystemProperty(parsedArgs);
        Zygote.applyInvokeWithSystemProperty(parsedArgs);

        /* Enable pointer tagging in the system server unconditionally. Hardware support for
         * this is present in all ARMv8 CPUs; this flag has no effect on other platforms. */
        parsedArgs.mRuntimeFlags |= Zygote.MEMORY_TAG_LEVEL_TBI;

        if (shouldProfileSystemServer()) {
            parsedArgs.mRuntimeFlags |= Zygote.PROFILE_SYSTEM_SERVER;
        }

        /* Request to fork the system server process */
        pid = Zygote.forkSystemServer(
                parsedArgs.mUid, parsedArgs.mGid,
                parsedArgs.mGids,
                parsedArgs.mRuntimeFlags,
                null,
                parsedArgs.mPermittedCapabilities,
                parsedArgs.mEffectiveCapabilities);
    } catch (IllegalArgumentException ex) {
        throw new RuntimeException(ex);
    }

    /* For child process */
    if (pid == 0) {
        if (hasSecondZygote(abiList)) {
            waitForSecondaryZygote(socketName);
        }

        zygoteServer.closeServerSocket();
        return handleSystemServerProcess(parsedArgs);
    }

    return null;
}
```

args是启动进程的参数。这里有很多数字表示这些进程加入到system-server进程组。定义在[android_filesystem_config.h](https://android.googlesource.com/platform/system/core/+/android-o-iot-preview-5/libcutils/include/private/android_filesystem_config.h)。

nice-name表示进程的显示名称, 这里是system-server, 进程以及用户组指定为1000。

在子进程中, 先关闭父进程fork过来的socket。然后处理system-server进程。

## handleSystemServerProcess

这里会设置用户的nicename。

获取SYSTEMSERVERCLASSPATH, 这个参数在解析rc时有设置过全局变量。

performSystemServerDexOpt会优化dex文件。

如果参数指定了自定义的执行方式。会优先使用。

否则通过zygoteInit进行创建。


```java
/**
 * Finish remaining work for the newly forked system server process.
 */
private static Runnable handleSystemServerProcess(ZygoteArguments parsedArgs) {
    // set umask to 0077 so new files and directories will default to owner-only permissions.
    Os.umask(S_IRWXG | S_IRWXO);

    if (parsedArgs.mNiceName != null) {
        Process.setArgV0(parsedArgs.mNiceName);
    }

    final String systemServerClasspath = Os.getenv("SYSTEMSERVERCLASSPATH");
    if (systemServerClasspath != null) {
        performSystemServerDexOpt(systemServerClasspath);
        // Capturing profiles is only supported for debug or eng builds since selinux normally
        // prevents it.
        if (shouldProfileSystemServer() && (Build.IS_USERDEBUG || Build.IS_ENG)) {
            try {
                Log.d(TAG, "Preparing system server profile");
                prepareSystemServerProfile(systemServerClasspath);
            } catch (Exception e) {
                Log.wtf(TAG, "Failed to set up system server profile", e);
            }
        }
    }

    // 使用exec来执行执行新建进程的方式
    if (parsedArgs.mInvokeWith != null) {
        String[] args = parsedArgs.mRemainingArgs;
        // If we have a non-null system server class path, we'll have to duplicate the
        // existing arguments and append the classpath to it. ART will handle the classpath
        // correctly when we exec a new process.
        if (systemServerClasspath != null) {
            String[] amendedArgs = new String[args.length + 2];
            amendedArgs[0] = "-cp";
            amendedArgs[1] = systemServerClasspath;
            System.arraycopy(args, 0, amendedArgs, 2, args.length);
            args = amendedArgs;
        }

        WrapperInit.execApplication(parsedArgs.mInvokeWith,
                parsedArgs.mNiceName, parsedArgs.mTargetSdkVersion,
                VMRuntime.getCurrentInstructionSet(), null, args);

        throw new IllegalStateException("Unexpected return from WrapperInit.execApplication");
    } else {
        ClassLoader cl = null;
        // 创建
        if (systemServerClasspath != null) {
            cl = createPathClassLoader(systemServerClasspath, parsedArgs.mTargetSdkVersion);

            Thread.currentThread().setContextClassLoader(cl);
        }
        // 使用默认流程来加载进程。
        /*
         * Pass the remaining arguments to SystemServer.
         */
        return ZygoteInit.zygoteInit(parsedArgs.mTargetSdkVersion,
                parsedArgs.mDisabledCompatChanges,
                parsedArgs.mRemainingArgs, cl);
    }

    /* should never reach here */
}
```

## zygoteInit

在这里主要调用nativeZygoteInit。找到方法定义的位置[AndroidRuntime.cpp](https://android.googlesource.com/platform/frameworks/base/+/refs/tags/android-10.0.0_r32/core/jni/AndroidRuntime.cpp)找到方法com_android_internal_os_ZygoteInit_nativeZygoteInit。它是AndroidRuntime对象, 但是实现是AppRuntime, 在init.cpp中实现它的这个方法。

可以看到它是开启了一个线程池。这是一个binder的线程池。为了方便其他服务进行跨进程通信。

```java
public static final Runnable zygoteInit(int targetSdkVersion, long[] disabledCompatChanges,
        String[] argv, ClassLoader classLoader) {
    if (RuntimeInit.DEBUG) {
        Slog.d(RuntimeInit.TAG, "RuntimeInit: Starting application from zygote");
    }

    Trace.traceBegin(Trace.TRACE_TAG_ACTIVITY_MANAGER, "ZygoteInit");
    RuntimeInit.redirectLogStreams();

    RuntimeInit.commonInit();
    ZygoteInit.nativeZygoteInit();
    return RuntimeInit.applicationInit(targetSdkVersion, disabledCompatChanges, argv,
            classLoader);
}
```

```c
// AndroidRuntime.cpp
static void com_android_internal_os_ZygoteInit_nativeZygoteInit(JNIEnv* env, jobject clazz)
{
    gCurRuntime->onZygoteInit();
}

// app_main.cpp
virtual void onZygoteInit()
{
    sp<ProcessState> proc = ProcessState::self();
    ALOGV("App process: starting thread pool.\n");
    proc->startThreadPool();
}
```

## applicationInit

在创建完binder线程池后, 继续看applicationInit方法。

这里其实没干什么, 调用了findStaticMain来找到main入口。

startClass就是最开始传入的com.android.server.SystemServer。

```java
protected static Runnable applicationInit(int targetSdkVersion, long[] disabledCompatChanges,
        String[] argv, ClassLoader classLoader) {
    // If the application calls System.exit(), terminate the process
    // immediately without running any shutdown hooks.  It is not possible to
    // shutdown an Android application gracefully.  Among other things, the
    // Android runtime shutdown hooks close the Binder driver, which can cause
    // leftover running threads to crash before the process actually exits.
    nativeSetExitWithoutCleanup(true);

    VMRuntime.getRuntime().setTargetSdkVersion(targetSdkVersion);
    VMRuntime.getRuntime().setDisabledCompatChanges(disabledCompatChanges);

    final Arguments args = new Arguments(argv);

    // The end of of the RuntimeInit event (see #zygoteInit).
    Trace.traceEnd(Trace.TRACE_TAG_ACTIVITY_MANAGER);

    // Remaining arguments are passed to the start class's static main
    return findStaticMain(args.startClass, args.startArgs, classLoader);
}
```

## findStaticMain

这是个通用的方法, 找到指定类的main方法。并创建一个封装方法与参数的类。

用于执行main方法。这里返回的类在ZygoteInit的main方法中继续被调用了run方法。

```java
protected static Runnable findStaticMain(String className, String[] argv,
            ClassLoader classLoader) {
    Class<?> cl;

    try {
        cl = Class.forName(className, true, classLoader);
    } catch (ClassNotFoundException ex) {
        throw new RuntimeException(
                "Missing class when invoking static main " + className,
                ex);
    }

    Method m;
    try {
        m = cl.getMethod("main", new Class[] { String[].class });
    } catch (NoSuchMethodException ex) {
        throw new RuntimeException(
                "Missing static main on " + className, ex);
    } catch (SecurityException ex) {
        throw new RuntimeException(
                "Problem getting static main on " + className, ex);
    }

    int modifiers = m.getModifiers();
    if (! (Modifier.isStatic(modifiers) && Modifier.isPublic(modifiers))) {
        throw new RuntimeException(
                "Main method is not public and static on " + className);
    }

    /*
     * This throw gets caught in ZygoteInit.main(), which responds
     * by invoking the exception's run() method. This arrangement
     * clears up all the stack frames that were required in setting
     * up the process.
     */
    return new MethodAndArgsCaller(m, argv);
}

static class MethodAndArgsCaller implements Runnable {
    /** method to call */
    private final Method mMethod;

    /** argument array */
    private final String[] mArgs;

    public MethodAndArgsCaller(Method method, String[] args) {
        mMethod = method;
        mArgs = args;
    }

    public void run() {
        try {
            mMethod.invoke(null, new Object[] { mArgs });
        } catch (IllegalAccessException ex) {
            throw new RuntimeException(ex);
        } catch (InvocationTargetException ex) {
            Throwable cause = ex.getCause();
            if (cause instanceof RuntimeException) {
                throw (RuntimeException) cause;
            } else if (cause instanceof Error) {
                throw (Error) cause;
            }
            throw new RuntimeException(ex);
        }
    }
}
```

## SystemServer.main

这里就是创建一个SystemServer实例, 并执行run方法。

```java
/**
 * The main entry point from zygote.
 */
public static void main(String[] args) {
    new SystemServer().run();
}
```

## SystemServer.run

在run方法中, 会创建一个本地的接口系统服务管理。用于创建于记录系统服务。

同时会开启很多系统默认开启的服务。比如AMS。

看下startBootstrapServices方法。

```java
private void run() {

    try {
        // ...
        // Initialize native services.
        System.loadLibrary("android_servers");
        // Create the system service manager.
        mSystemServiceManager = new SystemServiceManager(mSystemContext);
        mSystemServiceManager.setStartInfo(mRuntimeRestart,
                mRuntimeStartElapsedTime, mRuntimeStartUptime);
        LocalServices.addService(SystemServiceManager.class, mSystemServiceManager);
        // Prepare the thread pool for init tasks that can be parallelized
        SystemServerInitThreadPool.get();
        //...
    } finally {
        traceEnd();  // InitBeforeStartServices
    }

    // Start services.
    // 开启系统服务
    try {
        traceBeginAndSlog("StartServices");
        startBootstrapServices();
        startCoreServices();
        startOtherServices();
        SystemServerInitThreadPool.shutdown();
    } catch (Throwable ex) {
        Slog.e("System", "******************************************");
        Slog.e("System", "************ Failure starting system services", ex);
        throw ex;
    } finally {
        traceEnd();
    }

    //...

    // Loop forever.
    Looper.loop();
    throw new RuntimeException("Main thread loop unexpectedly exited");
}

```

## startBootstrapServices

以Installer为例, 就是我们安装应用时候的安装器服务。调用的是SystemServiceManager的startService方法。

这是个方法是泛型方法。指定service是SystemService的子类。

通过找到这个传入类的带参数的Context的构造方法。实例化一个服务实例。

并添加到mServices数组中。然后调用onStart方法开启任务。

```java
private void startBootstrapServices() {
    // ...

    // Wait for installd to finish starting up so that it has a chance to
    // create critical directories such as /data/user with the appropriate
    // permissions.  We need this to complete before we initialize other services.
    traceBeginAndSlog("StartInstaller");
    Installer installer = mSystemServiceManager.startService(Installer.class);
    traceEnd();
    //...
}
```

```java
// Services that should receive lifecycle events.
private final ArrayList<SystemService> mServices = new ArrayList<SystemService>();

public <T extends SystemService> T startService(Class<T> serviceClass) {
    try {
        final String name = serviceClass.getName();
        Slog.i(TAG, "Starting " + name);
        Trace.traceBegin(Trace.TRACE_TAG_SYSTEM_SERVER, "StartService " + name);

        // Create the service.
        if (!SystemService.class.isAssignableFrom(serviceClass)) {
            throw new RuntimeException("Failed to create " + name
                    + ": service must extend " + SystemService.class.getName());
        }
        final T service;
        try {
            Constructor<T> constructor = serviceClass.getConstructor(Context.class);
            service = constructor.newInstance(mContext);
        } catch (InstantiationException ex) {
            throw new RuntimeException("Failed to create service " + name
                    + ": service could not be instantiated", ex);
        } catch (IllegalAccessException ex) {
            throw new RuntimeException("Failed to create service " + name
                    + ": service must have a public constructor with a Context argument", ex);
        } catch (NoSuchMethodException ex) {
            throw new RuntimeException("Failed to create service " + name
                    + ": service must have a public constructor with a Context argument", ex);
        } catch (InvocationTargetException ex) {
            throw new RuntimeException("Failed to create service " + name
                    + ": service constructor threw an exception", ex);
        }

        startService(service);
        return service;
    } finally {
        Trace.traceEnd(Trace.TRACE_TAG_SYSTEM_SERVER);
    }
}

public void startService(@NonNull final SystemService service) {
    // Register it.
    mServices.add(service);
    // Start it.
    long time = SystemClock.elapsedRealtime();
    try {
        service.onStart();
    } catch (RuntimeException ex) {
        throw new RuntimeException("Failed to start service " + service.getClass().getName()
                + ": onStart threw an exception", ex);
    }
    warnIfTooLong(SystemClock.elapsedRealtime() - time, service, "onStart");
}
```

## onStart

在onStart方法会进行连接获取installd服务。这个服务是解析[installd.rc](https://android.googlesource.com/platform/frameworks/native/+/master/cmds/installd/installd.rc)时会开启这个服务。在class main启动时同时启动。

```java
@Override
public void onStart() {
    if (mIsolated) {
        mInstalld = null;
    } else {
        connect();
    }
}

private void connect() {
    IBinder binder = ServiceManager.getService("installd");
    if (binder != null) {
        try {
            binder.linkToDeath(new DeathRecipient() {
                @Override
                public void binderDied() {
                    Slog.w(TAG, "installd died; reconnecting");
                    connect();
                }
            }, 0);
        } catch (RemoteException e) {
            binder = null;
        }
    }

    if (binder != null) {
        mInstalld = IInstalld.Stub.asInterface(binder);
        try {
            invalidateMounts();
        } catch (InstallerException ignored) {
        }
    } else {
        Slog.w(TAG, "installd not found; trying again");
        BackgroundThread.getHandler().postDelayed(() -> {
            connect();
        }, DateUtils.SECOND_IN_MILLIS);
    }
}
```

其它的服务也类似。

到这里SystemServer进程也已经创建完成, 并完成了服务的注册。

在之前看到插件化方案是通过hook系统这个服务来实现管理的。

