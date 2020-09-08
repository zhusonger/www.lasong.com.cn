---
title: 02:Android rc解析过程以及zygote进程的启动过程
author: Zhusong
layout: post
footer: true
category: Android Framework
date: 2020-04-02
excerpt: "02:Android rc解析过程以及zygote进程的启动过程"
abstract: ""
---
# 源码

Android源码  
<https://android.googlesource.com/>

<https://www.androidos.net.cn/sourcecode>

Android通用内核代码  
<https://android.googlesource.com/kernel/common/>

Bootlin Linux系统源码查看  
<https://elixir.bootlin.com/linux/latest/source>

# 概述

上一章查看了init进程的启动流程。

首先是内核执行汇编代码, 进入到C代码, 通过idle(PID=0)通过kernel_init执行/init文件。

/init入口是platform/system/core/init/main.cpp。

在Android10之后修改了代码。在这里分开执行了几个阶段。

FirstStageMain => SetupSelinux => SecondStageMain

在SecondStageMain里执行我们关注的加载init.rc的过程。

init.rc的主要过程

early-init => init => late-init

在early-init导入系统配置开启ueventd服务。

在init启动logd、servicemanager、hwservicemanager、vndservicemanager服务。

在late-init启动文件相关过程以及我们最关心的zygote的启动。

上一篇我们是按照init.rc的过程来认为已经启动进程。

这一篇我们看下它是怎么启动的。

# CreateParser

在init.cpp里。我们看到构造方法里有传一个service_list和subcontexts。构造方法的定义在头文件中[service.h](https://android.googlesource.com/platform/system/core/+/refs/tags/android-10.0.0_r32/init/service.h)。service_list是从一个单例中得到的。这样可以保证所有的服务都在这个单例里。

```c
// init.cpp

ServiceList& sm = ServiceList::GetInstance();

Parser CreateParser(ActionManager& action_manager, ServiceList& service_list) {
    Parser parser;
    parser.AddSectionParser("service", std::make_unique<ServiceParser>(&service_list, subcontexts));
    parser.AddSectionParser("on", std::make_unique<ActionParser>(&action_manager, subcontexts));
    parser.AddSectionParser("import", std::make_unique<ImportParser>(&parser));
    return parser;
}

parser.ParseConfig("/init.rc");
```
接着我们会在LoadBootScripts开始parse。

# ParseConfig

我们开始加载init.rc。

这个加载的过程在[parse.cpp](https://android.googlesource.com/platform/system/core/+/refs/tags/android-10.0.0_r32/init/parser.cpp)。截取核心代码。我们在init.cpp中已经设置过自定义处理指令的解析器了。到这里, 我们知道了是从哪里开始处理各个tag的。


我们这里以service举例。

回顾一下init.zygote32.rc的配置。
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

然后继续来看代码。我们这里以解析service为例。首先调用ParseSection解析第一行, 得到代表服务的Service对象。并在service结束调用EndSection来加入到service_list列表中。 

并继续使用解析service时的解析器解析后面的内容。  

```c
bool Parser::ParseConfig(const std::string& path) {
    if (is_dir(path.c_str())) {
        return ParseConfigDir(path);
    }
    return ParseConfigFile(path);
}

bool Parser::ParseConfigFile(const std::string& path) {
    LOG(INFO) << "Parsing file " << path << "...";
    android::base::Timer t;
    auto config_contents = ReadFile(path);
    if (!config_contents) {
        LOG(INFO) << "Unable to read config file '" << path << "': " << config_contents.error();
        return false;
    }
    ParseData(path, &config_contents.value());
    LOG(VERBOSE) << "(Parsing " << path << " took " << t << ".)";
    return true;
}

void Parser::ParseData(const std::string& filename, std::string* data) {
    data->push_back('\n');  // TODO: fix tokenizer
    data->push_back('\0');
    parse_state state;
    state.line = 0;
    state.ptr = data->data();
    state.nexttoken = 0;
    SectionParser* section_parser = nullptr;
    int section_start_line = -1;
    std::vector<std::string> args;
    // If we encounter a bad section start, there is no valid parser object to parse the subsequent
    // sections, so we must suppress errors until the next valid section is found.
    bool bad_section_found = false;
    auto end_section = [&] {
        bad_section_found = false;
        if (section_parser == nullptr) return;
        if (auto result = section_parser->EndSection(); !result) {
            parse_error_count_++;
            LOG(ERROR) << filename << ": " << section_start_line << ": " << result.error();
        }
        section_parser = nullptr;
        section_start_line = -1;
    };
    for (;;) {
        switch (next_token(&state)) {
            case T_EOF:
                end_section();
                for (const auto& [section_name, section_parser] : section_parsers_) {
                    section_parser->EndFile();
                }
                return;
            case T_NEWLINE: {
                state.line++;
                if (args.empty()) break;
                // If we have a line matching a prefix we recognize, call its callback and unset any
                // current section parsers.  This is meant for /sys/ and /dev/ line entries for
                // uevent.
                auto line_callback = std::find_if(
                    line_callbacks_.begin(), line_callbacks_.end(),
                    [&args](const auto& c) { return android::base::StartsWith(args[0], c.first); });
                if (line_callback != line_callbacks_.end()) {
                    end_section();
                    if (auto result = line_callback->second(std::move(args)); !result) {
                        parse_error_count_++;
                        LOG(ERROR) << filename << ": " << state.line << ": " << result.error();
                    }
                }
                // 如果有设置自定义解析器, 优先使用
                // 以service为例, 第一行是service开头,args[0]即为service。
                // 取得自定义解析器ServiceParser解析
                else if (section_parsers_.count(args[0])) {
                    end_section();
                    section_parser = section_parsers_[args[0]].get();
                    section_start_line = state.line;
                    if (auto result =
                            section_parser->ParseSection(std::move(args), filename, state.line);
                        !result) {
                        parse_error_count_++;
                        LOG(ERROR) << filename << ": " << state.line << ": " << result.error();
                        section_parser = nullptr;
                        bad_section_found = true;
                    }
                } 
                // 当解析第二行时, 不再是service开始, 但是属于service模块下的内容
                // 使用上次的section_parser, 即ServiceParser
                else if (section_parser) {
                    if (auto result = section_parser->ParseLineSection(std::move(args), state.line);
                        !result) {
                        parse_error_count_++;
                        LOG(ERROR) << filename << ": " << state.line << ": " << result.error();
                    }
                } else if (!bad_section_found) {
                    parse_error_count_++;
                    LOG(ERROR) << filename << ": " << state.line
                               << ": Invalid section keyword found";
                }
                args.clear();
                break;
            }
            case T_TEXT:
                args.emplace_back(state.text);
                break;
        }
    }
}
```
# service.cpp

在[service.cpp](https://android.googlesource.com/platform/system/core/+/refs/tags/android-10.0.0_r32/init/service.cpp)中, 我们直接看ServiceParse对应的方法。ParseSection上面已经提过。是生成Service对象加入到服务队列中。

再来看ParseLineSection。它直接让生成的Service对象来处理它自己的内容并更新自己的字段。

比如socket, 就会调用ParseSocket方法。并把信息存储到descriptors_字段中。

```c
Result<void> ServiceParser::ParseSection(std::vector<std::string>&& args,
                                         const std::string& filename, int line) {
    if (args.size() < 3) {
        return Error() << "services must have a name and a program";
    }

    const std::string& name = args[1];
    if (!IsValidName(name)) {
        return Error() << "invalid service name '" << name << "'";
    }

    filename_ = filename;

    Subcontext* restart_action_subcontext = nullptr;
    if (subcontext_ && subcontext_->PathMatchesSubcontext(filename)) {
        restart_action_subcontext = subcontext_;
    }

    std::vector<std::string> str_args(args.begin() + 2, args.end());

    if (SelinuxGetVendorAndroidVersion() <= __ANDROID_API_P__) {
        if (str_args[0] == "/sbin/watchdogd") {
            str_args[0] = "/system/bin/watchdogd";
        }
    }
    if (SelinuxGetVendorAndroidVersion() <= __ANDROID_API_Q__) {
        if (str_args[0] == "/charger") {
            str_args[0] = "/system/bin/charger";
        }
    }
    // 生成一个Service对象
    // 在结束一行的解析后会执行EndSection 保存到service_list列表中用来启动
    service_ = std::make_unique<Service>(name, restart_action_subcontext, str_args, from_apex_);
    return {};
}


Result<Success> ServiceParser::EndSection() {
    if (service_) {
        Service* old_service = service_list_->FindService(service_->name());
        if (old_service) {
            if (!service_->is_override()) {
                return Error() << "ignored duplicate definition of service '" << service_->name()
                               << "'";
            }
            if (StartsWith(filename_, "/apex/") && !old_service->is_updatable()) {
                return Error() << "cannot update a non-updatable service '" << service_->name()
                               << "' with a config in APEX";
            }
            service_list_->RemoveService(*old_service);
            old_service = nullptr;
        }
        // 结束添加解析的Service到队列中
        service_list_->AddService(std::move(service_));
    }
    return Success();
}

void ServiceList::AddService(std::unique_ptr<Service> service) {
    services_.emplace_back(std::move(service));
}

Result<Success> ServiceParser::ParseLineSection(std::vector<std::string>&& args, int line) {
    return service_ ? service_->ParseLine(std::move(args)) : Success();
}

Result<Success> Service::ParseLine(std::vector<std::string>&& args) {
    // 从OptionParserMap找到解析的parse方法
    static const OptionParserMap parser_map;
    auto parser = parser_map.FindFunction(args);
    if (!parser) return parser.error();
    // 执行每一行对应的parse方法
    return std::invoke(*parser, this, std::move(args));
}

const Service::OptionParserMap::Map& Service::OptionParserMap::map() const {
    constexpr std::size_t kMax = std::numeric_limits<std::size_t>::max();
    // clang-format off
    static const Map option_parsers = {
        //...
        {"socket",      {3,     6,    &Service::ParseSocket}},
        //...
    };
    // clang-format on
    return option_parsers;
}

// name type perm [ uid gid context ]
Result<Success> Service::ParseSocket(std::vector<std::string>&& args) {
    if (!StartsWith(args[2], "dgram") && !StartsWith(args[2], "stream") &&
        !StartsWith(args[2], "seqpacket")) {
        return Error() << "socket type must be 'dgram', 'stream' or 'seqpacket'";
    }
    return AddDescriptor<SocketInfo>(std::move(args));
}

template <typename T>
Result<Success> Service::AddDescriptor(std::vector<std::string>&& args) {
    // ...
    // 这是个模板方法。比如上面的就是创建SocketInfo对象。
    auto descriptor = std::make_unique<T>(args[1], args[2], *uid, *gid, perm, context);
    // 将SocketInfo存入descriptors_
    descriptors_.emplace_back(std::move(descriptor));
    return Success();
}
```

# init.cpp

下一步就是回到init.cpp查看后面执行的代码。

这里我们先不看HandleProcessActions, 它只是调用Service的Start方法。

在之前我们已经把service解析成对象了。在init.rc里通过start方法启动了zygote服务。

跟上面OptionParserMap一样。init.cpp中也有一个get_control_message_map储存对应的方法。

这个方法的调用是在HandleControlMessage, 具体在哪里调用的。由于使用的网站不太好找。

正在下载源码中。找起来会比较方便。

在之前的代码就是在init.cpp的循环内调用的HandleControlMessage。

```c
// init.cpp#SecondStageMain
// ...
// Trigger all the boot actions to get us started.
am.QueueEventTrigger("init");
// ...
// Don't mount filesystems or start core system services in charger mode.
std::string bootmode = GetProperty("ro.bootmode", "");
if (bootmode == "charger") {
    am.QueueEventTrigger("charger");
} else {
    am.QueueEventTrigger("late-init");
}
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
        // 执行命令
        am.ExecuteOneCommand();
    }
    if (!(waiting_for_prop || Service::is_exec_service_running())) {
        if (!shutting_down) {
            // 每次都会检测需要重启的服务
            auto next_process_action_time = HandleProcessActions();
            // If there's a process that needs restarting, wake up in time for that.
            if (next_process_action_time) {
                epoll_timeout = std::chrono::ceil<std::chrono::milliseconds>(
                        *next_process_action_time - boot_clock::now());
                if (*epoll_timeout < 0ms) epoll_timeout = 0ms;
            }
        }
        // 如果队列非空, 就把执行等待时间设置为0, 表示不等待
        // If there's more work to do, wake up again immediately.
        if (am.HasMoreCommands()) epoll_timeout = 0ms;
    }
    if (auto result = epoll.Wait(epoll_timeout); !result) {
        LOG(ERROR) << result.error();
    }
}

// HandleProcessActions方法会进行service的重启
static std::optional<boot_clock::time_point> HandleProcessActions() {
    std::optional<boot_clock::time_point> next_process_action_time;
    for (const auto& s : ServiceList::GetInstance()) {
        if ((s->flags() & SVC_RUNNING) && s->timeout_period()) {
            auto timeout_time = s->time_started() + *s->timeout_period();
            if (boot_clock::now() > timeout_time) {
                s->Timeout();
            } else {
                if (!next_process_action_time || timeout_time < *next_process_action_time) {
                    next_process_action_time = timeout_time;
                }
            }
        }
        // 如果没有重启 就忽略
        if (!(s->flags() & SVC_RESTARTING)) continue;

        auto restart_time = s->time_started() + s->restart_period();
        if (boot_clock::now() > restart_time) {
            // 如果超过需要重启的时间, 重新启动service
            if (auto result = s->Start(); !result.ok()) {
                LOG(ERROR) << "Could not restart process '" << s->name() << "': " << result.error();
            }
        } else {
            if (!next_process_action_time || restart_time < *next_process_action_time) {
                next_process_action_time = restart_time;
            }
        }
    }
    return next_process_action_time;
}

static const std::map<std::string, ControlMessageFunction>& get_control_message_map() {
    // clang-format off
    static const std::map<std::string, ControlMessageFunction> control_message_functions = {
        {"sigstop_on",        {ControlTarget::SERVICE,
                               [](auto* service) { service->set_sigstop(true); return Success(); }}},
        {"sigstop_off",       {ControlTarget::SERVICE,
                               [](auto* service) { service->set_sigstop(false); return Success(); }}},
        {"start",             {ControlTarget::SERVICE,   DoControlStart}},
        {"stop",              {ControlTarget::SERVICE,   DoControlStop}},
        {"restart",           {ControlTarget::SERVICE,   DoControlRestart}},
        {"interface_start",   {ControlTarget::INTERFACE, DoControlStart}},
        {"interface_stop",    {ControlTarget::INTERFACE, DoControlStop}},
        {"interface_restart", {ControlTarget::INTERFACE, DoControlRestart}},
    };
    // clang-format on
    return control_message_functions;
}

static Result<void> DoControlStart(Service* service) {
    return service->Start();
}
```

# Service.Start

到这里终于到我们service进程的创建了。不容易啊。

首先通过init进程fork出子进程。再对设置的其它行为进程创建并发布。比如socket。

跟以前的代码不一样。现在是通过DescriptorInfo来创建对应的任务了。比较隐蔽。

在[descriptors.cpp](https://android.googlesource.com/platform/system/core/+/refs/tags/android-9.0.0_r54/init/descriptors.cpp)中, 找到CreateAndPublish方法定义以及SocketInfo类定义。

可以看到在CreateAndPublish方法中创建并发布了这个任务。具体做什么由子类重写。

比如SocketInfo的Create方法就是CreateSocket创建一个

```c
Result<Success> Service::Start() {
    //...
    LOG(INFO) << "starting service '" << name_ << "'...";
    pid_t pid = -1;
    if (namespace_flags_) {
        pid = clone(nullptr, nullptr, namespace_flags_ | SIGCHLD, nullptr);
    } else {
        // 在这里会fork出一个新的进程
        pid = fork();
    }
    // 这个是新创建的进程。即在init进程里创建的子进程
    // 调用的线程直接进入后面的代码执行
    // 子进程返回0, 父进程返回子进程pid
    if (pid == 0) {
        // ...
        std::for_each(descriptors_.begin(), descriptors_.end(),
                      std::bind(&DescriptorInfo::CreateAndPublish, std::placeholders::_1, scon));
        _exit(127);
    }
    if (pid < 0) {
        pid_ = 0;
        return ErrnoError() << "Failed to fork";
    }
    // ...
    NotifyStateChange("running");
    return Success();
}

// descriptors.cpp
void DescriptorInfo::CreateAndPublish(const std::string& globalContext) const {
  // Create
  const std::string& contextStr = context_.empty() ? globalContext : context_;
  int fd = Create(contextStr);
  if (fd < 0) return;
  // Publish
  std::string publishedName = key() + name_;
  std::for_each(publishedName.begin(), publishedName.end(),
                [] (char& c) { c = isalnum(c) ? c : '_'; });
  std::string val = std::to_string(fd);
  setenv(publishedName.c_str(), val.c_str(), 1);
  // make sure we don't close on exec
  fcntl(fd, F_SETFD, 0);
}

SocketInfo::SocketInfo(const std::string& name, const std::string& type, uid_t uid,
                       gid_t gid, int perm, const std::string& context)
        : DescriptorInfo(name, type, uid, gid, perm, context) {
}
void SocketInfo::Clean() const {
    std::string path = android::base::StringPrintf("%s/%s", ANDROID_SOCKET_DIR, name().c_str());
    unlink(path.c_str());
}
int SocketInfo::Create(const std::string& context) const {
    auto types = android::base::Split(type(), "+");
    int flags =
        ((types[0] == "stream" ? SOCK_STREAM : (types[0] == "dgram" ? SOCK_DGRAM : SOCK_SEQPACKET)));
    bool passcred = types.size() > 1 && types[1] == "passcred";
    return CreateSocket(name().c_str(), flags, passcred, perm(), uid(), gid(), context.c_str());
}
const std::string SocketInfo::key() const {
  return ANDROID_SOCKET_ENV_PREFIX;
}
```

# CreateSocket

在[utils.cpp](https://android.googlesource.com/platform/system/core/+/refs/tags/android-10.0.0_r32/init/util.cpp)中创建socket。这就是服务socket的创建过程, 到这里只是创建, 还没有发布。

```c
#define ANDROID_SOCKET_ENV_PREFIX   "ANDROID_SOCKET_"
#define ANDROID_SOCKET_DIR      "/dev/socket"

/*
 * CreateSocket - creates a Unix domain socket in ANDROID_SOCKET_DIR
 * ("/dev/socket") as dictated in init.rc. This socket is inherited by the
 * daemon. We communicate the file descriptor's value via the environment
 * variable ANDROID_SOCKET_ENV_PREFIX<name> ("ANDROID_SOCKET_foo").
 */
int CreateSocket(const char* name, int type, bool passcred, mode_t perm, uid_t uid, gid_t gid,
                 const char* socketcon) {
    if (socketcon) {
        if (setsockcreatecon(socketcon) == -1) {
            PLOG(ERROR) << "setsockcreatecon(\"" << socketcon << "\") failed";
            return -1;
        }
    }
    android::base::unique_fd fd(socket(PF_UNIX, type, 0));
    if (fd < 0) {
        PLOG(ERROR) << "Failed to open socket '" << name << "'";
        return -1;
    }
    if (socketcon) setsockcreatecon(NULL);
    struct sockaddr_un addr;
    memset(&addr, 0 , sizeof(addr));
    addr.sun_family = AF_UNIX;
    snprintf(addr.sun_path, sizeof(addr.sun_path), ANDROID_SOCKET_DIR"/%s",
             name);
    if ((unlink(addr.sun_path) != 0) && (errno != ENOENT)) {
        PLOG(ERROR) << "Failed to unlink old socket '" << name << "'";
        return -1;
    }
    std::string secontext;
    if (SelabelLookupFileContext(addr.sun_path, S_IFSOCK, &secontext) && !secontext.empty()) {
        setfscreatecon(secontext.c_str());
    }
    if (passcred) {
        int on = 1;
        if (setsockopt(fd, SOL_SOCKET, SO_PASSCRED, &on, sizeof(on))) {
            PLOG(ERROR) << "Failed to set SO_PASSCRED '" << name << "'";
            return -1;
        }
    }
    int ret = bind(fd, (struct sockaddr *) &addr, sizeof (addr));
    int savederrno = errno;
    if (!secontext.empty()) {
        setfscreatecon(nullptr);
    }
    if (ret) {
        errno = savederrno;
        PLOG(ERROR) << "Failed to bind socket '" << name << "'";
        goto out_unlink;
    }
    if (lchown(addr.sun_path, uid, gid)) {
        PLOG(ERROR) << "Failed to lchown socket '" << addr.sun_path << "'";
        goto out_unlink;
    }
    if (fchmodat(AT_FDCWD, addr.sun_path, perm, AT_SYMLINK_NOFOLLOW)) {
        PLOG(ERROR) << "Failed to fchmodat socket '" << addr.sun_path << "'";
        goto out_unlink;
    }
    LOG(INFO) << "Created socket '" << addr.sun_path << "'"
              << ", mode " << std::oct << perm << std::dec
              << ", user " << uid
              << ", group " << gid;
    return fd.release();
out_unlink:
    unlink(addr.sun_path);
    return -1;
}
```

在上一步Create完成之后, 开始发布任务。key()方法返回的就是ANDROID_SOCKET_ENV_PREFIX, 即ANDROID_SOCKET_。 如果是zygote, 那就是ANDROID_SOCKET_zygote, setenv方法将socket发布到系统中。

```c
// descriptors.cpp
void DescriptorInfo::CreateAndPublish(const std::string& globalContext) const {
  // Create
  const std::string& contextStr = context_.empty() ? globalContext : context_;
  int fd = Create(contextStr);
  if (fd < 0) return;
  // Publish
  std::string publishedName = key() + name_;
  std::for_each(publishedName.begin(), publishedName.end(),
                [] (char& c) { c = isalnum(c) ? c : '_'; });
  std::string val = std::to_string(fd);
  setenv(publishedName.c_str(), val.c_str(), 1);
  // make sure we don't close on exec
  fcntl(fd, F_SETFD, 0);
}
```

到这里。我们rc的解析流程也差不多了。

zygote进程也的C++代码执行完了。

这里主要是在查找socket的创建过程。

因为后面创建应用进程, 都是通过socket连接zygote进程来创建的。

所以我们要清楚, 服务端的socket是如何创建的。

然后回到最开始的/system/bin/app_process执行文件的内容。

找到[app_process.cpp](https://android.googlesource.com/platform/frameworks/base/+/refs/tags/android-10.0.0_r32/cmds/app_process/app_main.cpp)。

这个继续下一章进程分析。

