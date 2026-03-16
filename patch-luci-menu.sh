#!/bin/bash
set -e
set -o pipefail

echo "Patching LuCI menus..."

python3 - <<'PY'
import json
from pathlib import Path

def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))

def save_json(path: Path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

# 1. 精确修改 luci-mod-status 菜单
status_targets = {
    "admin/status/overview",
    "admin/status/realtime",
    "admin/status/realtime/load",
    "admin/status/realtime/bandwidth",
    "admin/status/realtime/wireless",
    "admin/status/realtime/connections",
}

for p in Path(".").rglob("luci-mod-status.json"):
    s = str(p).replace("\\", "/")
    if not s.endswith("/luci-mod-status/root/usr/share/luci/menu.d/luci-mod-status.json"):
        continue

    data = load_json(p)
    new_data = {k: v for k, v in data.items() if k not in status_targets}

    if new_data != data:
        save_json(p, new_data)
        print(f"patched status menu: {p}")

# 2. 把 bandix 从 网络 挪到 状态
for p in Path(".").rglob("luci-app-bandix.json"):
    s = str(p).replace("\\", "/")
    if not s.endswith("/luci-app-bandix/root/usr/share/luci/menu.d/luci-app-bandix.json"):
        continue

    data = load_json(p)
    changed = False
    new_data = {}

    for k, v in data.items():
        nk = k
        if k.startswith("admin/network/bandix"):
            nk = "admin/status/bandix" + k[len("admin/network/bandix"):]
            changed = True

        if isinstance(v, dict):
            action = v.get("action")
            if isinstance(action, dict):
                pathv = action.get("path")
                if isinstance(pathv, list) and len(pathv) >= 2:
                    if pathv[0] == "admin" and pathv[1] == "network":
                        pathv[1] = "status"
                        changed = True

        new_data[nk] = v

    if changed:
        save_json(p, new_data)
        print(f"patched bandix menu: {p}")

PY

# 3. 删除 realtime 视图文件，避免直接访问
find . -path '*/luci-mod-status/htdocs/luci-static/resources/view/status/load.js' -delete
find . -path '*/luci-mod-status/htdocs/luci-static/resources/view/status/bandwidth.js' -delete
find . -path '*/luci-mod-status/htdocs/luci-static/resources/view/status/wireless.js' -delete
find . -path '*/luci-mod-status/htdocs/luci-static/resources/view/status/connections.js' -delete

echo "LuCI menu patch done."