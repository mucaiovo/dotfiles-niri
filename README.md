# dotfiles-niri

Niri + DankMaterialShell (DMS) 桌面配置，**自包含**，不依赖 `shorin-dms-niri-git`。

## 这是什么

原本这套桌面由 AUR 包 `shorin-dms-niri-git` 提供：它自带一套配置模板（`/usr/share/shorin-dms-niri/`），通过 `shorindms init` 铺到 `$HOME`。本仓库把那套模板 **vendoring** 进来，接管部署，从此不再需要那个包。

分成两层，职责清晰：

| 层 | 内容 | 来源 |
|---|---|---|
| `dotfiles-shorin/` | 91 个文件，桌面底座（niri 结构、matugen 模板、fcitx5、fish、主题） | 从 shorin 包 vendoring |
| `dotfiles-user/` | 24 个文件，我的个人改动 | 我自己改的 |

部署时**底座先铺，个人层覆盖**。所以 `dotfiles-shorin/` 里的文件你可以随时用上游版本替换，个人改动不会被冲掉。

## 在另一台 Arch 机器上还原

### 1. 取回仓库

```bash
# 有 SSH 密钥时（推荐）
git clone git@github.com:mucaiovo/dotfiles-niri.git ~/dotfiles-niri

# 直连 GitHub 不通时
git clone https://ghproxy.net/https://github.com/mucaiovo/dotfiles-niri.git ~/dotfiles-niri

# 或网页 Download ZIP 后解压到 ~/dotfiles-niri
```

### 2. 一键部署

```bash
cd ~/dotfiles-niri
./install.sh
```

脚本会：

1. 检查环境与 AUR 助手
2. 用 `pacman` 装上核心依赖（niri、dms-shell、quickshell、matugen、kitty、fcitx5 等）
3. 检查 `shorin-dms-niri-git` 是否还在，并提示如何处置
4. 系统级设置：locale、`i2c` 组、`i2c-dev` 模块、电源管理
5. 铺 126 个文件（底座 → 个人层覆盖），自动把底座里的 `/home/shorin` 占位符换成真实家目录
6. 探测本机背光设备并写入 `settings.json`

常用参数：

```bash
./install.sh --dry-run        # 先看会做什么，不实际改动
./install.sh --no-packages    # 不装软件，只铺配置
./install.sh --no-system      # 不动 locale / i2c 等系统设置
```

### 3. 首次登录后必做

壁纸和配色是按机器生成的，无法预置：

1. 注销重登（`i2c` 组变更也需重登生效）
2. DMS 设置 → 个性化 → 壁纸，选一张壁纸
3. DMS 设置 → 主题与配色 → 选 `auto` 并挑配色
   这步会生成 `~/.config/niri/dms/colors.kdl` 与 `wpblur.kdl`

可选：Firefox 装 pywalfox 扩展 → Fetch；VSCode 装 DMS 主题扩展选 DankShell。

### 回滚

```bash
ls ~/.dotfiles-backup/       # 找时间戳
# 把该目录内容按相同路径拷回 $HOME 即可
```

## 日常维护

改完配置后同步回个人层：

```bash
cd ~/dotfiles-niri
./sync.sh            # 只看差异
./sync.sh --apply    # 实际同步
git add -A && git commit -m "更新配置" && git push
```

`sync.sh` **只写 `dotfiles-user/`**，不碰底座层。想覆盖某个底座文件，把它复制到 `dotfiles-user/` 的同路径即可。

## 关于摆脱 shorin 包

`shorin-dms-niri-git` 原本做四件事，现在前三件都由本仓库接管：

| 原职责 | 现状 |
|---|---|
| 装 80 个软件 | `install.sh` 的内置清单接管 |
| 部署 92 个配置模板 | vendoring 到 `dotfiles-shorin/` |
| 系统级改动（locale/i2c/firefox policies） | `install.sh` 第 3 步接管 |
| 文档 | 见下方参考资料 |

**可以安全移除主包**，但下面这些 shorin 专属包建议保留，它们不依赖主包：

- `shorin-contrib-git` —— `~/.local/bin` 里的 `sysup`、`clean`、`mirror-update` 等十几个命令都软链到它
- `shorin-screenrec-menu-git` —— niri 的 `Mod+F3` 录屏菜单

移除方式（确认新配置生效后再做）：

```bash
sudo pacman -Rns shorin-dms-niri-git
```

注意：`shorindms protect` 那套保护机制随之失效，但你已不需要它——改动现在直接进 git。

### 未纳入的文件

- `.local/bin/bad-apple` —— 17 MB 的 Bad Apple 动画，占原包体积的 99%，无实际用途，已排除

## 键位

全部键位见 `dotfiles-user/.config/niri/dms/binds.kdl`。常用：

| 按键 | 功能 |
|---|---|
| `Super+T` | 终端 |
| `Super+Z` | 开始菜单 |
| `Super+E` | 文件管理器 |
| `Super+Q` | 关闭窗口 |
| `Super+G` / `Super+O` | overview |
| `Super+H/L` | 左右切换聚焦 |
| `Super+U/I` | 上下切换工作区 |
| `Super+Alt+A` | 截图 |
| `Super+F3` | 录屏菜单 |
| `Super+Shift+/` | 按键教程 |

## 安全

仓库带 `pre-commit` 钩子，拦截疑似密钥。启用：

```bash
git config core.hooksPath .githooks
```

`.gitignore` 已排除 `~/.ssh`、`~/.gnupg`、`*.pem`、`*.key`，以及个人机器人运维脚本（含明文 token）。

## 参考

- [Niri Wiki](https://github.com/niri-wm/niri/wiki)
- [DankMaterialShell](https://danklinux.com/)
- [Shorin Wiki](https://shorin.xyz/wiki)
