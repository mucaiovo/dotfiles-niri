#!/usr/bin/env bash
#
# Niri + DankMaterialShell —— 自包含部署脚本
# 不需要 shorin-dms-niri-git，本仓库自带全部配置。
#
# 用法:
#   ./install.sh              完整部署（装包 + 铺配置 + 系统设置）
#   ./install.sh --no-packages   跳过软件安装，只铺配置
#   ./install.sh --no-system     跳过系统级改动（locale/i2c 等）
#   ./install.sh --dry-run       只显示将要做什么，不实际改动
#
# 层叠顺序: dotfiles-shorin/ (底座) → dotfiles-user/ (个人改动覆盖)
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$REPO_DIR/dotfiles-shorin"
USER_DIR="$REPO_DIR/dotfiles-user"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%F-%H%M%S)"

DO_PACKAGES=1
DO_SYSTEM=1
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --no-packages) DO_PACKAGES=0 ;;
        --no-system)   DO_SYSTEM=0 ;;
        --dry-run)     DRY_RUN=1 ;;
        -h|--help)     sed -n '2,16p' "$0" | sed 's/^# \?//'; exit 0 ;;
        *) echo "未知参数: $arg" >&2; exit 2 ;;
    esac
done

c_red=$'\033[31m'; c_grn=$'\033[32m'; c_yel=$'\033[33m'; c_dim=$'\033[2m'; c_rst=$'\033[0m'
info() { printf '%s==>%s %s\n' "$c_grn" "$c_rst" "$*"; }
warn() { printf '%s[!]%s %s\n' "$c_yel" "$c_rst" "$*"; }
die()  { printf '%s[x]%s %s\n' "$c_red" "$c_rst" "$*" >&2; exit 1; }
run()  { if [ "$DRY_RUN" -eq 1 ]; then printf '%s    [dry-run]%s %s\n' "$c_dim" "$c_rst" "$*"; else "$@"; fi; }

[ "$(id -u)" -eq 0 ] && die "请不要用 root 运行。"
[ -d "$BASE_DIR" ] || die "缺少底座目录 $BASE_DIR"
[ -d "$USER_DIR" ] || die "缺少用户层目录 $USER_DIR"
[ "$DRY_RUN" -eq 1 ] && warn "DRY-RUN 模式：只显示操作，不实际改动"

# ---------------------------------------------------------------- 软件清单
CORE_PACKAGES=(
    niri dms-shell quickshell-git niri-sidebar-git
    matugen kitty fuzzel cava btop fastfetch starship
    satty slurp grim wf-recorder
    xdg-desktop-portal-gnome xdg-desktop-portal-gtk
    adw-gtk-theme breeze-cursors
    noto-fonts noto-fonts-cjk noto-fonts-emoji
    fcitx5 fcitx5-gtk fcitx5-qt fcitx5-configtool fcitx5-rime
    fish starship zoxide eza bat jq
    ttf-jetbrains-mono-nerd
    gnome-keyring polkit-gnome
)

# ---------------------------------------------------------------- 1. 环境
info "1/6 检查环境"
command -v pacman >/dev/null 2>&1 || warn "未检测到 pacman，本脚本针对 Arch 系发行版。"

AUR=""
if command -v paru >/dev/null 2>&1; then AUR=paru
elif command -v yay >/dev/null 2>&1; then AUR=yay
fi
[ -n "$AUR" ] && echo "  AUR 助手: $AUR" || warn "未找到 paru/yay，AUR 包需你手动安装。"

# ---------------------------------------------------------------- 2. 装包
if [ "$DO_PACKAGES" -eq 1 ]; then
    info "2/6 安装软件"
    if command -v pacman >/dev/null 2>&1; then
        missing=()
        for p in "${CORE_PACKAGES[@]}"; do
            pacman -Qq "$p" >/dev/null 2>&1 || missing+=("$p")
        done
        if [ ${#missing[@]} -eq 0 ]; then
            echo "  依赖已齐全"
        else
            echo "  缺少 ${#missing[@]} 个包: ${missing[*]}"
            run sudo pacman -S --needed --noconfirm "${missing[@]}" || warn "部分包安装失败，请手动检查。"
        fi
    else
        warn "跳过（非 pacman 系统），请自行安装清单中的包。"
    fi
else
    info "2/6 跳过软件安装 (--no-packages)"
fi

# ---------------------------------------------------------------- 3. 原始包处置
info "3/6 检查 shorin-dms-niri-git"
if pacman -Qq shorin-dms-niri-git >/dev/null 2>&1; then
    warn "检测到 shorin-dms-niri-git。它的配置从此不再生效（本仓库已接管）。"
    echo "  以下 shorin 专属工具不依赖它，建议保留:"
    echo "    shorin-contrib-git          ~/.local/bin 里的 sysup/clean/mirror-update 等"
    echo "    shorin-screenrec-menu-git   niri 的 Mod+F3 录屏菜单"
    echo "  确认配置已生效后，可手动移除主包:"
    echo "    sudo pacman -Rns shorin-dms-niri-git"
    echo "  注意: 移除前先确认 ~/.local/bin 里的软链仍可用。"
else
    echo "  未安装（已经是自包含状态）"
fi

# ---------------------------------------------------------------- 4. 系统级
if [ "$DO_SYSTEM" -eq 1 ]; then
    info "4/6 系统级设置"
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "    [dry-run] locale.gen / i2c 组 / i2c-dev 模块"
    else
        # locale
        need_gen=0
        locale -a 2>/dev/null | grep -qi "en_US.utf8" || { sudo sed -i 's/^#\s*en_US\.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen; need_gen=1; }
        locale -a 2>/dev/null | grep -qi "zh_CN.utf8" || { sudo sed -i 's/^#\s*zh_CN\.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen; need_gen=1; }
        [ "$need_gen" -eq 1 ] && { sudo locale-gen >/dev/null 2>&1 && echo "  已生成 locales"; } || echo "  locales 已就绪"

        # i2c（外接显示器亮度控制需要）
        if ! id -nG "$USER" | tr ' ' '\n' | grep -qx i2c; then
            sudo gpasswd -a "$USER" i2c >/dev/null 2>&1 && echo "  已将 $USER 加入 i2c 组（需重新登录生效）"
        else
            echo "  已在 i2c 组"
        fi
        if ! grep -q "i2c-dev" /etc/modules-load.d/i2c-dev.conf 2>/dev/null; then
            echo "i2c-dev" | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null
            echo "  已添加 i2c-dev 模块"
        fi

        # 电源管理：TLP 与 power-profiles-daemon 互斥，绝不盲目开启
        if pacman -Qq tlp >/dev/null 2>&1; then
            warn "检测到 TLP，跳过 power-profiles-daemon（两者互斥，同时启用会导致电源策略打架）"
            systemctl is-enabled power-profiles-daemon >/dev/null 2>&1 && \
                warn "  注意: power-profiles-daemon 当前是 enabled，建议 sudo systemctl mask power-profiles-daemon"
        else
            sudo systemctl enable --now power-profiles-daemon.service >/dev/null 2>&1 && \
                echo "  已启用 power-profiles-daemon" || warn "  power-profiles-daemon 启用失败（可能未安装）"
        fi
    fi
else
    info "4/6 跳过系统级设置 (--no-system)"
fi

# ---------------------------------------------------------------- 5. 铺配置
info "5/6 部署配置"
MANIFEST="$(mktemp)"; UNIQUE_FILE="$(mktemp)"
trap 'rm -f "$MANIFEST" "$UNIQUE_FILE"' EXIT

if git -C "$REPO_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$REPO_DIR" ls-files dotfiles-shorin dotfiles-user >"$MANIFEST"
    echo "  清单来源: git 索引"
else
    (cd "$REPO_DIR" && find dotfiles-shorin dotfiles-user -type f | sort) >"$MANIFEST"
    echo "  清单来源: 目录遍历（ZIP 模式）"
fi
[ -s "$MANIFEST" ] || die "文件清单为空。"

backup_count=0; write_count=0

while IFS= read -r tracked; do
    case "$tracked" in
        dotfiles-shorin/*) rel="${tracked#dotfiles-shorin/}" ;;
        dotfiles-user/*)   rel="${tracked#dotfiles-user/}" ;;
        *) continue ;;
    esac
    src="$REPO_DIR/$tracked"
    dst="$HOME/$rel"
    [ -e "$src" ] || continue

    # 备份已存在的实体文件（软链不备份，直接替换）
    if { [ -e "$dst" ] || [ -L "$dst" ]; } && [ ! -L "$dst" ]; then
        mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
        cp -a "$dst" "$BACKUP_DIR/$rel"
        backup_count=$((backup_count + 1))
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        printf '%s\n' "$rel" >>"$UNIQUE_FILE"
        write_count=$((write_count + 1)); continue
    fi

    mkdir -p "$(dirname "$dst")"
    rm -f "$dst"
    cp -a "$src" "$dst"

    # 底座里的 /home/shorin 占位符换成真实家目录
    if [ "${tracked#dotfiles-shorin/}" != "$tracked" ] && grep -q "/home/shorin" "$dst" 2>/dev/null; then
        sed -i "s|/home/shorin|$HOME|g" "$dst"
    fi
    printf '%s\n' "$rel" >>"$UNIQUE_FILE"
    write_count=$((write_count + 1))
done <"$MANIFEST"

final_count=$(sort -u "$UNIQUE_FILE" | wc -l)
echo "  部署 $final_count 个配置（写入 $write_count 次，用户层覆盖底座层 $((write_count - final_count)) 处）"
[ "$DRY_RUN" -eq 1 ] || { [ "$backup_count" -gt 0 ] && echo "  备份 $backup_count 个原有文件到: $BACKUP_DIR"; }

# ---------------------------------------------------------------- 6. 收尾
info "6/6 收尾"
if [ "$DRY_RUN" -eq 0 ]; then
    # 脚本可执行位
    for d in "$HOME/.config/niri/scripts" "$HOME/.local/bin"; do
        [ -d "$d" ] && find "$d" -maxdepth 1 -type f -exec chmod +x {} \; 2>/dev/null || true
    done

    # 机器特定：背光设备
    SETTINGS="$HOME/.config/DankMaterialShell/settings.json"
    if [ -f "$SETTINGS" ] && command -v python3 >/dev/null 2>&1; then
        real_bl="$(basename "$(ls -d /sys/class/backlight/* 2>/dev/null | head -1)" 2>/dev/null || true)"
        [ -n "$real_bl" ] && python3 - "$SETTINGS" "$real_bl" <<'PY'
import json, sys, pathlib
p, dev = pathlib.Path(sys.argv[1]), sys.argv[2]
try: d = json.loads(p.read_text())
except Exception: raise SystemExit(0)
for w in d.get("controlCenterWidgets", []):
    if w.get("id") == "brightnessSlider" and not w.get("deviceName"):
        w["deviceName"] = f"backlight:{dev}"
p.write_text(json.dumps(d, indent=2, ensure_ascii=False) + "\n")
print(f"  背光设备设为 backlight:{dev}")
PY
    fi
fi

cat <<EOF

$(printf '%s' "$c_grn")部署完成。$(printf '%s' "$c_rst")

首次登录后还需手动做三件事（壁纸与配色按机器生成，无法预置）:
  1. 注销后重新登录（i2c 组变更也需重登生效）
  2. DMS 设置 → 个性化 → 壁纸，选一张壁纸
  3. DMS 设置 → 主题与配色 → 选 "auto" 并挑配色
     这步会生成 ~/.config/niri/dms/colors.kdl 与 wpblur.kdl

可选:
  * Firefox 配色: 扩展页装 pywalfox → Fetch
  * VSCode 配色: 装 DMS 主题扩展，主题选 DankShell
  * 隐藏冗余 .desktop 图标: 见 README 的"可选系统微调"

回滚: 把 $BACKUP_DIR 内容按相同路径拷回 \$HOME
EOF
