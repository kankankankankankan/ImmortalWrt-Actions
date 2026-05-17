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


# =========================================================
# FakeHTTP 二进制下载 + 安装到固件
# 目标结果
# 1. 固件内包含 /usr/bin/fakehttp
# 2. 包含 /etc/init.d/fakehttp
# 3. 首次启动自动 enable
# =========================================================

# 1️⃣ 创建文件目录
mkdir -p files/usr/bin
mkdir -p files/etc/init.d
mkdir -p files/etc/uci-defaults

# ==========================
# 2️⃣ 下载 FakeHTTP 二进制并放入固件
# ==========================
echo "Downloading FakeHTTP binary..."
curl -L https://github.com/a315344690/FakeHTTP/releases/latest/download/fakehttp-linux-x86_64.tar.gz -o fakehttp.tar.gz

echo "Extracting FakeHTTP..."
tar xzvf fakehttp.tar.gz
chmod +x fakehttp-linux-x86_64/fakehttp
mv fakehttp-linux-x86_64/fakehttp files/usr/bin/
rm -rf fakehttp.tar.gz fakehttp-linux-x86_64

# ==========================
# 3️⃣ 创建 init 脚本
# ==========================
cat << 'EOF' > files/etc/init.d/fakehttp
#!/bin/sh /etc/rc.common
USE_PROCD=1
START=95
STOP=01

start_service() {
    procd_open_instance
    procd_set_param command fakehttp -d -a -e creator.douyin.com -e vd3.bdstatic.com -e p3-pc-sign.douyinpic.com -e i0.hdslb.com -e cn-sxxa-cm-01-12.bilivideo.com -e cn-sxxa-cm-01-04.bilivideo.com -e cn-sxxa-ct-03-03.bilivideo.com -e cn-sxxa-cu-02-01.bilivideo.com -e www.speedtest.cn -e pan.quark.cn -e www.123pan.com -e onedrive.live.com -e www.alipan.com -e dlcv2.cnspeedtest.cn -e yun.139.com -e ykj-eos-wx2-01.eos-wuxi-3.cmecloud.cn -e test.ustc.edu.cn -h yun.139.com -h d1-ant.baidu.com -h pan.baidu.com -e ykj-eos-dg5-01.eos-dongguan-6.cmec
    procd_close_instance
}

stop_service() {
    fakehttp -k
}

restart_service() {
    stop
    start
}
EOF

chmod +x files/etc/init.d/fakehttp

# ==========================
# 4️⃣ 创建 uci-defaults 脚本，开机自动 enable
# ==========================
cat << 'EOF' > files/etc/uci-defaults/10_fakehttp_enable
#!/bin/sh
# Enable FakeHTTP service on first boot
/etc/init.d/fakehttp enable
exit 0
EOF

chmod +x files/etc/uci-defaults/10_fakehttp_enable
echo "FakeHTTP integration done."

# 调用补充脚本
# bash "$(dirname "$0")/patch-luci-menu.sh"
