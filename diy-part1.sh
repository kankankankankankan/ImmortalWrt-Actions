#!/bin/bash
set -e
set -o pipefail

# 添加自定义软件源，插入至 feeds.conf.default 首行，置于官方软件源之前，以确保同名软件包优先采用本仓库所提供之版本
sed -i '1i src-git immortalwrt https://github.com/kankankankankankan/ImmortalWrt-Packages;main' feeds.conf.default
