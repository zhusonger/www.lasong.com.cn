---
title: 02:Chrome清除DNS缓存
author: Zhusong
layout: post
post_list: "category"
category: Server
home_btn: true
btn_text: true
footer: true
maximize: true
date: 2020-2-13
excerpt: "02:Chrome清除DNS缓存"
abstract: ""
---


## 一：问题描述

Chrome老是访问缓存, 其实网站/反向代理已经更新, 但是就是不生效

## 二：想要的结果

清除掉DNS的缓存, 重新加载新的地址

## 三：步骤
打开调试工具(mac:option + command + i, windows:ctrl + shift + i) , 按住地址栏刷新按钮，出现子菜单，选择[清空缓存并硬性重新加载]，解决
> <img src="{{site.assets_path}}/img/server/img-chrome-clean-dns.png" width="80%">

## 链接
https://laotan.net/clear-chrome-301-disk-cache/