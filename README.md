# dotfiles-niri

Niri + DankMaterialShell（Shorin-DMS 套装）个人配置。

这套配置**不是从零搭建的**，而是在 [shorin-dms-niri](https://shorin.xyz/wiki) 提供的桌面上做的个人改动。因此本仓库只保存**增量**：只放我改过的文件，没改过的由 `shorindms init` 提供。

## 在另一台 Arch 机器上还原

### 1. 取回仓库

```bash
# 有 SSH 密钥时（推荐）
git clone git@github.com:mucaiovo/dotfiles-niri.git ~/dotfiles-niri

# 直连 GitHub 不通时，走镜像
git clone https://ghproxy.net/https://github.com/mucaiovo/dotfiles-niri.git ~/dotfiles-niri

# 或者直接在网页上 Download ZIP，解压到 ~/dotfiles-niri
```

ZIP 方式没有 `.git`，`install.sh` 会自动回退到遍历目录（已适配），但 `sync.sh` 需要 git，仅本机回传时用到。

### 2. 安装依赖组件

```bash
paru -S --needed shorin-dms-niri-git
shorindms init          # 首次运行，铺开包自带的基础配置
```

`install.sh` 会检查这一步，未完成会提示并中止。

### 3. 应用个人配置

```bash
cd ~/dotfiles-niri
./install.sh
```

`install.sh` 会：

1. 检查 UEFI、pacman、AUR 助手
2. 确认 `shorin-dms-niri-git` 已安装且 `~/.config/niri` 存在，否则提示先 init
3. 把将被覆盖的文件备份到 `~/.dotfiles-backup/<时间戳>/`
4. 按文件清单把仓库内文件**软链**到 `$HOME` 对应位置
5. 把 `settings.json` 里留空的亮度设备修正为**本机**真实背光设备
6. 恢复脚本可执行权限

### 4. 首次登录后必做

DMS 的壁纸与配色是按机器生成的，无法随仓库携带：

1. 注销重登，让 Niri 读取新配置
2. DMS 设置 → 个性化 → 壁纸，选一张壁纸
3. DMS 设置 → 主题与配色 → 选 `auto` 并挑配色，这一步会重新生成 `dms/colors.kdl` 和 `dms/wpblur.kdl`

可选：Firefox 装 pywalfox 扩展 → Fetch；VSCode 装 DMS 主题扩展选 DankShell。

### 回滚

```bash
ls ~/.dotfiles-backup/          # 找到对应时间戳
# 把该目录内容按相同路径拷回 $HOME 即可
```

## 日常维护

改完配置后把改动同步回仓库：

```bash
cd ~/dotfiles-niri
./sync.sh            # 只看差异，不写入
./sync.sh --apply    # 实际同步
git diff             # 审阅
git add -A && git commit -m "更新配置" && git push
```

脚本刻意使用**拷贝**而非软链。日常用的机器上**不要**把 `~/.config` 建成软链指向仓库：`shorindms update` 落盘时可能打断软链，反而把你的真实配置变成断链。软链只在 `install.sh` 还原新机器时使用。

`DankMaterialShell/settings.json` 里的背光设备名是本机专属值，`sync.sh` 同步时会自动清空它，避免把本机设备名固化进仓库。

## 为什么只有这些文件

`shorin-dms-niri-git` 自带整套 dotfiles。我用逐文件 diff 找出了真正被我改动的部分：

| 类别 | 处理 | 原因 |
|---|---|---|
| 我改过的 | **入库** | `niri/config.kdl`、`dms/binds.kdl`、`dms/layout.kdl`、`dms/alttab.kdl`、`dms/cursor.kdl`、`scripts/screenshot-sound.sh` |
| 包自带且未改 | 不入库 | `blur.kdl`、`animations.kdl`、`kitty.conf`、`cava/config` 等，`shorindms init` 即可还原 |
| 自动生成 | **明文说明，不还原** | `dms/colors.kdl`、`dms/wpblur.kdl` 由 matugen/DMS 生成，带 `DO NOT EDIT` 标记 |
| 个人资产 | 不入库 | 121 张壁纸（727 MB）、`uv`/`btop` 二进制 |

`dotfiles/.config/niri/dms/colors.kdl` 保留了一份**快照**，仅作首次登录前的兜底，DMS 一启动就会覆盖它。

## 版本管理须知

- `shorindms update` 会同步上游新配置。本仓库中的文件若同时处于 `shorindms` 的**保护列表**，不会被覆盖：
  ```bash
  shorindms protected-list          # 查看当前受保护路径
  shorindms protect .config/niri/dms/binds.kdl
  ```
- 由于文件是软链，`shorindms update` 若用「重命名再写入」的方式落盘，**可能打断软链**。更新后建议执行：
  ```bash
  cd ~/dotfiles-niri && ./install.sh
  ```
  重新建立链接即可。

## 安全

仓库带一个 `pre-commit` 钩子，会拦截疑似密钥的提交。启用方式：

```bash
git config core.hooksPath .githooks
```

`.gitignore` 已排除 `~/.ssh`、`~/.gnupg`、`*.pem`、`*.key`，以及个人机器人运维脚本（含明文 token）。

## 键位

全部键位见 `dotfiles/.config/niri/dms/binds.kdl`。常用：

| 按键 | 功能 |
|---|---|
| `Super+T` | 终端 |
| `Super+Z` | 开始菜单 / 程序菜单 |
| `Super+E` | 文件管理器 |
| `Super+Q` | 关闭窗口 |
| `Super+G` / `Super+O` | overview |
| `Super+H/L` | 左右切换聚焦 |
| `Super+U/I` | 上下切换工作区 |
| `Super+Alt+A` | 截图 |
| `Super+Shift+/` | 按键教程 |

## 参考

- [Niri Wiki](https://github.com/niri-wm/niri/wiki)
- [DankMaterialShell](https://danklinux.com/)
- [Shorin Wiki](https://shorin.xyz/wiki)
