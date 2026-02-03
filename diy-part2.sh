#!/bin/bash
set -e
set -o pipefail

# 需在 ImmortalWrt 或 OpenWrt 源码根目录执行
if [ ! -d "package" ] || [ ! -f "include/target.mk" ]; then
  echo "Error: please run this script in OpenWrt or ImmortalWrt source root."
  exit 1
fi

echo "[1/7] Prepare luci-app-daed source"
if [ ! -d "package/dae" ]; then
  git clone --depth=1 https://github.com/QiuSimons/luci-app-daed package/dae
else
  echo "package/dae already exists, skip clone."
fi

# 避免与 feeds 里的 daed 冲突
rm -rf feeds/packages/net/daed
rm -rf package/feeds/packages/daed

echo "[2/7] Sanitize GOEXPERIMENT in build system (include/ + feeds/)"
PATCH_ROOTS="include feeds"

# A. 移除已知会触发 unknown GOEXPERIMENT 的实验项
BAD_EXPS="greenteagc runtimefreegc simd"
for exp in $BAD_EXPS; do
  FILES="$(grep -RIl --binary-files=without-match "$exp" $PATCH_ROOTS 2>/dev/null || true)"
  if [ -n "$FILES" ]; then
    echo "Patch: remove token '${exp}' from:"
    echo "$FILES"
    echo "$FILES" | xargs -r sed -i \
      -e "s/${exp},//g" \
      -e "s/,${exp}//g" \
      -e "s/${exp}//g"
  fi
done

ASSIGN_FILES="$(grep -RIl --binary-files=without-match -E '^(export[[:space:]]+)?GOEXPERIMENT[:?]?=' $PATCH_ROOTS 2>/dev/null || true)"
if [ -n "$ASSIGN_FILES" ]; then
  echo "Patch: clear GOEXPERIMENT assignment in:"
  echo "$ASSIGN_FILES"
  echo "$ASSIGN_FILES" | xargs -r sed -i -E \
    -e 's/^(export[[:space:]]+)?GOEXPERIMENT([:?]?=).*/GOEXPERIMENT\2/'
fi

if [ -f "feeds/packages/lang/golang/golang-build.sh" ]; then
  if grep -q "GOEXPERIMENT=" feeds/packages/lang/golang/golang-build.sh; then
    echo "Patch: clear inline GOEXPERIMENT=... in feeds/packages/lang/golang/golang-build.sh"
    sed -i -E 's/GOEXPERIMENT=[^[:space:]]+/GOEXPERIMENT=/g' feeds/packages/lang/golang/golang-build.sh
  fi
fi

echo "[3/7] Sanitize GOEXPERIMENT tokens inside package/dae (third party)"
for exp in $BAD_EXPS; do
  FILES="$(grep -RIl --binary-files=without-match "$exp" package/dae 2>/dev/null || true)"
  if [ -n "$FILES" ]; then
    echo "Patch: remove token '${exp}' from:"
    echo "$FILES"
    echo "$FILES" | xargs -r sed -i \
      -e "s/${exp},//g" \
      -e "s/,${exp}//g" \
      -e "s/${exp}//g"
  fi
done

echo "[4/7] Fix geodata dependencies (daed-geoip -> v2ray-geoip)"
# luci-app-daed 依赖 daed-geoip/daed-geosite，但 ImmortalWrt 里叫 v2ray-geoip/v2ray-geosite
find package/dae -type f \( -name "Makefile" -o -name "*.mk" \) -exec sed -i \
  -e 's/daed-geoip/v2ray-geoip/g' \
  -e 's/daed-geosite/v2ray-geosite/g' {} \;

echo "Geodata dependencies after patch:"
grep -r "geoip\|geosite" package/dae --include="Makefile" | head -10 || echo "No geodata deps found"

echo "[5/7] Clean daed build artifacts (reduce cache interference)"
make package/dae/daed/clean V=s >/dev/null 2>&1 || true
rm -rf build_dir/target-*/daed-* 2>/dev/null || true
rm -rf tmp/go-build 2>/dev/null || true

echo "[6/7] Verify patches applied"
echo "--- GOEXPERIMENT in package/dae ---"
grep -r "GOEXPERIMENT" package/dae --include="Makefile" | head -5 || echo "None"
echo "--- GOEXPERIMENT in feeds ---"
grep -r "GOEXPERIMENT" feeds/packages/lang/golang --include="*.mk" | head -5 || echo "None"

echo "[7/7] daed patches complete"

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
