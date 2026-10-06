#!/usr/bin/env bash
#
# sync.sh —— 把本机当前配置同步回仓库的【用户层】
#
# 用法:
#   ./sync.sh           显示将要发生的更改，不实际写入
#   ./sync.sh --apply   实际同步，然后由你手动 commit
#
# 两层结构:
#   dotfiles-shorin/  底座，从 shorin 包 vendoring 而来，本脚本【只读不写】
#   dotfiles-user/    你的个人改动，本脚本只同步这一层
#
# 说明:
#   本脚本刻意使用「拷贝」而非「软链」，避免上游工具落盘时打断软链。
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_DIR="$REPO_DIR/dotfiles-user"
APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

c_grn=$'\033[32m'; c_yel=$'\033[33m'; c_dim=$'\033[2m'; c_rst=$'\033[0m'

if ! git -C "$REPO_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    printf '%s[x]%s 这不是一个 git 仓库（可能来自 ZIP 下载）。\n' "$c_yel" "$c_rst" >&2
    echo "    sync.sh 用于把本机改动回传到仓库，需要 git 历史。" >&2
    echo "    若只想应用配置，请改用: ./install.sh" >&2
    exit 1
fi

[ -d "$USER_DIR" ] || { echo "缺少 $USER_DIR" >&2; exit 1; }

# 只以用户层已跟踪的文件为准
changed=0
while IFS= read -r tracked; do
    rel="${tracked#dotfiles-user/}"
    src="$HOME/$rel"
    dst="$USER_DIR/$rel"

    if [ ! -e "$src" ]; then
        printf '%s[缺失]%s 本机没有: %s\n' "$c_yel" "$c_rst" "$rel"
        continue
    fi

    if [ -L "$src" ]; then
        printf '%s[软链]%s 跳过（本机该文件是软链）: %s\n' "$c_yel" "$c_rst" "$rel"
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

    # settings.json 的背光设备名是本机专属，仓库恒为空，
    # 按归一化内容比较，避免每次误报。
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
done < <(git -C "$REPO_DIR" ls-files dotfiles-user)

echo
if [ "$changed" -eq 0 ]; then
    echo "无变更，用户层已是最新。"
    exit 0
fi

if [ "$APPLY" -eq 0 ]; then
    echo "共 $changed 个文件有差异。加 --apply 实际同步。"
else
    cat <<EOF
已同步 $changed 个文件到 dotfiles-user/。

接下来手动提交:
  cd $REPO_DIR
  git diff
  git add -A && git commit -m '更新配置' && git push

提示: 若你改动的是底座文件（dotfiles-shorin/），sync.sh 不会同步它。
      把该文件复制到 dotfiles-user/ 同路径即可变成你的个人覆盖层。
EOF
fi
