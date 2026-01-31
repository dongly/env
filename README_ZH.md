# RT-Thread Env Python 脚本

**[English Document](README.md)**

> **⚠️ 重要提示**
>
> [env v2.0](https://github.com/RT-Thread/env/tree/master) 和 [env-windows v2.0](https://github.com/RT-Thread/env-windows/tree/v2.0.0) 仅 **完全支持** RT-Thread > v5.1.0 或 [master](https://github.com/rt-thread/rt-thread) 分支。如果您使用 RT-Thread <= v5.1.0，请使用 [env v1.5.x](https://github.com/RT-Thread/env/tree/v1.5.x)（Linux）或 [env-windows v1.5.2](https://github.com/RT-Thread/env-windows/tree/v1.5.2)（Windows）。
>
> **v2.0 主要变更：**
> - 将 Python 版本从 v2 升级到 v3
> - 使用 Python kconfiglib 替换 kconfig-frontends
>
> **注意：** env v2.0 需要 Python kconfiglib（~~通过 `pip install kconfiglib` 安装~~,现在的安装程序已安装此软件包），但 env v1.5.x 与 kconfiglib 冲突（请运行 `pip uninstall kconfiglib`）。

---

## 目录

- [Windows](#windows-使用指南)
  - [安装](#安装-env-1)
  - [激活环境](#激活-env-1)
- [Linux/macOS](#linuxmacos-使用指南)
  - [教程](#教程)
  - [安装](#安装-env)
  - [激活环境](#激活-env)
  - [使用](#使用-env)

- [参数说明](#参数说明)
- [故障排除](#故障排除)
  - [备份策略说明](#备份策略说明)
  - [镜像连接问题](#镜像连接问题)
  - [权限问题（Linux/macOS）](#权限问题linuxmacos)
  - [权限问题（Windows）](#权限问题windows)
- [相关文档](#相关文档)
- [许可证](#许可证)
- [相关链接](#相关链接)

---

## Windows 使用指南

### 安装 Env

**前提条件：** 无特殊要求，安装脚本会自动处理权限提升和执行策略设置。

**支持的 PowerShell 版本：**
- Windows PowerShell (PowerShell v5.1 及以上版本)
- PowerShell Core / PowerShell 7+ (跨平台版本)

在 PowerShell 中执行：

```powershell
# 一行命令下载并运行安装脚本（使用内存运行）
$script = Invoke-WebRequest -Uri https://raw.githubusercontent.com/RT-Thread/env/master/tools/install.ps1 -UseBasicParsing; Invoke-Expression $script.Content
```

中国大陆用户（可选，安装脚本会自动检测并使用镜像）：

```powershell
# 一行命令下载并运行安装脚本（使用内存运行）
$script = Invoke-WebRequest -Uri https://gitee.com/RT-Thread-Mirror/env/raw/master/tools/install.ps1 -UseBasicParsing; Invoke-Expression "$($script.Content) --cn"
```

**注意：**
- 安装脚本会根据地理位置自动选择是否使用镜像源，除非使用 `--cn` 或 `--official` 参数明确指定
- 使用内存运行方式（Invoke-WebRequest + Invoke-Expression），无需下载脚本到磁盘
- Windows 安装脚本内置提权功能，会自动弹出提权窗口，无需手动以管理员权限运行
- 所有系统都支持普通用户权限安装，安装脚本会自动处理权限提升

有关所有可用参数的完整说明，请参见 [参数说明](#参数说明) 部分。

**重要提示：**

1. ✅ 安装脚本会自动处理权限提升和执行策略设置，可以作为普通用户运行 PowerShell。
2. 🦠 杀毒软件可能会阻止安装，如有需要请暂时禁用。

### 激活 RT-Thread ENV

安装完成后，需要激活环境变量。

**方案 A：每次手动激活**

每 次启动新的 PowerShell 会话时运行以下命令：

```powershell
~/.rt-env/env.ps1
```

**方案 B：启动时自动激活（推荐）**

创建或编辑 PowerShell 配置文件来自动激活环境：

```powershell
# 打开配置文件（如果不存在则创建）
notepad $PROFILE

# 在文件中添加以下行：
~/.rt-env/env.ps1
```

PowerShell 配置文件位于：
`C:\Users\<用户名>\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`

如果 `WindowsPowerShell` 文件夹不存在，可能需要先创建它。添加激活命令后，每次重启 PowerShell 时会自动加载环境，无需再执行方案 A。

---
## Linux/macOS 使用指南

### 教程

[如何在 Ubuntu 中安装 Env 工具并配合 QEMU 模拟器使用](https://github.com/RT-Thread/rt-thread/blob/master/documentation/quick-start/quick_start_qemu/quick_start_qemu_linux.md)

**统一安装脚本（Linux 和 macOS）**

```bash
wget -O- https://raw.githubusercontent.com/RT-Thread/env/master/tools/install.sh | bash
```

中国大陆用户（可选，安装脚本会自动检测并使用镜像）：

```bash
wget -O- https://gitee.com/RT-Thread-Mirror/env/raw/master/tools/install.sh | bash --cn
```

**注意：**
- 安装脚本会根据地理位置自动选择是否使用镜像源，除非使用 `--cn` 或 `--official` 参数明确指定
- Linux 系统安装脚本会根据需要自动使用 `sudo` 提权，无需手动以 root 权限运行
- 所有系统都支持普通用户权限安装，安装脚本会自动处理权限提升

有关所有可用参数的完整说明，请参见 [参数说明](#参数说明) 部分。




### 激活 RT-Thread ENV

安装完成后，在使用 RT-Thread 工具之前需要激活环境变量。

**方案 A：每次手动激活**

每 次 打开新终端时运行以下命令：

```bash
source ~/.rt-env/env.sh
```

**方案 B：登录时自动激活（推荐）**

将激活命令添加到 shell 配置文件，使其自动运行：

```bash
# 对于 bash
echo 'source ~/.rt-env/env.sh' >> ~/.bashrc

# 对于 zsh
echo 'source ~/.rt-env/env.sh' >> ~/.zshrc
```

添加后，每次登录系统时会自动激活环境，无需再手动执行该命令。

### 使用 Env

详细使用说明请参考：
<https://github.com/RT-Thread/rt-thread/blob/master/documentation/env/env.md#bsp-configuration-menuconfig>

---

## 参数说明

以下为所有安装脚本通用的参数说明：

| 参数 | 描述 |
|------|------|
| `-y`, `--yes`, `--auto` | 自动安装，无提示 |
| `-c`, `--cn`, `--gitee` | 使用中国镜像源（Gitee、PyPI TUNA） |
| `-o`, `--official` | 强制使用官方源 |
| `-d`, `--pyocd` | 安装 pyocd（用于调试） |
| `-r`, `--env-root <path>` | 设置自定义 .rt-env 目录路径（覆盖默认的 `~/.rt-env`） |
| `-e`, `--en`, `--english` | 强制英文显示 |
| `-z`, `--zh`, `--chinese` | 强制中文显示 |
| `-P`, `--packages <repo>[#<branch>]` | 指定 packages 仓库地址和分支，格式: url[#branch] |
| `-E`, `--env <repo>[#<branch>]` | 指定 env 仓库地址和分支，格式: url[#branch] |
| `-S`, `--sdk <repo>[#<branch>]` | 指定 sdk 仓库地址和分支，格式: url[#branch] |
| `-b`, `--backup <strategy>` | 备份策略: preserve(保留配置和工具链,删除其他), delete_all(删除所有内容), backup_all(完整备份) |
| `-t`, `--touch-env-url <url>` | 指定 touch_env.py 下载 URL |
| `-h`, `--help` | 显示帮助信息 |
| `-p`, `--python [path]` | 安装便携式 Python，安装目录为 path（仅 Windows PowerShell，默认：D:\Tools\Python） |

**PowerShell 版本说明：**

- **Windows PowerShell**: Windows 系统自带的 PowerShell (v5.1 及以上版本)
- **PowerShell Core / PowerShell 7+**: 跨平台版本，可在 Windows、Linux 和 macOS 上运行

**备份策略说明：**

- **preserve** (默认): 保留配置文件(.config)和工具链(local_pkgs)，删除其他内容后重新安装
- **delete_all**: 完全删除现有ENV目录，不保留任何内容  
- **backup_all**: 创建完整备份，保留所有内容，包括配置和工具链

**使用示例 (Windows [PowerShell - 本地脚本])：**

```powershell
# 设置自定义安装路径
.\install.ps1 --env-root "C:\custom\path\to\env"

# 使用中国镜像并设置自定义路径
.\install.ps1 --env-root "C:\custom\path\to\env" --cn

# 默认安装（使用 ~/.rt-env）
.\install.ps1

# 自动安装，无提示
.\install.ps1 -y

# 强制使用官方源
.\install.ps1 --official

# 安装便携式 Python
.\install.ps1 --python "D:\MyPython"

# 安装 pyocd 调试工具
.\install.ps1 --pyocd

# 指定自定义 packages 仓库
.\install.ps1 --packages https://gitee.com/user/packages.git#my-branch

# 指定自定义 env 仓库
.\install.ps1 --env https://gitee.com/user/env.git#my-branch

# 指定自定义 sdk 仓库
.\install.ps1 --sdk https://gitee.com/user/sdk.git#my-branch

# 使用备份策略
.\install.ps1 --backup preserve

# 指定 touch_env.py 下载 URL
.\install.ps1 --touch-env-url https://gitee.com/RT-Thread-Mirror/env/raw/master/tools/touch_env.py
```

**使用示例 (Windows [PowerShell - 内存运行])：**

```powershell
# 从 GitHub 下载并运行（使用内存运行方式）
$script = Invoke-WebRequest -Uri https://raw.githubusercontent.com/RT-Thread/env/master/tools/install.ps1 -UseBasicParsing; Invoke-Expression "$($script.Content) --env-root 'C:\custom\path\to\env'"

# 使用中国镜像（使用内存运行方式）
$script = Invoke-WebRequest -Uri https://gitee.com/RT-Thread-Mirror/env/raw/master/tools/install.ps1 -UseBasicParsing; Invoke-Expression "$($script.Content) --cn"

# 自动安装，无提示（使用内存运行方式）
$script = Invoke-WebRequest -Uri https://raw.githubusercontent.com/dongly/env/refs/heads/i3/tools/install.ps1 -UseBasicParsing; Invoke-Expression "$($script.Content) -y"

# 指定自定义 env 仓库（使用内存运行方式）
$script = Invoke-WebRequest -Uri https://raw.githubusercontent.com/RT-Thread/env/master/tools/install.ps1 -UseBasicParsing; Invoke-Expression "$($script.Content) --env https://gitee.com/user/env.git#my-branch"

   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
   $script = Invoke-WebRequest -Uri https://raw.githubusercontent.com/dongly/env/i3/tools/install.ps1 -UseBasicParsing   Invoke-Expression "$($script.Content) -env 'https://github.com/dongly/env.git#i3'"


    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
   $script = Invoke-WebRequest -Uri https://raw.githubusercontent.com/dongly/env/i3/tools/install.ps1 -UseBasicParsing    & ([scriptblock]::Create($script.Content)) --env 'https://github.com/dongly/env.git#i3'

$script = Invoke-WebRequest -Uri https://raw.githubusercontent.com/dongly/env/i3/tools/install.ps1 -UseBasicParsing; Invoke-Expression "$($script.Content) --env https://github.com/dongly/env.git#i3"

# 安装 pyocd 调试工具（使用内存运行方式）
$script = Invoke-WebRequest -Uri https://raw.githubusercontent.com/RT-Thread/env/master/tools/install.ps1 -UseBasicParsing; Invoke-Expression "$($script.Content) --pyocd"
```
**使用示例 (Linux/macOS [bash / zsh])：**
```bash
# 设置自定义安装路径
./install.sh --env-root /custom/path/to/env

# 使用中国镜像并设置自定义路径
./install.sh --env-root /custom/path/to/env --cn

# 默认安装（使用 ~/.rt-env）
./install.sh

# 自动安装，无提示
./install.sh -y

# 强制使用官方源
./install.sh --official

# 安装 pyocd 调试工具
./install.sh --pyocd

# 指定自定义 packages 仓库
./install.sh --packages https://github.com/user/packages.git#my-branch

# 指定自定义 env 仓库
./install.sh --env https://github.com/user/env.git#my-branch

# 指定自定义 sdk 仓库
./install.sh --sdk https://github.com/user/sdk.git#my-branch

# 使用备份策略
./install.sh --backup preserve

# 指定 touch_env.py 下载 URL
./install.sh --touch-env-url https://gitee.com/RT-Thread-Mirror/env/raw/master/tools/touch_env.py
```

**使用示例 (Linux/macOS [bash - 一行命令])：**
```bash
# 从 GitHub 下载并运行（一行命令）
wget -O- https://raw.githubusercontent.com/RT-Thread/env/master/tools/install.sh | bash

# 使用中国镜像（一行命令）
wget -O- https://gitee.com/RT-Thread-Mirror/env/raw/master/tools/install.sh | bash --cn

# 设置自定义安装路径（一行命令）
wget -O- https://raw.githubusercontent.com/RT-Thread/env/master/tools/install.sh | bash -s -- --env-root /custom/path/to/env

# 使用中国镜像并设置自定义路径（一行命令）
wget -O- https://gitee.com/RT-Thread-Mirror/env/raw/master/tools/install.sh | bash -s -- --env-root /custom/path/to/env --cn

# 自动安装，无提示（一行命令）
wget -O- https://raw.githubusercontent.com/RT-Thread/env/master/tools/install.sh | bash -s -- -y

# 安装 pyocd 调试工具（一行命令）
wget -O- https://raw.githubusercontent.com/RT-Thread/env/master/tools/install.sh | bash -s -- --pyocd
```

---

## 故障排除

### 镜像连接问题

如果下载缓慢或失败：

- 尝试使用 `--cn` 参数，使用 gitee 默认镜像
- 检查网络连接

### 权限问题（Linux/macOS）

Linux 系统的安装脚本会自动使用 `sudo` 安装系统依赖，无需手动执行权限相关命令。

如果遇到权限问题：

```bash
# 检查 .rt-env 目录权限
ls -la ~/.rt-env

# 如果 .rt-env 属于 root 用户，可以尝试以下命令
sudo chown -R $USER:$USER ~/.rt-env
```

### 权限问题（Windows）

如果遇到权限错误：

1. 检查杀毒软件是否阻止安装
2. Windows 安装脚本内置执行策略设置和提权功能，会自动处理需要管理员权限的操作

---

## 相关文档

- [Env 工具使用指南](https://github.com/RT-Thread/rt-thread/blob/master/documentation/env/env.md)
- [QEMU 快速入门](https://github.com/RT-Thread/rt-thread/blob/master/documentation/quick-start/quick_start_qemu/quick_start_qemu_linux.md)
- [BSP 配置](https://github.com/RT-Thread/rt-thread/blob/master/documentation/env/env.md#bsp-configuration-menuconfig)

---

## 许可证

Apache License 2.0

---

## 相关链接

- [GitHub 仓库](https://github.com/RT-Thread/env)
- [RT-Thread 官方网站](https://www.rt-thread.org/)
- [RT-Thread 文档中心](https://www.rt-thread.io/document/site/)


   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
   $script = Invoke-WebRequest -Uri https://raw.githubusercontent.com/dongly/env/i3/tools/install.ps1 -UseBasicParsing;   Invoke-Expression "$($script.Content) --env 'https://github.com/dongly/env.git#i3'"


      Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
   $scriptPath = Join-Path $env:TEMP "install.ps1"
   Invoke-WebRequest -Uri https://raw.githubusercontent.com/dongly/env/i3/tools/install.ps1 -OutFile $scriptPath
   & $scriptPath --env 'https://github.com/dongly/env.git#i3'
   Remove-Item $scriptPath
   