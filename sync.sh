#!/usr/bin/env bash
#
# sync.sh —— 把本机当前配置同步回仓库
#
# 用法:
#   ./sync.sh           显示将要发生的更改，不实际写入
#   ./sync.sh --apply   实际同步，然后由你手动 commit
#
# 说明:
#   本脚本刻意使用「拷贝」而非「软链」。因为 shorindms update 落盘时可能
#   打断软链，导致你的真实配置被替换成断链。拷贝同步没有这个风险。
#
# 特例:
#   DankMaterialShell/settings.json 里的背光设备名是本机专属值，
#   同步时会自动清空，交给 install.sh 在新机器上探测回填。
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$REPO_DIR/dotfiles"
APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

c_grn=$'\033[32m'; c_yel=$'\033[33m'; c_dim=$'\033[2m'; c_rst=$'\033[0m'

# 以仓库跟踪的文件为准，新文件需先 git add 才会被纳入
changed=0
while IFS= read -r tracked; do
    rel="${tracked#dotfiles/}"
    src="$HOME/$rel"
    dst="$SRC_DIR/$rel"

    if [ ! -e "$src" ]; then
        printf '%s[缺失]%s 本机没有: %s\n' "$c_yel" "$c_rst" "$rel"
        continue
    fi

    if [ -L "$src" ]; then
        printf '%s[软链]%s 跳过（本机该文件是软链，同步会自指）: %s\n' "$c_yel" "$c_rst" "$rel"
        continue
    fi

    if [ ! -e "$dst" ]; then
        printf '%s[新增]%s %s\n' "$c_grn" "$c_rst" "$rel"
        changed=$((changed + 1))
        [ "$APPLY" -eq 1 ] && { mkdir -p "$(dirname "$dst")"; cp -a "$src" "$dst"; }
        continue
    fi

    if cmp -s "$src" "$dst"; then
        continue
    fi

    # settings.json 里的背光设备名是本机专属，仓库恒为空。
    # 这里按「归一化后」比较，避免每次都误报有变更。
    if [ "$rel" = ".config/DankMaterialShell/settings.json" ] && command -v python3 >/dev/null 2>&1; then
        if python3 - "$src" "$dst" <<'PY'
import json, sys, pathlib
s, d = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
def norm(p):
    data = json.loads(p.read_text())
    for w in data.get("controlCenterWidgets", []):
        if w.get("id") == "brightnessSlider":
            w["deviceName"] = ""
    return json.dumps(data, indent=2, ensure_ascii=False, sort_keys=True)
raise SystemExit(0 if norm(s) == norm(d) else 1)
PY
        then
            continue
        fi
    fi

    printf '%s[更新]%s %s\n' "$c_grn" "$c_rst" "$rel"

    if [ "$APPLY" -eq 1 ]; then
        diff -u "$dst" "$src" | head -40 | sed "s/^/$c_dim    /" || true
        printf '%s' "$c_rst"

        if [ "$rel" = ".config/DankMaterialShell/settings.json" ]; then
            # 背光设备名是本机专属，仓库里必须留空，由 install.sh 在
            # 新机器上探测回填。直接拷贝会把本机设备名固化进仓库，
            # 导致别的机器上亮度滑块失效。
            python3 - "$src" "$dst" <<'PY'
import json, sys, pathlib
s, d = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
data = json.loads(s.read_text())
for w in data.get("controlCenterWidgets", []):
    if w.get("id") == "brightnessSlider":
        w["deviceName"] = ""
d.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
print("    (已清空机器特定背光设备名)")
PY
        else
            cp -a "$src" "$dst"
        fi
    fi
    changed=$((changed + 1))
done < <(git -C "$REPO_DIR" ls-files dotfiles)

echo
if [ "$changed" -eq 0 ]; then
    echo "无变更，仓库已是最新。"
    exit 0
fi

if [ "$APPLY" -eq 0 ]; then
    echo "共 $changed 个文件有差异。加 --apply 实际同步。"
else
    echo "已同步 $changed 个文件。"
    echo
    echo "接下来手动提交（脚本不替你 commit，方便你先审阅）:"
    echo "  cd $REPO_DIR"
    echo "  git diff"
    echo "  git add -A && git commit -m '更新配置' && git push"
fi
