---
title: 01:Github/Gitee Pages 绑定自定义域名, 加快访问速度
author: Zhusong
layout: post
category: Server
home_btn: true
btn_text: true
footer: true
maximize: true
date: 2020-2-9
---


## 一：问题描述

国内访问Github Pages还是稍微有点慢, 想要加快点访问速度

## 二：想要的结果

国内访问国内的服务器, 国外访问国外的, 区分对待, 加快访问速度

## 三：解决方案

### Gitee Pages
码云 Pages 是一个免费的静态网页托管服务，您可以使用 码云 Pages 托管博客、项目官网等静态网页。如果您使用过 Github Pages 那么您会很快上手使用码云的 Pages服务。目前码云 Pages 支持 Jekyll、Hugo、Hexo编译静态资源。

## 四：步骤
1. 按步骤注册Gitee账号
2. 从Github导入项目, 仓库名称跟归属会自动填充, 先不管
> <img src="{{site.url}}{{site.baseurl}}{{site.assets_path}}/img/server/img-gitee-pages.png" width="80%">
> <img src="{{site.url}}{{site.baseurl}}{{site.assets_path}}/img/server/img-gitee-pages-import.png" width="80%">

3. 为了跟Github Pages一样, 一个域名直接定位到这个Pages, 修改项目路径, 如果想要跟Github的项目同步, 点一下项目名称旁边的刷新按钮即可(那个圆圈)
> <img src="{{site.url}}{{site.baseurl}}{{site.assets_path}}/img/server/img-gitee-pages-setting.png" width="80%">

4. 切换到服务 => Gitee Pages开启即可
5. 到这一步, 你只要方位https://username.gitee.io就可以看到了,下面开始配置DNS自定义域名的解析设置
6. 在阿里云DNS内配置解析
> <img src="{{site.url}}{{site.baseurl}}{{site.assets_path}}/img/server/img-gitee-pages-dns.png" width="80%">
> <img src="{{site.url}}{{site.baseurl}}{{site.assets_path}}/img/server/img-gitee-pages-dns-look.png" width="80%">