#!/usr/bin/env bash
#
# Niri + DankMaterialShell (Shorin-DMS) dotfiles 复原脚本
# 用法:  ./install.sh
#
# 设计要点:
#   * 文件清单来自 `git ls-files`，仓库没有的文件脚本不会碰
#   * 每个文件独立软链，覆盖前先备份
#   * 机器特定值（背光设备名）自动修正为本机实际值
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$REPO_DIR/dotfiles"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%F-%H%M%S)"
DISTRO_PKG="shorin-dms-niri-git"

c_red=$'\033[31m'; c_grn=$'\033[32m'; c_yel=$'\033[33m'; c_dim=$'\033[2m'; c_rst=$'\033[0m'
info() { printf '%s==>%s %s\n' "$c_grn" "$c_rst" "$*"; }
warn() { printf '%s[!]%s %s\n' "$c_yel" "$c_rst" "$*"; }
die()  { printf '%s[x]%s %s\n' "$c_red" "$c_rst" "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] && die "请不要用 root 运行，脚本会写入 \$HOME。"
[ -d "$SRC_DIR" ] || die "找不到 $SRC_DIR"

# ---------------------------------------------------------------- 1. 前置检查
info "1/6 检查运行环境"

if [ ! -d /sys/firmware/efi ]; then
    warn "当前不是 UEFI 启动，Niri 仍可用，但请确认引导方式。"
fi

if ! command -v git >/dev/null 2>&1; then
    die "缺少 git，请先安装：sudo pacman -S git"
fi

if ! command -v pacman >/dev/null 2>&1; then
    warn "未检测到 pacman，本脚本针对 Arch 系发行版；其他发行版请手动安装依赖。"
fi

echo -n "  AUR 助手: "
if command -v paru >/dev/null 2>&1; then AUR=paru
elif command -v yay >/dev/null 2>&1;  then AUR=yay
else AUR=""; warn "未找到 paru/yay，稍后需要你手动安装 $DISTRO_PKG"; fi
[ -n "$AUR" ] && echo "$AUR"

# ---------------------------------------------------------------- 2. 组件
info "2/6 检查 Shorin-DMS 套件"

if pacman -Qq "$DISTRO_PKG" >/dev/null 2>&1; then
    echo "  $DISTRO_PKG 已安装"
else
    warn "未安装 $DISTRO_PKG —— 本仓库只是你个人改动的增量，本体由该包提供。"
    if [ -n "$AUR" ]; then
        read -r -p "  现在用 $AUR 安装? [y/N] " a
        if [[ "$a" =~ ^[Yy]$ ]]; then
            "$AUR" -S --needed "$DISTRO_PKG"
        else
            die "请先安装 $DISTRO_PKG 后再运行本脚本。"
        fi
    else
        die "请先安装 $DISTRO_PKG 后再运行本脚本。"
    fi
fi

if command -v shorindms >/dev/null 2>&1; then
    if [ ! -d "$HOME/.config/niri" ]; then
        info "  首次运行: 执行 shorindms init 铺开基础配置"
        warn "  该步骤会覆盖家目录文件（它自己会备份到 ~/.cache），继续前请确认。"
        read -r -p "  执行 shorindms init? [y/N] " a
        [[ "$a" =~ ^[Yy]$ ]] && shorindms init || die "已取消。请先 init 再运行本脚本。"
    else
        echo "  ~/.config/niri 已存在，跳过 init"
    fi
fi

# ---------------------------------------------------------------- 3. 备份
info "3/6 备份将被覆盖的文件到 $BACKUP_DIR"

MANIFEST="$(mktemp)"
trap 'rm -f "$MANIFEST"' EXIT

# 以 git 索引为唯一事实来源
git -C "$REPO_DIR" ls-files dotfiles >"$MANIFEST" || die "git ls-files 失败"

backup_count=0
while IFS= read -r tracked; do
    rel="${tracked#dotfiles/}"
    dst="$HOME/$rel"
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
        cp -a "$dst" "$BACKUP_DIR/$rel"
        backup_count=$((backup_count + 1))
    fi
done <"$MANIFEST"
echo "  已备份 $backup_count 个现存文件"

# ---------------------------------------------------------------- 4. 软链
info "4/6 链接配置文件"

link_count=0
while IFS= read -r tracked; do
    rel="${tracked#dotfiles/}"
    src="$SRC_DIR/$rel"
    dst="$HOME/$rel"

    [ -e "$src" ] || { warn "源文件缺失，跳过: $rel"; continue; }

    mkdir -p "$(dirname "$dst")"

    if [ -L "$dst" ]; then
        rm -f "$dst"
    elif [ -e "$dst" ]; then
        if cmp -s "$src" "$dst"; then
            rm -f "$dst"                     # 内容相同，直接换成软链
        else
            rm -f "$dst"                      # 已在上一步备份
        fi
    fi

    ln -s "$src" "$dst"
    link_count=$((link_count + 1))
done <"$MANIFEST"

echo "  已链接 $link_count 个文件"

# ---------------------------------------------------------------- 5. 机器特定修正
info "5/6 修正机器特定配置"

SETTINGS="$HOME/.config/DankMaterialShell/settings.json"
if [ -f "$SETTINGS" ] && command -v python3 >/dev/null 2>&1; then
    # 把 settings.json 里留空的背光设备替换为本机真实设备
    real_bl="$(basename "$(ls -d /sys/class/backlight/* 2>/dev/null | head -1)" 2>/dev/null || true)"
    if [ -n "$real_bl" ]; then
        python3 - "$SETTINGS" "$real_bl" <<'PY'
import json, sys, pathlib
p, dev = pathlib.Path(sys.argv[1]), sys.argv[2]
try:
    d = json.loads(p.read_text())
except Exception as e:
    print(f"  settings.json 解析失败，跳过: {e}"); raise SystemExit(0)
changed = 0
for w in d.get("controlCenterWidgets", []):
    if w.get("id") == "brightnessSlider" and not w.get("deviceName"):
        w["deviceName"] = f"backlight:{dev}"
        changed += 1
p.write_text(json.dumps(d, indent=2, ensure_ascii=False) + "\n")
print(f"  背光设备设为 backlight:{dev} ({changed} 处)")
PY
    else
        warn "  未找到 /sys/class/backlight/*，亮度滑块需在 DMS 设置里手动选一次。"
    fi
else
    warn "  跳过（缺 python3 或配置文件）"
fi

# 可执行位（git 可能未保留，显式补一次）
for f in "$HOME"/.config/niri/scripts/*; do
    [ -f "$f" ] && chmod +x "$f" 2>/dev/null || true
done
echo "  已恢复脚本可执行权限"

# ---------------------------------------------------------------- 6. 收尾
info "6/6 完成"

cat <<EOF

$(printf '%s' "$c_grn")配置文件已就位。$(printf '%s' "$c_rst")

还需要手动做三件事（DMS 的壁纸与配色是按机器生成的，无法随仓库携带）:

  1. 注销后重新登录（或重启），让 Niri 读取新配置。
  2. 打开 DMS 设置 → 个性化 → 壁纸，选一张壁纸。
     这会同时生成 overview 模糊壁纸层。
  3. DMS 设置 → 主题与配色 → 选 "auto" 再挑一个配色方案。
     这一步会重新生成 ~/.config/niri/dms/colors.kdl 与 wpblur.kdl。

可选项:
  * Firefox 配色: 打开 Firefox → pywalfox 扩展 → Fetch。
  * VSCode 配色: 安装 DMS 主题扩展，主题选 DankShell。

备份位置: $BACKUP_DIR
回滚办法: 把该目录内容按相同路径拷回 \$HOME 即可。
EOF
