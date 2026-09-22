# FF-120 指定 daede 软件源

2026-09-23：官方 packages 与自定义 immortalwrt feed 存在同名 dae/daed，统一 install -a 会选前者。

修复先卸载 dae、daed、luci-app-daede 的 feed 链接，再从 immortalwrt 指定安装。`-f` 本身只处理 core override，不能省略卸载。下载前检查唯一链接实际指向 `feeds/immortalwrt/openwrt-daede` 且三个包都选为 y；编译后检查全部 manifest 中版本等于 Makefile 的 PKG_VERSION-rPKG_RELEASE，校验失败不能进入上传/发布。

验证：`python3 scripts/test-daede-feed.py`。夹具包含成功、错版本、缺 manifest、包未内置、错误链接；独立静态审查已复核 uninstall/install 的 v24.10.6 feeds 实现。尚未真实编译。

使用：先合并 openwrt-daede 的 FF-120 插件修复（LuCI 1.15-r10），同步 ImmortalWrt-Packages 后再运行本仓构建。门禁检查的是构建实际使用的 feed，不会自动同步未合并的插件代码。

回退：Git revert 此次提交。测试临时目录自动清理；无需手工文件备份，已有 Git 基线 fc97ba4。此改动不直接刷写路由器。
