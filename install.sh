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

# ---------------------------------------------------------------- 发行版检测
DISTRO_ID=""; DISTRO_LIKE=""; DISTRO_NAME="未知"; PKG_FAMILY="unknown"
if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    DISTRO_ID="${ID:-}"; DISTRO_LIKE="${ID_LIKE:-}"; DISTRO_NAME="${PRETTY_NAME:-$ID}"
fi
case " $DISTRO_ID $DISTRO_LIKE " in
    *" arch "*)   PKG_FAMILY="arch" ;;
    *" debian "*|*" ubuntu "*) PKG_FAMILY="debian" ;;
    *" fedora "*|*" rhel "*)   PKG_FAMILY="fedora" ;;
    *" opensuse "*|*" suse "*) PKG_FAMILY="suse" ;;
esac
# 允许显式覆盖（异常系统 / 测试用）: DOTFILES_PKG_FAMILY=debian ./install.sh
case "${DOTFILES_PKG_FAMILY:-}" in
    arch|debian|fedora|suse)
        PKG_FAMILY="$DOTFILES_PKG_FAMILY"
        case "$DOTFILES_PKG_FAMILY" in
            arch)   DISTRO_NAME="$DISTRO_NAME (按 Arch 处理)" ;;
            debian) DISTRO_NAME="$DISTRO_NAME (按 Debian 处理)" ;;
            fedora) DISTRO_NAME="$DISTRO_NAME (按 Fedora 处理)" ;;
            suse)   DISTRO_NAME="$DISTRO_NAME (按 openSUSE 处理)" ;;
        esac
        ;;
esac

# 兜底：按可用命令判断
if [ "$PKG_FAMILY" = "unknown" ]; then
    if command -v pacman >/dev/null 2>&1; then PKG_FAMILY="arch"
    elif command -v apt    >/dev/null 2>&1; then PKG_FAMILY="debian"
    elif command -v dnf    >/dev/null 2>&1; then PKG_FAMILY="fedora"
    elif command -v zypper >/dev/null 2>&1; then PKG_FAMILY="suse"
    fi
fi

# 各发行版下的包名映射（Arch 名 → Debian/Fedora 名）
#   __SKIP__  = 该发行版无对应包，不尝试安装
#   __OBS__   = 由上一步提示的第三方仓库提供
#   __CHECK__ = 包名不确定，安装后会报错并提示你手动确认
debian_pkg() {
    case "$1" in
        dms-shell)                  echo "dms" ;;
        dms-greeter)                echo "dms-greeter" ;;
        quickshell-git)             echo "__OBS__" ;;
        niri-sidebar-git)           echo "__SKIP__" ;;
        niri)                       echo "__CHECK__" ;;   # Debian 13 无官方包，需编译
        matugen)                    echo "matugen" ;;
        adw-gtk-theme)              echo "adw-gtk3" ;;
        breeze-cursors)             echo "breeze-cursor-theme" ;;
        noto-fonts)                 echo "fonts-noto-core" ;;
        noto-fonts-cjk)             echo "fonts-noto-cjk" ;;
        noto-fonts-emoji)           echo "fonts-noto-color-emoji" ;;
        polkit-gnome)               echo "policykit-1-gnome" ;;
        satty)                      echo "__CHECK__" ;;
        slurp)                      echo "slurp" ;;
        grim)                       echo "grim" ;;
        wf-recorder)                echo "wf-recorder" ;;
        ttf-jetbrains-mono-nerd)    echo "fonts-jetbrains-mono" ;;
        eza)                        echo "__CHECK__" ;;   # Debian 仓库无 eza
        starship)                   echo "starship" ;;
        zoxide)                     echo "zoxide" ;;
        *)                          echo "$1" ;;
    esac
}
fedora_pkg() {
    case "$1" in
        dms-shell)                  echo "dms" ;;
        dms-greeter)                echo "dms-greeter" ;;
        quickshell-git)             echo "quickshell" ;;   # COPR 提供
        niri-sidebar-git)           echo "__SKIP__" ;;
        niri)                       echo "niri" ;;         # pgdev/niri COPR
        adw-gtk-theme)              echo "adw-gtk3-theme" ;;
        breeze-cursors)             echo "breeze-cursor-theme" ;;
        noto-fonts)                 echo "google-noto-sans-fonts" ;;
        noto-fonts-cjk)             echo "google-noto-sans-cjk-fonts" ;;
        noto-fonts-emoji)           echo "google-noto-emoji-fonts" ;;
        polkit-gnome)               echo "polkit-gnome" ;;
        satty)                      echo "satty" ;;
        slurp)                      echo "slurp" ;;
        grim)                       echo "grim" ;;
        wf-recorder)                echo "wf-recorder" ;;
        ttf-jetbrains-mono-nerd)    echo "jetbrains-mono-fonts-all" ;;
        starship)                   echo "starship" ;;
        zoxide)                     echo "zoxide" ;;
        eza)                        echo "eza" ;;
        xdg-desktop-portal-gnome)   echo "xdg-desktop-portal-gnome" ;;
        *)                          echo "$1" ;;
    esac
}

suse_pkg() {
    case "$1" in
        dms-shell)                  echo "dms" ;;
        quickshell-git)             echo "__OBS__" ;;
        niri-sidebar-git)           echo "__SKIP__" ;;
        niri)                       echo "niri" ;;
        dms-greeter)                echo "dms-greeter" ;;
        adw-gtk-theme)              echo "adw-gtk3-theme" ;;
        noto-fonts)                 echo "noto-sans-fonts" ;;
        noto-fonts-cjk)             echo "noto-sans-cjk-fonts" ;;
        noto-fonts-emoji)           echo "noto-coloremoji-fonts" ;;
        ttf-jetbrains-mono-nerd)    echo "jetbrains-mono-fonts" ;;
        polkit-gnome)               echo "polkit-gnome" ;;
        *)                          echo "$1" ;;
    esac
}

pkg_installed() {
    case "$PKG_FAMILY" in
        arch)   pacman -Qq "$1" >/dev/null 2>&1 ;;
        debian) dpkg -s "$1"   >/dev/null 2>&1 ;;
        fedora) rpm -q "$1"    >/dev/null 2>&1 ;;
        suse)   rpm -q "$1"    >/dev/null 2>&1 ;;
        *)      return 1 ;;
    esac
}

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
    # DMS 登录器（Arch 上为 AUR: greetd-dms-greeter-bin）
    greetd dms-greeter
)

# ---------------------------------------------------------------- 1. 环境
info "1/6 检查环境"
echo "  发行版: $DISTRO_NAME"
case "$PKG_FAMILY" in
    arch)   echo "  包管理器: pacman" ;;
    debian) echo "  包管理器: apt" ;;
    fedora) echo "  包管理器: dnf" ;;
    suse)   echo "  包管理器: zypper" ;;
    *)      warn "无法识别的发行版，软件安装需手动完成（配置部署不受影响）" ;;
esac

AUR=""
if [ "$PKG_FAMILY" = "arch" ]; then
    if command -v paru >/dev/null 2>&1; then AUR=paru
    elif command -v yay >/dev/null 2>&1; then AUR=yay
    fi
    [ -n "$AUR" ] && echo "  AUR 助手: $AUR" || warn "未找到 paru/yay，AUR 包需手动安装。"
fi

# ---------------------------------------------------------------- 2. 装包
if [ "$DO_PACKAGES" -eq 1 ]; then
    info "2/6 安装软件"

    # 把 Arch 包名映射成本发行版的包名
    map_pkg() {
        case "$PKG_FAMILY" in
            arch)   echo "$1" ;;
            debian) debian_pkg "$1" ;;
            fedora) fedora_pkg "$1" ;;
            suse)   suse_pkg "$1" ;;
            *)      echo "$1" ;;
        esac
    }

    missing=(); skipped=(); unsure=()
    for p in "${CORE_PACKAGES[@]}"; do
        m="$(map_pkg "$p")"
        if [ "$m" = "__SKIP__" ]; then skipped+=("$p"); continue; fi
        [ "$m" = "__OBS__" ] && { skipped+=("$p (需 DMS 仓库)"); continue; }
        if [ "$m" = "__CHECK__" ]; then unsure+=("$p"); continue; fi
        pkg_installed "$m" || missing+=("$m")
    done

    if [ "$PKG_FAMILY" = "unknown" ]; then
        warn "未知发行版，跳过自动装包。请手动安装以下依赖:"
        printf '    %s\n' "${CORE_PACKAGES[@]}"
    elif [ ${#missing[@]} -eq 0 ]; then
        echo "  依赖已齐全"
    else
        echo "  缺少 ${#missing[@]} 个包"
        case "$PKG_FAMILY" in
            arch)   run sudo pacman -S --needed --noconfirm "${missing[@]}" || warn "部分包安装失败，请手动检查。" ;;
            debian) run sudo apt install -y "${missing[@]}" || warn "部分包安装失败，请手动检查。" ;;
            fedora) run sudo dnf install -y "${missing[@]}" || warn "部分包安装失败，请手动检查。" ;;
            suse)   run sudo zypper install -y "${missing[@]}" || warn "部分包安装失败，请手动检查。" ;;
        esac
    fi

    [ ${#skipped[@]} -gt 0 ] && { warn "以下包需手动处理:"; printf '    %s\n' "${skipped[@]}"; }
    [ ${#unsure[@]} -gt 0 ] && {
        warn "以下包在本发行版无稳定对应包名，未自动安装:"
        printf '    %s\n' "${unsure[@]}"
        echo "    请到本发行版的包索引确认后手动安装（配置部署不受影响）。"
    }

    # 非 Arch 系统需要先加第三方仓库才能拿到 DMS / niri
    if [ "$PKG_FAMILY" = "debian" ]; then
        echo
        echo "  Debian 需先启用 DMS 官方仓库（本脚本不代改 apt 源，请手动执行）:"
        echo "    curl -fsSL https://download.opensuse.org/repositories/home:AvengeMedia:danklinux/Debian_13/Release.key | \\"
        echo "      sudo gpg --dearmor -o /etc/apt/keyrings/danklinux.gpg"
        echo "    echo \"deb [signed-by=/etc/apt/keyrings/danklinux.gpg] https://download.opensuse.org/repositories/home:/AvengeMedia:/danklinux/Debian_13/ /\" | \\"
        echo "      sudo tee /etc/apt/sources.list.d/danklinux.list"
        echo "    sudo apt update && sudo apt install dms"
        echo "    niri 需自行编译: https://github.com/rufex/niri-on-debian"
    elif [ "$PKG_FAMILY" = "suse" ]; then
        echo
        echo "  openSUSE 需先加 DMS 官方仓库（本脚本不代改 zypper 源，请手动执行）:"
        echo "    sudo zypper addrepo https://download.opensuse.org/repositories/home:AvengeMedia:danklinux/openSUSE_Tumbleweed/home:AvengeMedia:danklinux.repo"
        echo "    sudo zypper addrepo https://download.opensuse.org/repositories/home:/AvengeMedia:/dms/openSUSE_Tumbleweed/home:AvengeMedia:dms.repo"
        echo "    sudo zypper refresh && sudo zypper install dms niri"
    elif [ "$PKG_FAMILY" = "fedora" ]; then
        echo
        echo "  Fedora 需先启用 COPR 仓库（本脚本不代改 dnf 源，请手动执行）:"
        echo "    sudo dnf copr enable avengemedia/dms"
        echo "    sudo dnf install dms"
        echo "    niri 可用 COPR: sudo dnf copr enable pgdev/niri && sudo dnf install niri"
    fi
else
    info "2/6 跳过软件安装 (--no-packages)"
fi

# ---------------------------------------------------------------- 3. 原始包处置
info "3/6 检查 shorin-dms-niri-git"
if [ "$PKG_FAMILY" != "arch" ]; then
    echo "  非 Arch 系统，跳过（该包是 AUR 专属，与自包含部署无关）"
elif pkg_installed shorin-dms-niri-git; then
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
        # locale —— 各发行版机制不同
        need_gen=0
        if [ -f /etc/locale.gen ]; then
            # Arch / Debian 用 locale.gen
            locale -a 2>/dev/null | grep -qi "en_US.utf8" || { sudo sed -i 's/^#\s*en_US\.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen; need_gen=1; }
            locale -a 2>/dev/null | grep -qi "zh_CN.utf8" || { sudo sed -i 's/^#\s*zh_CN\.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen; need_gen=1; }
            if [ "$need_gen" -eq 1 ]; then
                if command -v locale-gen >/dev/null 2>&1; then
                    sudo locale-gen >/dev/null 2>&1 && echo "  已生成 locales (locale-gen)"
                elif command -v localedef >/dev/null 2>&1; then
                    sudo localedef -i en_US -f UTF-8 en_US.UTF-8 >/dev/null 2>&1
                    sudo localedef -i zh_CN -f UTF-8 zh_CN.UTF-8 >/dev/null 2>&1
                    echo "  已生成 locales (localedef)"
                else
                    warn "  找不到 locale-gen / localedef，请手动生成 locales"
                fi
            else
                echo "  locales 已就绪"
            fi
        else
            # Fedora 无 /etc/locale.gen
            if command -v localedef >/dev/null 2>&1; then
                locale -a 2>/dev/null | grep -qi "zh_CN.utf8" || {
                    sudo localedef -i zh_CN -f UTF-8 zh_CN.UTF-8 >/dev/null 2>&1 && echo "  已生成 zh_CN.UTF-8"
                }
                locale -a 2>/dev/null | grep -qi "zh_CN.utf8" && echo "  locales 已就绪"
            else
                warn "  未找到 localedef，请手动生成 zh_CN.UTF-8"
            fi
        fi

        # i2c 组（外接显示器亮度控制需要）
        if id -nG "$USER" 2>/dev/null | tr ' ' '\n' | grep -qx i2c; then
            echo "  已在 i2c 组"
        else
            if command -v gpasswd >/dev/null 2>&1; then
                sudo gpasswd -a "$USER" i2c >/dev/null 2>&1 && echo "  已将 $USER 加入 i2c 组（需重新登录生效）"
            elif command -v usermod >/dev/null 2>&1; then
                sudo usermod -aG i2c "$USER" >/dev/null 2>&1 && echo "  已将 $USER 加入 i2c 组（需重新登录生效）"
            else
                warn "  无法自动加入 i2c 组，请手动执行: sudo usermod -aG i2c $USER"
            fi
        fi

        # i2c-dev 模块开机加载
        if grep -q "i2c-dev" /etc/modules-load.d/i2c-dev.conf 2>/dev/null; then
            echo "  i2c-dev 模块已配置"
        else
            sudo mkdir -p /etc/modules-load.d 2>/dev/null || true
            echo "i2c-dev" | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null 2>&1 \
                && echo "  已添加 i2c-dev 模块" \
                || warn "  写入 modules-load.d 失败（Fedora 若无此服务，可改用 /etc/modprobe.d）"
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

# DMS 登录器（dms-greeter 自带 CLI，不手写 /etc/greetd 配置）
echo
echo "  --- DMS 登录器 ---"
if command -v dms-greeter >/dev/null 2>&1; then
    # 判定以 greetd 运行日志里的实际启动命令为准 —— 这是本机最权威、
    # 且非 root 可读的证据。dms-greeter status 依据它自己写的标记文件，
    # 当 /etc/greetd/config.toml 是手工或第三方脚本写的时候会误报 not found，
    # 而登录屏其实是正常工作的。
    if journalctl -u greetd -b --no-pager 2>/dev/null | grep -q "command:.*dms-greeter"; then
        greeter_state="configured"
    elif journalctl -u greetd --no-pager 2>/dev/null | grep -q "command:.*dms-greeter"; then
        greeter_state="configured"
    else
        greeter_state="unknown"
    fi

    case "$greeter_state" in
        configured)
            echo "  ✓ greetd 已指向 dms-greeter（依据运行日志）"
            ;;
        *)
            echo "  ? 无法从日志确认登录器状态，请自行执行 dms-greeter status 查看"
            echo "    若确实未启用: sudo dms-greeter enable"
            ;;
    esac

    # status 的同步健康状况仍值得看，但它的 "config not found" 在上述
    # 情况下是误报，不据此给建议
    if sync_out="$(dms-greeter status 2>/dev/null)"; then
        printf '%s' "$sync_out" | grep -q "Wallpaper Override.*Override file not present" && \
            echo "    ℹ 登录屏壁纸走桌面壁纸回退（可在 DMS 设置 → Greeter 里单独指定）"
    fi

    echo "    同步桌面主题到登录屏: dms-greeter sync"
    echo "    登录器外观在 DMS 设置 → Greeter 里调整（dms-greeter 只读同步结果）"
else
    warn "  未安装 dms-greeter，跳过（壁纸与桌面主题不受影响）"
fi

cat <<EOF

$(printf '%s' "$c_grn")部署完成。$(printf '%s' "$c_rst")

首次登录后还需手动做三件事（壁纸与配色按机器生成，无法预置）:
  1. 注销后重新登录（i2c 组变更也需重登生效）
  2. DMS 设置 → 个性化 → 壁纸，选一张壁纸
  3. DMS 设置 → 主题与配色 → 选 "auto" 并挑配色
     这步会生成 ~/.config/niri/dms/colors.kdl 与 wpblur.kdl
  4. 若用 DMS 登录器: 装完壁纸后执行 dms-greeter sync，把主题同步到登录屏
     登录器自身的外观在 DMS 设置 → Greeter 里调整

可选:
  * Firefox 配色: 扩展页装 pywalfox → Fetch
  * VSCode 配色: 装 DMS 主题扩展，主题选 DankShell
  * 隐藏冗余 .desktop 图标: 见 README 的"可选系统微调"

回滚: 把 $BACKUP_DIR 内容按相同路径拷回 \$HOME
EOF
