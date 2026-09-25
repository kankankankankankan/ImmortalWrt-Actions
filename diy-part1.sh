#!/bin/bash
set -e
set -o pipefail

# 添加自定义软件源（追加至 feeds.conf.default 末尾，沿用 OpenWrt 标配写法）。
# dae/daed 同名冲突不在本步骤处理：官方 packages feed 中的同名包由
# ImmortalWrt-builder.yml 中的“Prefer local openwrt-daede packages”步骤移除，
# 移除后本自定义源成为唯一提供者，feeds install 即会采用本仓库所提供之版本。
printf 'src-git immortalwrt https://github.com/kankankankankankan/ImmortalWrt-Packages;main\n' >> feeds.conf.default