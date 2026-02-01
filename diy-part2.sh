#!/bin/bash
set -e
set -o pipefail

# 确认在 ImmortalWrt 或 OpenWrt 源码根目录执行
if [ ! -d "package" ] || [ ! -f "include/target.mk" ]; then
  echo "Error: please run this script in OpenWrt or ImmortalWrt source root."
  exit 1
fi

# =========================================================
# luci-app-daed 源码集成
# 目标结果
# 1. 在 package/dae 出现 luci-app-daed 源码
# 2. 后续 make defconfig 与 make 编译时可选中并打包进固件
# =========================================================
if [ ! -d "package/dae" ]; then
  git clone --depth=1 https://github.com/QiuSimons/luci-app-daed package/dae
else
  echo "package/dae already exists, skip clone."
fi

rm -rf feeds/packages/net/daed
rm -rf package/feeds/packages/daed

# 兼容 go1.23，移除 greenteagc
FILES="$(grep -RIl "greenteagc" package/dae 2>/dev/null || true)"
if [ -n "$FILES" ]; then
  echo "Patch: remove GOEXPERIMENT greenteagc for go1.23 toolchain"
  echo "$FILES"
  echo "$FILES" | xargs -r sed -i \
    -e 's/greenteagc,//g' \
    -e 's/,greenteagc//g' \
    -e 's/greenteagc//g'
fi

# =========================================================
# FakeHTTP 二进制下载 + 安装到固件
# 目标结果
# 1. 固件内包含 /usr/bin/fakehttp
# 2. 包含 /etc/init.d/fakehttp
# 3. 首次启动自动 enable
# 注意
# 这里会下载第三方二进制并打包进固件
# 如果你希望我帮你加版本固定与 sha256 校验的安全写法，请回复同意
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
