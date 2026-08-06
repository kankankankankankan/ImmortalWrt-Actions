#!/bin/bash
set -e
set -o pipefail

# =========================================================
# 替换 OpenWrt 的 Go 编译工具链
#
# 原因：
# ImmortalWrt 24.10.x 默认 golang/host 版本是 Go 1.23.x。
# 现在部分 Go 软件包，例如 v2dat，依赖链可能要求 Go >= 1.25。
# OpenWrt 编译 Go 包时使用 feeds/packages/lang/golang 里的 golang/host，
# 不是直接使用 GitHub Actions 系统自带的 go 命令。
#
# 处理方式：
# 主系统继续使用 ImmortalWrt v24.10.6 稳定版，
# 只替换 feeds/packages/lang/golang 为 sbwml 维护的新版本 Go 工具链。
# 这样不用直接切到 openwrt-25.12，整体风险更小。
# =========================================================

echo "===== 替换 feeds/packages/lang/golang ====="
rm -rf feeds/packages/lang/golang
git clone --depth=1 -b 26.x https://github.com/sbwml/packages_lang_golang feeds/packages/lang/golang
echo "===== 当前 Go 工具链版本信息 ====="
grep -R "GO_VERSION_MAJOR_MINOR\|GO_VERSION_PATCH\|PKG_VERSION" feeds/packages/lang/golang/golang*/Makefile || true

# 清理旧的 Go host 构建缓存，避免继续沿用 1.23.x 的旧产物
rm -rf build_dir/hostpkg/golang*
rm -rf staging_dir/hostpkg/lib/go*
rm -rf staging_dir/hostpkg/bin/go
rm -rf tmp/go-build