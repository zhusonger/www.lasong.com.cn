#!/bin/sh
pkill -f jekyll
nohup jekyll serve --detach --watch >/dev/null 2>&1 &	
