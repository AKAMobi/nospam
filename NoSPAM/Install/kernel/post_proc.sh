#!/bin/sh

# 如果不是 root，depmod会报错并拒绝加载模块
chown -R root lib/modules/2.4.26-noSPAM 
