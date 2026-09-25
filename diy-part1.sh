#!/bin/bash
set -e
set -o pipefail

# 添加自定义软件源，插到 feeds.conf.default 最前面（在官方 packages 之前），同名包以咱们的优先
sed -i '1i src-git immortalwrt https://github.com/kankankankankankan/ImmortalWrt-Packages;main' feeds.conf.default
