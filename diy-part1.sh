#!/bin/bash
set -e
set -o pipefail

# 添加自定义软件源
echo 'src-git immortalwrt https://github.com/kankankankankankan/ImmortalWrt-Packages;main' >> feeds.conf.default