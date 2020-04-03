---
title: 01:Android init进程与servicemanager进程的启动流程
author: Zhusong
layout: post
footer: true
category: Android Framework
date: 2020-04-01
excerpt: "01:Android init进程与servicemanager进程的启动流程"
abstract: ""
---
# 源码

Android源码  
<https://android.googlesource.com/>

Android通用内核代码  
<https://android.googlesource.com/kernel/common/>

Bootlin Linux系统源码查看  
<https://elixir.bootlin.com/linux/latest/source>

# 系统启动

![]({{site.assets_path}}/img/android/android-launcher.png) 

开局一张图。后面全靠脑补。

这部分是系统的启动逻辑。涉及到Linux的系统启动过程。

我们从[Android提供的通用内核](https://source.android.google.cn/setup/building-kernels?hl=vi)查看一下基本逻辑。

Kernel初始化可以分成三部分：zImage解压缩、kernel的汇编启动阶段、Kernel的C启动阶段。

内核启动引导地址由bootp.lds决定，内核启动的执行的第一条的代码在[head.S](https://android.googlesource.com/kernel/common/+/refs/tags/android-mainline-5.6/arch/arm64/kernel/head.S)文件中，主要功能是实现压缩内核的解压和跳转到内核vmlinux内核的入口。

查看head.S从入口一行行往下找, 会找到一行用来启动内核代码。

这是就是进入C代码逻辑的入口。


```sh
# 顺序执行下来之后会调用到这里, 启动内核, 进入C启动阶段。
b start_kernel
```

这个方法在[main.c](https://android.googlesource.com/kernel/common/+/refs/tags/android-mainline-5.6/init/main.c)中, 最后执行reset_init方法开始init以及kthreadd进程的创建。

```c
asmlinkage __visible void __init start_kernel(void)
{
	// 初始化很多东西
	/* Do the rest non-__init'ed, we're now alive */
	arch_call_rest_init();
}

void __init __weak arch_call_rest_init(void)
{
	rest_init();
}

noinline void __ref rest_init(void)
{
	struct task_struct *tsk;
	int pid;
	rcu_scheduler_starting();
	/*
	 * We need to spawn init first so that it obtains pid 1, however
	 * the init task will end up wanting to create kthreads, which, if
	 * we schedule it before we create kthreadd, will OOPS.
	 */
	// CLONE_FS与父进程共享文件系统, kernel_init是个函数指针, 再查看下kernel_init执行的内容	
	pid = kernel_thread(kernel_init, NULL, CLONE_FS);
	/*
	 * Pin init on the boot CPU. Task migration is not properly working
	 * until sched_init_smp() has been run. It will set the allowed
	 * CPUs for init to the non isolated CPUs.
	 */
	rcu_read_lock();
	tsk = find_task_by_pid_ns(pid, &init_pid_ns);
	set_cpus_allowed_ptr(tsk, cpumask_of(smp_processor_id()));
	rcu_read_unlock();
	numa_default_policy();
	// CLONE_FILES与父进程共享文件描述符, 这里说明kthreadd是和idle同处一个内核态
	pid = kernel_thread(kthreadd, NULL, CLONE_FS | CLONE_FILES);
	rcu_read_lock();
	kthreadd_task = find_task_by_pid_ns(pid, &init_pid_ns);
	rcu_read_unlock();
	/*
	 * Enable might_sleep() and smp_processor_id() checks.
	 * They cannot be enabled earlier because with CONFIG_PREEMPTION=y
	 * kernel_thread() would trigger might_sleep() splats. With
	 * CONFIG_PREEMPT_VOLUNTARY=y the init task might have scheduled
	 * already, but it's stuck on the kthreadd_done completion.
	 */
	system_state = SYSTEM_SCHEDULING;
	complete(&kthreadd_done);
	/*
	 * The boot idle thread must execute schedule()
	 * at least once to get things moving:
	 */
	schedule_preempt_disabled();
	/* Call into cpu_idle with preempt disabled */
	cpu_startup_entry(CPUHP_ONLINE);
}
```

到这里我可以再来看如何启动init的进程。 默认就是执行系统根目录下的/init执行文件。如果存在并正常执行。

这个进程就一直在这里运行了。直到系统退出。

到这里, 我们已经了解了系统启动的流程。

然后只要再去分析 /init执行文件是由哪些文件编写的执行文件即可。

查看他们的逻辑。

```c
static int __ref kernel_init(void *unused)
{
	int ret;
	// 这里会设置默认执行的根目录下的/init二进制文件
	kernel_init_freeable();
	// ...
	// 
	// 这里就是kernel_init_freeable设置路径为/init的执行文件
	if (ramdisk_execute_command) {
		// 运行可执行文件/init
		// 执行成功就不会继续执行了。知道/init结束。也就是整个系统关闭退出的时候。
		ret = run_init_process(ramdisk_execute_command);
		if (!ret)
			return 0;
		pr_err("Failed to execute %s (error %d)\n",
		       ramdisk_execute_command, ret);
	}
	// 下面是尝试其他有可能的init路径执行文件
	/*
	 * We try each of these until one succeeds.
	 *
	 * The Bourne shell can be used instead of init if we are
	 * trying to recover a really broken machine.
	 */
	if (execute_command) {
		ret = run_init_process(execute_command);
		if (!ret)
			return 0;
		panic("Requested init %s failed (error %d).",
		      execute_command, ret);
	}
	if (!try_to_run_init_process("/sbin/init") ||
	    !try_to_run_init_process("/etc/init") ||
	    !try_to_run_init_process("/bin/init") ||
	    !try_to_run_init_process("/bin/sh"))
		return 0;
	panic("No working init found.  Try passing init= option to kernel. "
	      "See Linux Documentation/admin-guide/init.rst for guidance.");
}

static noinline void __init kernel_init_freeable(void)
{
	/*
	 * Wait until kthreadd is all set-up.
	 */
	// init 进程的初始化需要等待kthreadd完成。
	wait_for_completion(&kthreadd_done);
	// ...
	/*
	 * check if there is an early userspace init.  If yes, let it do all
	 * the work
	 */
	// 这里就是设置默认路径下init执行文件路径
	if (!ramdisk_execute_command)
		ramdisk_execute_command = "/init";
	if (ksys_access((const char __user *)
			ramdisk_execute_command, 0) != 0) {
		ramdisk_execute_command = NULL;
		prepare_namespace();
	}
	/*
	 * Ok, we have completed the initial bootup, and
	 * we're essentially up and running. Get rid of the
	 * initmem segments and start the user-mode stuff..
	 *
	 * rootfs is available now, try loading the public keys
	 * and default modules
	 */
	integrity_load_keys();
}

static const char *argv_init[MAX_INIT_ARGS+2] = { "init", NULL, };
const char *envp_init[MAX_INIT_ENVS+2] = { "HOME=/", "TERM=linux", NULL, };
// 配置启动参数并执行可执行文件
// argv_init的参数由setup_arch方法中读取的填充。
// envp_init的参数由unknown_bootoption方法中读取的填充。
static int run_init_process(const char *init_filename)
{
	const char *const *p;
	argv_init[0] = init_filename;
	pr_info("Run %s as init process\n", init_filename);
	pr_debug("  with arguments:\n");
	for (p = argv_init; *p; p++)
		pr_debug("    %s\n", *p);
	pr_debug("  with environment:\n");
	for (p = envp_init; *p; p++)
		pr_debug("    %s\n", *p);
	return do_execve(getname_kernel(init_filename),
		(const char __user *const __user *)argv_init,
		(const char __user *const __user *)envp_init);
}

```

# init进程

在之前的过程中, 我们知道了系统启动之后调用/init来开启init进程的。我们再来看下/init的是哪些文件生成的, 做了什么工作。

找到[Android.bp](https://android.googlesource.com/platform/system/core/+/refs/heads/master/init/Android.bp), 找到如下配置

/init进程是 phony定义的。可以看到, 其实实际执行的是init_second_stage执行文件。在init_second_stage里, srcs就是main.cpp。就是这个可执行文件的入口。我们找到main.cpp的main方法入口。

```sh
phony {
    name: "init",
    required: [
        "init_second_stage",
    ],
}
cc_binary {
    name: "init_second_stage",
    recovery_available: true,
    stem: "init",
    defaults: ["init_defaults"],
    static_libs: ["libinit"],
    required: [
        "e2fsdroid",
        "init.rc",
        "mke2fs",
        "sload_f2fs",
        "make_f2fs",
        "ueventd.rc",
    ],
    srcs: ["main.cpp"],
    symlinks: ["ueventd"],
    target: {
        recovery: {
            cflags: ["-DRECOVERY"],
            exclude_shared_libs: [
                "libbinder",
                "libutils",
            ],
        },
    },
}
```

在[main.cpp](https://android.googlesource.com/platform/system/core/+/refs/heads/master/init/main.cpp)文件的入口。Android10以前是直接调用init.cpp的main方法。现在是抽离出来。

argc是参数个数, argv[0]传入的就是init。发现这里都没有匹配。执行FirstStageMain函数。

```cpp
// main.cpp
int main(int argc, char** argv) {
#if __has_feature(address_sanitizer)
    __asan_set_error_report_callback(AsanReportCallback);
#endif
    if (!strcmp(basename(argv[0]), "ueventd")) {
        return ueventd_main(argc, argv);
    }
    if (argc > 1) {
    	// 上下文初始化
        if (!strcmp(argv[1], "subcontext")) {
        	// 初始化日志系统
            android::base::InitLogging(argv, &android::base::KernelLogger);
            const BuiltinFunctionMap& function_map = GetBuiltinFunctionMap();
            return SubcontextMain(argc, argv, &function_map);
        }
        // 安全策略系统安装
        if (!strcmp(argv[1], "selinux_setup")) {
            return SetupSelinux(argv);
        }
        if (!strcmp(argv[1], "second_stage")) {
            return SecondStageMain(argc, argv);
        }
    }
    // 执行第一阶段
    return FirstStageMain(argc, argv);
}
```

FirstStageMain在[first_stage_init.cpp](https://android.googlesource.com/platform/system/core/+/master/init/first_stage_init.cpp)中定义。这里我们看到了熟悉的selinux_setup。

```cpp
// 1. first_stage_init.cpp
int FirstStageMain(int argc, char** argv) {
    //一些文件初始化
    const char* path = "/system/bin/init";
    const char* args[] = {path, "selinux_setup", nullptr};
    // ...
    execv(path, const_cast<char**>(args));
    // execv() only returns if an error happened, in which case we
    // panic and never fall through this conditional.
    PLOG(FATAL) << "execv(\"" << path << "\") failed";
    return 1;
}
```

然后继续执行SetupSelinux方法, 这个方法在[selinux.cpp](https://android.googlesource.com/platform/system/core/+/master/init/selinux.cpp)。在执行SetupSelinux内我们又看到了熟悉的一串second_stage, 进入最后一阶段的处理。

```cpp
// 2. selinux.cpp
int SetupSelinux(char** argv) {
    SetStdioToDevNull(argv);
    InitKernelLogging(argv);
    if (REBOOT_BOOTLOADER_ON_PANIC) {
        InstallRebootSignalHandlers();
    }
    boot_clock::time_point start_time = boot_clock::now();
    MountMissingSystemPartitions();
    // Set up SELinux, loading the SELinux policy.
    // 初始化SELinux, 加载SELinux策略
    SelinuxSetupKernelLogging();
    SelinuxInitialize();
    // We're in the kernel domain and want to transition to the init domain.  File systems that
    // store SELabels in their xattrs, such as ext4 do not need an explicit restorecon here,
    // but other file systems do.  In particular, this is needed for ramdisks such as the
    // recovery image for A/B devices.
    if (selinux_android_restorecon("/system/bin/init", 0) == -1) {
        PLOG(FATAL) << "restorecon failed of /system/bin/init failed";
    }
    setenv(kEnvSelinuxStartedAt, std::to_string(start_time.time_since_epoch().count()).c_str(), 1);
    // 继续执行第二阶段
    const char* path = "/system/bin/init";
    const char* args[] = {path, "second_stage", nullptr};
    execv(path, const_cast<char**>(args));
    // execv() only returns if an error happened, in which case we
    // panic and never return from this function.
    PLOG(FATAL) << "execv(\"" << path << "\") failed";
    return 1;
}
```

SecondStageMain方法是在[init.cpp](https://android.googlesource.com/platform/system/core/+/refs/tags/android-10.0.0_r32/init/init.cpp)中。但是最新的[init.cpp](https://android.googlesource.com/platform/system/core/+/refs/heads/master/init/init.cpp)跟Android10及之前不太一样。默认是从/system/etc/init/hw/init.rc加载启动配置。 

在这里我们可以看到service对应[ServiceParser](https://android.googlesource.com/platform/system/core/+/refs/tags/android-10.0.0_r32/init/service.cpp)。 on对应[ActionParser](https://android.googlesource.com/platform/system/core/+/refs/tags/android-10.0.0_r32/init/action_parser.cpp)。import对应[ImportParser](https://android.googlesource.com/platform/system/core/+/refs/tags/android-10.0.0_r32/init/import_parser.cpp)。

import其实还是通过ServiceParser & ActionParser执行的。

这里把执行的过程加入到了一个队列。

然后在while循环执行命令。

```cpp
// 3. init.cpp
int SecondStageMain(int argc, char** argv) {
    //...
    // 得到解析rc脚本的解析对象
    // 在rc配置文件会经常看到service on import就是通过这个来执行它们的内容的
    // 后面哪些就是一次执行的内容, 比如early-init就是init.rc里定义的
    LoadBootScripts(am, sm);
    // Turning this on and letting the INFO logging be discarded adds 0.2s to
    // Nexus 9 boot time, so it's disabled by default.
    if (false) DumpState();
    // Make the GSI status available before scripts start running.
    if (android::gsi::IsGsiRunning()) {
        property_set("ro.gsid.image_running", "1");
    } else {
        property_set("ro.gsid.image_running", "0");
    }
    am.QueueBuiltinAction(SetupCgroupsAction, "SetupCgroups");
    am.QueueEventTrigger("early-init");
    // Queue an action that waits for coldboot done so we know ueventd has set up all of /dev...
    am.QueueBuiltinAction(wait_for_coldboot_done_action, "wait_for_coldboot_done");
    // ... so that we can start queuing up actions that require stuff from /dev.
    am.QueueBuiltinAction(MixHwrngIntoLinuxRngAction, "MixHwrngIntoLinuxRng");
    am.QueueBuiltinAction(SetMmapRndBitsAction, "SetMmapRndBits");
    am.QueueBuiltinAction(SetKptrRestrictAction, "SetKptrRestrict");
    Keychords keychords;
    am.QueueBuiltinAction(
        [&epoll, &keychords](const BuiltinArguments& args) -> Result<Success> {
            for (const auto& svc : ServiceList::GetInstance()) {
                keychords.Register(svc->keycodes());
            }
            keychords.Start(&epoll, HandleKeychord);
            return Success();
        },
        "KeychordInit");
    am.QueueBuiltinAction(console_init_action, "console_init");
    // Trigger all the boot actions to get us started.
    am.QueueEventTrigger("init");
    // Starting the BoringSSL self test, for NIAP certification compliance.
    am.QueueBuiltinAction(StartBoringSslSelfTest, "StartBoringSslSelfTest");
    // Repeat mix_hwrng_into_linux_rng in case /dev/hw_random or /dev/random
    // wasn't ready immediately after wait_for_coldboot_done
    am.QueueBuiltinAction(MixHwrngIntoLinuxRngAction, "MixHwrngIntoLinuxRng");
    // Initialize binder before bringing up other system services
    am.QueueBuiltinAction(InitBinder, "InitBinder");
    // Don't mount filesystems or start core system services in charger mode.
    std::string bootmode = GetProperty("ro.bootmode", "");
    // charger是充电模式的状态。我们不看啦。
    if (bootmode == "charger") {
        am.QueueEventTrigger("charger");
    } else {
        am.QueueEventTrigger("late-init");
    }
    // Run all property triggers based on current state of the properties.
    am.QueueBuiltinAction(queue_property_triggers_action, "queue_property_triggers");
    while (true) {
    	// epoll系统轮询等待消息处理。
        // By default, sleep until something happens.
        auto epoll_timeout = std::optional<std::chrono::milliseconds>{};
        if (do_shutdown && !shutting_down) {
            do_shutdown = false;
            if (HandlePowerctlMessage(shutdown_command)) {
                shutting_down = true;
            }
        }
        if (!(waiting_for_prop || Service::is_exec_service_running())) {
            am.ExecuteOneCommand();
        }
        if (!(waiting_for_prop || Service::is_exec_service_running())) {
            if (!shutting_down) {
                auto next_process_action_time = HandleProcessActions();
                // If there's a process that needs restarting, wake up in time for that.
                if (next_process_action_time) {
                    epoll_timeout = std::chrono::ceil<std::chrono::milliseconds>(
                            *next_process_action_time - boot_clock::now());
                    if (*epoll_timeout < 0ms) epoll_timeout = 0ms;
                }
            }
            // If there's more work to do, wake up again immediately.
            if (am.HasMoreCommands()) epoll_timeout = 0ms;
        }
        if (auto result = epoll.Wait(epoll_timeout); !result) {
            LOG(ERROR) << result.error();
        }
    }
    return 0;
}


static void LoadBootScripts(ActionManager& action_manager, ServiceList& service_list) {
    Parser parser = CreateParser(action_manager, service_list);
    std::string bootscript = GetProperty("ro.boot.init_rc", "");
    if (bootscript.empty()) {
        parser.ParseConfig("/init.rc");
        if (!parser.ParseConfig("/system/etc/init")) {
            late_import_paths.emplace_back("/system/etc/init");
        }
        if (!parser.ParseConfig("/product/etc/init")) {
            late_import_paths.emplace_back("/product/etc/init");
        }
        if (!parser.ParseConfig("/product_services/etc/init")) {
            late_import_paths.emplace_back("/product_services/etc/init");
        }
        if (!parser.ParseConfig("/odm/etc/init")) {
            late_import_paths.emplace_back("/odm/etc/init");
        }
        if (!parser.ParseConfig("/vendor/etc/init")) {
            late_import_paths.emplace_back("/vendor/etc/init");
        }
    } else {
        parser.ParseConfig(bootscript);
    }
}

Parser CreateParser(ActionManager& action_manager, ServiceList& service_list) {
    Parser parser;
    parser.AddSectionParser("service", std::make_unique<ServiceParser>(&service_list, subcontexts));
    parser.AddSectionParser("on", std::make_unique<ActionParser>(&action_manager, subcontexts));
    parser.AddSectionParser("import", std::make_unique<ImportParser>(&parser));
    return parser;
}
```

现在我们还是先按照一直以来的根目录下的[init.rc](https://android.googlesource.com/platform/system/core/+/refs/tags/android-10.0.0_r32/rootdir/init.rc)来看。

到了这里我们基本上是把android的init进程启动完整流程走完了。

后面开始的就是解析init.rc文件开启它的任务。

# init.rc

这个文件的内容比较多, 我们按照SecondStageMain里执行的顺序取核心的一段来看。

这个一直有在调整。从以前的版本到现在会不太一样。目前是取的Android10来看的。

主要的执行过程

early-init => init => late-init

## early-init

同时会触发init.environ.rc下的全局参数配置。

```sh
# init.environ.rc
on early-init
    export ANDROID_BOOTLOGO 1
    export ANDROID_ROOT /system
    export ANDROID_ASSETS /system/app
    export ANDROID_DATA /data
    export ANDROID_STORAGE /storage
    export ANDROID_RUNTIME_ROOT /apex/com.android.runtime
    export ANDROID_TZDATA_ROOT /apex/com.android.tzdata
    export EXTERNAL_STORAGE /sdcard
    export ASEC_MOUNTPOINT /mnt/asec
    export BOOTCLASSPATH %BOOTCLASSPATH%
    export DEX2OATBOOTCLASSPATH %DEX2OATBOOTCLASSPATH%
    export SYSTEMSERVERCLASSPATH %SYSTEMSERVERCLASSPATH%
    %EXPORT_GLOBAL_ASAN_OPTIONS%
    %EXPORT_GLOBAL_GCOV_OPTIONS%
    %EXPORT_GLOBAL_HWASAN_OPTIONS%

# init.rc
on early-init
    # Disable sysrq from keyboard
    write /proc/sys/kernel/sysrq 0
    # Set the security context of /adb_keys if present.
    restorecon /adb_keys
    # Set the security context of /postinstall if present.
    restorecon /postinstall
    mkdir /acct/uid
    # memory.pressure_level used by lmkd
    chown root system /dev/memcg/memory.pressure_level
    chmod 0040 /dev/memcg/memory.pressure_level
    # app mem cgroups, used by activity manager, lmkd and zygote
    mkdir /dev/memcg/apps/ 0755 system system
    # cgroup for system_server and surfaceflinger
    mkdir /dev/memcg/system 0550 system system
    start ueventd
    # Run apexd-bootstrap so that APEXes that provide critical libraries
    # become available. Note that this is executed as exec_start to ensure that
    # the libraries are available to the processes started after this statement.
    exec_start apexd-bootstrap
```

## init

在init最后会开启三个服务管理进程。  

这个是在Android框架的Native里实现的。  

比如[servicemanager.rc](https://android.googlesource.com/platform/frameworks/native/+/refs/tags/android-10.0.0_r32/cmds/servicemanager/)定义了servicemanager并执行/system/bin/servicemanager执行文件。 这个servicemanager应该是我们用的最多的了。

```sh
# init.rc
on init
	# 启动日志服务
	# Start logd before any other services run to ensure we capture all of their logs.
    start logd
	# 基本都是文件处理以及链接的过程,
	# 这里开启servicemanager
	# Start essential services.
    start servicemanager
    start hwservicemanager
    start vndservicemanager
```

简单看下[servicemanager.c](https://android.googlesource.com/platform/frameworks/native/+/refs/tags/android-10.0.0_r32/cmds/servicemanager/service_manager.c)的实现。看着看着发现了binder的实现。意外收获。

这里有几个binder区分清楚

* [uapi/linux/android/binder.h](https://elixir.bootlin.com/linux/v5.6.2/source/include/uapi/linux/android/binder.h)   

定义模块的头文件。定义了android的binder模块的头文件。[UAPI](https://blog.csdn.net/qwaszx523/article/details/52526115)

相当于把用户态的头文件跟内核态的区分开来。方便用户态开发的用户查看接口的变化。

* [cmds/servicemanager/binder.c](https://android.googlesource.com/platform/frameworks/native/+/refs/tags/android-10.0.0_r32/cmds/servicemanager/binder.c)

系统服务管理进程, servicemanager的binder驱动的使用。

* [drivers/android/binder.c](https://elixir.bootlin.com/linux/v5.6.2/source/drivers/android/binder.c)

这个是binder驱动的实现类。

----

继续看启动的service_manager。首先是打开binder驱动。打开128kb的内存用来处理binder的请求。

设置全局的创建的binder作为全局上下文管理者

进入loop循环进行读写操作。

```c
// service_manager.c
int main(int argc, char** argv)
{
    struct binder_state *bs;
    union selinux_callback cb;
    char *driver;
    if (argc > 1) {
        driver = argv[1];
    } else {
        driver = "/dev/binder";
    }
    // 得到128kb的内存
    // 具体实现看binder_open的注释
    bs = binder_open(driver, 128*1024);
    if (!bs) {
#ifdef VENDORSERVICEMANAGER
        ALOGW("failed to open binder driver %s\n", driver);
        while (true) {
            sleep(UINT_MAX);
        }
#else
        ALOGE("failed to open binder driver %s\n", driver);
#endif
        return -1;
    }
    // 设置创建的binder_state作为上下文的管理者
    // 这个全局唯一
    if (binder_become_context_manager(bs)) {
        ALOGE("cannot become context manager (%s)\n", strerror(errno));
        return -1;
    }
    cb.func_audit = audit_callback;
    selinux_set_callback(SELINUX_CB_AUDIT, cb);
#ifdef VENDORSERVICEMANAGER
    cb.func_log = selinux_vendor_log_callback;
#else
    cb.func_log = selinux_log_callback;
#endif
    selinux_set_callback(SELINUX_CB_LOG, cb);
#ifdef VENDORSERVICEMANAGER
    sehandle = selinux_android_vendor_service_context_handle();
#else
    sehandle = selinux_android_service_context_handle();
#endif
    selinux_status_open(true);
    if (sehandle == NULL) {
        ALOGE("SELinux: Failed to acquire sehandle. Aborting.\n");
        abort();
    }
    if (getcon(&service_manager_context) != 0) {
        ALOGE("SELinux: Failed to acquire service_manager context. Aborting.\n");
        abort();
    }
    // 前面都正常, 就死循环进行读写binder
    // svcmgr_handler用来处理binder收到的消息
    binder_loop(bs, svcmgr_handler);
    return 0;
}
```

这里不再看前面的binder做了什么。直接看loop循环。 

ioctl的驱动操作是执行的binder驱动内的binder的binder_ioctl方法。

正常情况下不会退出循环。

除非binder异常。

```c

// cmds/servicemanager/binder.c
// 进入binder驱动的读写循环
void binder_loop(struct binder_state *bs, binder_handler func)
{
    int res;
    struct binder_write_read bwr;
    uint32_t readbuf[32];
    bwr.write_size = 0;
    bwr.write_consumed = 0;
    bwr.write_buffer = 0;
    readbuf[0] = BC_ENTER_LOOPER;
    // 写入binder数据, 表示自己开始进入循环
    binder_write(bs, readbuf, sizeof(uint32_t));
    for (;;) {
        bwr.read_size = sizeof(readbuf);
        bwr.read_consumed = 0;
        bwr.read_buffer = (uintptr_t) readbuf;
        // 进行binder的读写
        // 传入bwr的地址, 从用户空间拷贝bwr数据
        // 根据bwr的write_size来决定是binder_thread_write还是binder_thread_read
        // 这里很明显。read_size为32。所以肯定会调用binder_thread_read
        // 最后再拷贝回用户空间的bwr中
        res = ioctl(bs->fd, BINDER_WRITE_READ, &bwr);
        if (res < 0) {
            ALOGE("binder_loop: ioctl failed (%s)\n", strerror(errno));
            break;
        }
        // 解析更新完的数据read数据
        res = binder_parse(bs, 0, (uintptr_t) readbuf, bwr.read_consumed, func);
        if (res == 0) {
            ALOGE("binder_loop: unexpected reply?!\n");
            break;
        }
        if (res < 0) {
            ALOGE("binder_loop: io error %d %s\n", res, strerror(errno));
            break;
        }
    }
}

// 关注点在BR_TRANSACTION & BR_TRANSACTION_SEC_CTX
// servicemanager的处理基本都在这里了。
// 最后执行的func方法, func是从main方法中传入的svcmgr_handler
int binder_parse(struct binder_state *bs, struct binder_io *bio,
                 uintptr_t ptr, size_t size, binder_handler func)
{
    int r = 1;
    uintptr_t end = ptr + (uintptr_t) size;
    while (ptr < end) {
        uint32_t cmd = *(uint32_t *) ptr;
        ptr += sizeof(uint32_t);
#if TRACE
        fprintf(stderr,"%s:\n", cmd_name(cmd));
#endif
        switch(cmd) {
        case BR_NOOP:
            break;
        case BR_TRANSACTION_COMPLETE:
            break;
        case BR_INCREFS:
        case BR_ACQUIRE:
        case BR_RELEASE:
        case BR_DECREFS:
#if TRACE
            fprintf(stderr,"  %p, %p\n", (void *)ptr, (void *)(ptr + sizeof(void *)));
#endif
            ptr += sizeof(struct binder_ptr_cookie);
            break;
        case BR_TRANSACTION_SEC_CTX:
        case BR_TRANSACTION: {
            struct binder_transaction_data_secctx txn;
            if (cmd == BR_TRANSACTION_SEC_CTX) {
                if ((end - ptr) < sizeof(struct binder_transaction_data_secctx)) {
                    ALOGE("parse: txn too small (binder_transaction_data_secctx)!\n");
                    return -1;
                }
                memcpy(&txn, (void*) ptr, sizeof(struct binder_transaction_data_secctx));
                ptr += sizeof(struct binder_transaction_data_secctx);
            } else /* BR_TRANSACTION */ {
                if ((end - ptr) < sizeof(struct binder_transaction_data)) {
                    ALOGE("parse: txn too small (binder_transaction_data)!\n");
                    return -1;
                }
                memcpy(&txn.transaction_data, (void*) ptr, sizeof(struct binder_transaction_data));
                ptr += sizeof(struct binder_transaction_data);
                txn.secctx = 0;
            }
            binder_dump_txn(&txn.transaction_data);
            if (func) {
                unsigned rdata[256/4];
                struct binder_io msg;
                struct binder_io reply;
                int res;
                bio_init(&reply, rdata, sizeof(rdata), 4);
                bio_init_from_txn(&msg, &txn.transaction_data);
                res = func(bs, &txn, &msg, &reply);
                if (txn.transaction_data.flags & TF_ONE_WAY) {
                    binder_free_buffer(bs, txn.transaction_data.data.ptr.buffer);
                } else {
                    binder_send_reply(bs, &reply, txn.transaction_data.data.ptr.buffer, res);
                }
            }
            break;
        }
        case BR_REPLY: {
            struct binder_transaction_data *txn = (struct binder_transaction_data *) ptr;
            if ((end - ptr) < sizeof(*txn)) {
                ALOGE("parse: reply too small!\n");
                return -1;
            }
            binder_dump_txn(txn);
            if (bio) {
                bio_init_from_txn(bio, txn);
                bio = 0;
            } else {
                /* todo FREE BUFFER */
            }
            ptr += sizeof(*txn);
            r = 0;
            break;
        }
        case BR_DEAD_BINDER: {
            struct binder_death *death = (struct binder_death *)(uintptr_t) *(binder_uintptr_t *)ptr;
            ptr += sizeof(binder_uintptr_t);
            death->func(bs, death->ptr);
            break;
        }
        case BR_FAILED_REPLY:
            r = -1;
            break;
        case BR_DEAD_REPLY:
            r = -1;
            break;
        default:
            ALOGE("parse: OOPS %d\n", cmd);
            return -1;
        }
    }
    return r;
}
```

到这里就是有对服务的操作了。比如添加、获取。

SVC_MGR_ADD_SERVICE & SVC_MGR_GET_SERVICE


```c
int svcmgr_handler(struct binder_state *bs,
                   struct binder_transaction_data_secctx *txn_secctx,
                   struct binder_io *msg,
                   struct binder_io *reply)
{
    struct svcinfo *si;
    uint16_t *s;
    size_t len;
    uint32_t handle;
    uint32_t strict_policy;
    int allow_isolated;
    uint32_t dumpsys_priority;
    struct binder_transaction_data *txn = &txn_secctx->transaction_data;
    //ALOGI("target=%p code=%d pid=%d uid=%d\n",
    //      (void*) txn->target.ptr, txn->code, txn->sender_pid, txn->sender_euid);
    if (txn->target.ptr != BINDER_SERVICE_MANAGER)
        return -1;
    if (txn->code == PING_TRANSACTION)
        return 0;
    // Equivalent to Parcel::enforceInterface(), reading the RPC
    // header with the strict mode policy mask and the interface name.
    // Note that we ignore the strict_policy and don't propagate it
    // further (since we do no outbound RPCs anyway).
    strict_policy = bio_get_uint32(msg);
    bio_get_uint32(msg);  // Ignore worksource header.
    s = bio_get_string16(msg, &len);
    if (s == NULL) {
        return -1;
    }
    if ((len != (sizeof(svcmgr_id) / 2)) ||
        memcmp(svcmgr_id, s, sizeof(svcmgr_id))) {
        fprintf(stderr,"invalid id %s\n", str8(s, len));
        return -1;
    }
    if (sehandle && selinux_status_updated() > 0) {
#ifdef VENDORSERVICEMANAGER
        struct selabel_handle *tmp_sehandle = selinux_android_vendor_service_context_handle();
#else
        struct selabel_handle *tmp_sehandle = selinux_android_service_context_handle();
#endif
        if (tmp_sehandle) {
            selabel_close(sehandle);
            sehandle = tmp_sehandle;
        }
    }
    switch(txn->code) {
    case SVC_MGR_GET_SERVICE:
    case SVC_MGR_CHECK_SERVICE:
        s = bio_get_string16(msg, &len);
        if (s == NULL) {
            return -1;
        }
        handle = do_find_service(s, len, txn->sender_euid, txn->sender_pid,
                                 (const char*) txn_secctx->secctx);
        if (!handle)
            break;
        bio_put_ref(reply, handle);
        return 0;
    case SVC_MGR_ADD_SERVICE:
        s = bio_get_string16(msg, &len);
        if (s == NULL) {
            return -1;
        }
        handle = bio_get_ref(msg);
        allow_isolated = bio_get_uint32(msg) ? 1 : 0;
        dumpsys_priority = bio_get_uint32(msg);
        if (do_add_service(bs, s, len, handle, txn->sender_euid, allow_isolated, dumpsys_priority,
                           txn->sender_pid, (const char*) txn_secctx->secctx))
            return -1;
        break;
    case SVC_MGR_LIST_SERVICES: {
        uint32_t n = bio_get_uint32(msg);
        uint32_t req_dumpsys_priority = bio_get_uint32(msg);
        if (!svc_can_list(txn->sender_pid, (const char*) txn_secctx->secctx, txn->sender_euid)) {
            ALOGE("list_service() uid=%d - PERMISSION DENIED\n",
                    txn->sender_euid);
            return -1;
        }
        si = svclist;
        // walk through the list of services n times skipping services that
        // do not support the requested priority
        while (si) {
            if (si->dumpsys_priority & req_dumpsys_priority) {
                if (n == 0) break;
                n--;
            }
            si = si->next;
        }
        if (si) {
            bio_put_string16(reply, si->name);
            return 0;
        }
        return -1;
    }
    default:
        ALOGE("unknown code %d\n", txn->code);
        return -1;
    }
    bio_put_uint32(reply, 0);
    return 0;
}
```

到这里servicemanager服务管理已经启动起来了。它主要负责服务的注册以及查询。

它的开启是为了后面启动zygote进程后, 同时启动的system-server来服务的。

## late-init

这里我们看zygote-start。

```sh
# 挂载文件系统 并 启动系统服务进程
# 这里相关联的开启了很多任务
# 我们最关注的就是zygote-start任务 就是我们的zygote进程的启动
# 
# Mount filesystems and start core system services.
on late-init
    trigger early-fs
    # Mount fstab in init.{$device}.rc by mount_all command. Optional parameter
    # '--early' can be specified to skip entries with 'latemount'.
    # /system and /vendor must be mounted by the end of the fs stage,
    # while /data is optional.
    trigger fs
    trigger post-fs
    # Mount fstab in init.{$device}.rc by mount_all with '--late' parameter
    # to only mount entries with 'latemount'. This is needed if '--early' is
    # specified in the previous mount_all command on the fs stage.
    # With /system mounted and properties form /system + /factory available,
    # some services can be started.
    trigger late-fs
    # Now we can mount /data. File encryption requires keymaster to decrypt
    # /data, which in turn can only be loaded when system properties are present.
    trigger post-fs-data
    # Load persist properties and override properties (if enabled) from /data.
    trigger load_persist_props_action
    # Now we can start zygote for devices with file based encryption
    trigger zygote-start
    # Remove a file to wake up anything waiting for firmware.
    trigger firmware_mounts_complete
    trigger early-boot
    trigger boot

on boot
    # 文件处理
    # Define default initial receive window size in segments.
    setprop net.tcp.default_init_rwnd 60
    # Start standard binderized HAL daemons
    class_start hal
    class_start core

# 根据当前的加密属性来决定启动的
# 但是看着不都一样么？？？
# It is recommended to put unnecessary data/ initialization from post-fs-data
# to start-zygote in device's init.rc to unblock zygote start.
on zygote-start && property:ro.crypto.state=unencrypted
    # A/B update verifier that marks a successful boot.
    exec_start update_verifier_nonencrypted
    start netd
    start zygote
    start zygote_secondary
on zygote-start && property:ro.crypto.state=unsupported
    # A/B update verifier that marks a successful boot.
    exec_start update_verifier_nonencrypted
    start netd
    start zygote
    start zygote_secondary
on zygote-start && property:ro.crypto.state=encrypted && property:ro.crypto.type=file
    # A/B update verifier that marks a successful boot.
    exec_start update_verifier_nonencrypted
    start netd
    start zygote
    start zygote_secondary
```

zygote进程在init.rc的头部到import了。根据当前设备的架构执行不同的执行文件。

* init.zygote32.rc：zygote 进程对应的执行程序是 app_process (纯 32bit 模式)
* init.zygote64.rc：zygote 进程对应的执行程序是 app_process64 (纯 64bit 模式)
* init.zygote32_64.rc：启动两个 zygote 进程 (名为 zygote 和 zygote_secondary)，对应的执行程序分别是 app_process32 (主模式)、app_process64
* init.zygote64_32.rc：启动两个 zygote 进程 (名为 zygote 和 zygote_secondary)，对应的执行程序分别是 app_process64 (主模式)、app_process32

32_64跟64_32又是什么鬼。为了兼容64位跟32位应用而开启的2个进程。

当应用程序是32位就使用app_process32执行文件创建进程, 否则就用64位。

前面的位数就是默认zygote进程。

都基本差不多, 我们来看下zygote32位即可。

onrestart表示进程重启就重启后面的进程。

这个时候又问了audioserver之类的是什么时候启动的呢。

查看audioserver.rc, 定义了class core。 在late-init里的boot任务中。启动了定义为core的服务。

其他的也类似的方式启动了。

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

# audioserver.rc
service audioserver /system/bin/audioserver
    class core
    user audioserver
    # media gid needed for /dev/fm (radio) and for /data/misc/media (tee)
    group audio camera drmrpc media mediadrm net_bt net_bt_admin net_bw_acct wakelock
    capabilities BLOCK_SUSPEND
    ioprio rt 4
    writepid /dev/cpuset/foreground/tasks /dev/stune/foreground/tasks
    onrestart restart vendor.audio-hal
    onrestart restart vendor.audio-hal-4-0-msd
    # Keep the original service names for backward compatibility
    onrestart restart vendor.audio-hal-2-0
    onrestart restart audio-hal-2-0
on property:vts.native_server.on=1
    stop audioserver
on property:vts.native_server.on=0
    start audioserver
on init
    mkdir /dev/socket/audioserver 0775 audioserver audioserver

```


到了这里。 init进程算真正意义上的启动完成了。

下一篇查看下rc文件的service, socket这些是如何处理。以及zygote和system-server进程的启动。

# 参考

Linux中rc文件的含义  
<https://blog.csdn.net/wendaotaoa/article/details/7513484>

android rc文件分析  
<https://www.cnblogs.com/zhougong/p/8889040.html>

Android 8.0 系统启动流程之Linux内核启动  
<https://blog.csdn.net/marshal_zsx/article/details/80225854>

android 启动流程  
<https://www.jianshu.com/p/0f1fd7c11177>

Binder系列3—启动ServiceManager  
<http://gityuan.com/2015/11/07/binder-start-sm/>

Android Binder机制(三) ServiceManager守护进程  
<https://wangkuiwu.github.io/2014/09/03/Binder-ServiceManager-Daemon/>