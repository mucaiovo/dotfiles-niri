# dotfiles-niri

Niri + DankMaterialShell（Shorin-DMS 套装）个人配置。

这套配置**不是从零搭建的**，而是在 [shorin-dms-niri](https://shorin.xyz/wiki) 提供的桌面上做的个人改动。因此本仓库只保存**增量**：只放我改过的文件，没改过的由 `shorindms init` 提供。

## 在另一台 Arch 机器上还原

```bash
git clone <本仓库地址> ~/dotfiles-niri
cd ~/dotfiles-niri
./install.sh
```

`install.sh` 会：

1. 检查 UEFI、git、pacman、AUR 助手
2. 确认 `shorin-dms-niri-git` 已安装；未安装则提示安装，必要时自动执行 `shorindms init` 铺开基础配置
3. 按 `git ls-files` 逐文件备份到 `~/.dotfiles-backup/<时间戳>/`
4. 把仓库内文件**软链**到 `$HOME` 对应位置
5. 把 `settings.json` 里留空的亮度设备修正为**本机**真实背光设备
6. 恢复脚本可执行权限

还原后仍需手动完成三件事（壁纸与配色是按机器生成的，无法随仓库携带）：

1. 注销重登，让 Niri 读取新配置
2. DMS 设置 → 个性化 → 壁纸，选一张壁纸
3. DMS 设置 → 主题与配色 → 选 `auto` 并挑配色，这一步会重新生成 `dms/colors.kdl` 和 `dms/wpblur.kdl`

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
