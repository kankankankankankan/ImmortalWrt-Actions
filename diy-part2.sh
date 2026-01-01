#!/bin/bash

# ==== FakeHTTP 二进制下载 + 安装到固件 ====

# 1️⃣ 创建文件目录
mkdir -p files/usr/bin
mkdir -p files/etc/init.d
mkdir -p files/etc/uci-defaults

# ==========================
# 2️⃣ 下载 FakeHTTP 二进制并放入固件
# ==========================
echo "Downloading FakeHTTP binary..."
curl -L https://github.com/MikeWang000000/FakeHTTP/releases/latest/download/fakehttp-linux-x86_64.tar.gz -o fakehttp.tar.gz

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
    procd_set_param command fakehttp -d -a -e creator.douyin.com -e vd3.bdstatic.com -e p3-pc-sign.douyinpic.com -e i0.hdslb.com -e cn-sxxa-cm-01-12.bilivideo.com -e cn-sxxa-cm-01-04.bilivideo.com -e cn-sxxa-ct-03-03.bilivideo.com -e cn-sxxa-cu-02-01.bilivideo.com -e www.speedtest.cn -e pan.quark.cn -e www.123pan.com -e onedrive.live.com -e www.alipan.com -e dlcv2.cnspeedtest.cn -e yun.139.com -e ykj-eos-wx2-01.eos-wuxi-3.cmecloud.cn -e test.ustc.edu.cn -h yun.139.com -e ykj-eos-dg5-01.eos-dongguan-6.cmec
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
