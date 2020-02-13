---
title: 04:Jenkins&Webhook&Shell&Python 实现Github Pages与Gitee Pages的自动同步
author: Zhusong
layout: post
category: Server
home_btn: true
btn_text: true
footer: true
maximize: true
date: 2020-2-14
excerpt: "04:Jenkins&Webhook&Shell&Python 实现Github Pages与Gitee Pages的自动同步"
abstract: ""
---

## 问题
在之前实现了国内国外不同的个人博客之后, 发现经常会出现莫名其妙的问题导致页面错位乱掉了, 原来是国内的Gitee Pages强制同步Github之后, 域名对应不上, 而且国内的Gitee Pages自定义域名/HTTPS/自动部署都需要收费, 就改成默认是Github Pages, 百度搜索给成Gitee Pages

那么同步Github到Gitee这个问题就比较棘手了

## 方案一
一种是手动操作, 每次有改动都去这么操作一次
> 一般的做法:  
> 1.登录Gitee  
> 2.点击强制同步按钮  
> 3.修改_config.yml域名为Gitee Pages的域名  
> 4.点击更新按钮等待部署完成

## 方案二
作为一个嫌麻烦的人又穷的人, 我不喜欢这样的方式, 就换种方式
> 1. 开始麻烦,后面不用管的做法:  
> 2. Jenkins开通Webhook功能获取到地址  
> 3. Github开通Webhook功能配置Jenkins地址, 每次Push通知Jenkins 
> 4. 新建Jenkins自由风格任务, 添加Github Pages项目库  
> 5. 本地clone下来Gitee Pages的工程库  
> 6. Jenkins任务构建执行Shell脚本
> 
> 	```shell
	#!/bin/sh
	echo "当前目录"
	pwd
	echo "拷贝"
	cp -rf assets/ ~/Git/zhusong/
	cp -rf _posts/ ~/Git/zhusong/
	cd ~/Git/zhusong
	echo "目标目录"
	pwd
	echo "开始拉取最新代码"
	git pull
	echo "开始提交"
	git add .
	git commit -m "同步Github Pages Jenkins自动执行"
	echo "开始远程推送"
	git push
	echo "完成同步"
	echo "开始执行部署Gitee脚本"
> 	```  
> 7. Jenkins任务构建执行Python脚本, 模拟一般做法中的操作步骤  
>
>	```python
	#! /usr/bin/python3
	# -*- coding: utf-8 -*-
	from selenium import webdriver
	from selenium.webdriver.chrome.options import Options
	from selenium.webdriver.common.action_chains import ActionChains
	from selenium.webdriver.support import expected_conditions as EC
	from selenium.webdriver.support.wait import WebDriverWait
	import time	
>	
	chrome_options = Options()
	chrome_options.add_argument('--headless')    # 设置无界面
	chrome_options.add_argument('--no-sandbox')  # root用户下运行代码需添加这一行
	chrome_options.add_argument('--disable-dev-shm-usage') #不加载图片, 提升速度
	chrome_options.add_argument('--disable-gpu') # 谷歌文档提到需要加上这个属性来规避bug
	driver = webdriver.Chrome(options=chrome_options)
	driver.get('https://gitee.com/login')
	driver.find_element_by_id('user_login').send_keys("userename")
	driver.find_element_by_id('user_password').send_keys("passwd")
	driver.find_element_by_id('new_user').submit()
	driver.implicitly_wait(30)
	print(f"enter home: {driver.title}")
	time.sleep(3)
	driver.get('https://gitee.com/{your path}/pages')
	print(f"enter page: {driver.title}")
	time.sleep(3)
	targetClickButton = driver.find_element_by_class_name("update_deploy")
	ActionChains(driver).click(targetClickButton).perform()
	print(f"click update deploy")
	time.sleep(2)
	alert = driver.switch_to.alert
	time.sleep(2)
	alert.accept()
	print(f"accept confirm")
	time.sleep(2)
	print(f"wait for deploy...")
	WebDriverWait(driver, 30, 1).until(EC.staleness_of(driver.find_element_by_id("pages_deploying")))
	print(f"deploy finish")
	print(f"all finish & quit")
	driver.quit()	
>	```
> 8. 收工, 以后只要管Github上的项目就行了

## 参考地址
1. Jenkins与Github集成 webhook配置  
	<https://blog.csdn.net/qq_21768483/article/details/80177920>  
	
2. Python+Selenium基础入门及实践  
	<https://www.jianshu.com/p/1531e12f8852>

 