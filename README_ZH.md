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

- [Windows 安装指南](#windows-安装指南)
  - [安装 Env](#安装-env)
  - [激活环境](#激活-rt-thread-env)
- [Linux/macOS 安装指南](#linuxmacos-安装指南)
  - [安装 Env](#安装-env-1)
  - [激活环境](#激活-rt-thread-env-1)
- [安装脚本参数说明](#安装脚本参数说明)
- [使用 Env 指南](#使用-env-指南)
- [故障排除](#故障排除)
- [相关文档](#相关文档)
- [许可证](#许可证)
- [相关链接](#相关链接)

---

## Windows 安装指南

### 安装 Env

**前提条件：**
- 第一次安装需要使用管理员权限（用于设置 .ps1 脚本的执行策略及启用长路径支持）
- 之后的更新可以使用普通用户权限

**支持的 PowerShell 版本：**
- Windows PowerShell (PowerShell v5.1 及以上版本)
- PowerShell 7+ (跨平台版本)

**重要兼容性说明：**

> ⚠️ **Windows PowerShell 与 PowerShell 编码兼容性**
>
> - **Windows PowerShell**：在中文 Windows 系统上，默认编码是 GB2312。从网络下载的 .ps1 脚本通常是 UTF-8 编码，但 Windows PowerShell 不支持不带 BOM 的 UTF-8 文件，只能读取 UTF-8 with BOM 编码的文件。
>
> - **PowerShell Core / PowerShell 7+**：原生支持 UTF-8，无编码问题。
>
> 为确保兼容性，安装脚本已配置为 UTF-8 with BOM 编码，并推荐使用以下安装命令：

**Windows PowerShell 与 PowerShell 兼容的安装命令：**

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass Process; irm https://raw.githubusercontent.com/RT-Thread/env/master/tools/install.ps1 | Out-File -Encoding utf8 .\install.ps1; .\install.ps1; Remove-Item .\install.ps1
```


中国大陆用户（可选）：

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass Process; irm https://gitee.com/RT-Thread-Mirror/env/raw/master/tools/install.ps1 | Out-File -Encoding utf8 .\install.ps1; .\install.ps1; Remove-Item .\install.ps1
```

**注意：**
- 安装脚本会根据地理位置自动选择是否使用镜像源，除非使用 `--cn` 或 `--official` 参数明确指定
- 第一次安装需要使用管理员权限

有关所有可用参数的完整说明，请参见 [参数说明](#参数说明) 部分。

**重要提示：**

1. ✅ 安装脚本需要管理员权限进行脚本执行策略及长路径支持设置
2. 非管理员权限运行时，如需上述设置会提示并退出
3. 🦠 杀毒软件可能会阻止安装，如有需要请暂时禁用

### 激活 RT-Thread ENV

安装完成后，需要激活环境变量。

**方案 A：每次手动激活**

每次启动新的 PowerShell 会话时运行以下命令：

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

**配置文件路径说明：**

| PowerShell 版本 | 配置文件路径 |
|----------------|-------------|
| Windows PowerShell (v5.1) | `C:\Users\<用户名>\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1` |
| PowerShell 7+ | `C:\Users\<用户名>\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` |

添加激活命令后，每次重启 PowerShell 时会自动加载环境，无需再执行方案 A。

---
## Linux/macOS 安装指南

**统一安装脚本（Linux 和 macOS）**

```bash
wget -O- https://raw.githubusercontent.com/RT-Thread/env/master/tools/install.sh | bash
```

中国大陆用户（可选）：

```bash
wget -O- https://gitee.com/RT-Thread-Mirror/env/raw/master/tools/install.sh | bash --cn
```

**注意：**
- 安装脚本会根据地理位置自动选择是否使用镜像源，除非使用 `--cn` 或 `--official` 参数明确指定
- Linux 系统安装脚本会根据需要自动使用 `sudo` 提权，无需手动以 root 权限运行
- 所有系统都支持普通用户权限安装，安装脚本会自动处理权限提升

有关所有可用参数的完整说明，请参见 [安装脚本参数说明](#安装脚本参数说明) 部分。

### 激活 RT-Thread ENV

安装完成后，在使用 RT-Thread 工具之前需要激活环境变量。

**方案 A：每次手动激活**

每次打开新终端时运行以下命令：

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

### 教程

**Env 工具教程：**

- [在 Ubuntu 中安装 Env 并配合 QEMU 模拟器使用](https://github.com/RT-Thread/rt-thread/blob/master/documentation/quick-start/quick_start_qemu/quick_start_qemu_linux.md)

---
## 安装脚本参数说明

以下为所有安装脚本通用的参数说明：

| 参数 | 描述 |
|------|------|
| `-y`, `--yes`, `--auto` | 自动安装，无交互 |
| `-c`, `--cn`, `--gitee` | 使用中国镜像源（Gitee、PyPI TUNA） |
| `-o`, `--official` | 强制使用官方源 |
| `-d`, `--pyocd` | 安装 pyocd（用于调试） |
| `-r`, `--env-root <path>` | 设置自定义 .rt-env 目录路径（覆盖默认的 `~/.rt-env`） |
| `-e`, `--en`, `--english` | 强制英文显示 |
| `-z`, `--zh`, `--chinese` | 强制中文显示 |
| `-P`, `--packages <repo>[#<branch>]` | 指定 packages 仓库地址和分支，格式: url[#branch] |
| `-E`, `--env <repo>[#<branch>]` | 指定 env 仓库地址和分支，格式: url[#branch] |
| `-S`, `--sdk <repo>[#<branch>]` | 指定 sdk 仓库地址和分支，格式: url[#branch] |
| `-b`, `--backup <strategy>` | 备份策略：preserve（保留配置和工具链）、delete_all（删除所有内容）、backup_all（完整备份） |
| `-t`, `--touch-env-url <url>` | 指定 touch_env.py 下载 URL |
| `-h`, `--help` | 显示帮助信息 |
| `-p`, `--python [path]` | 安装便携式 Python，安装目录为 path（仅 Windows，默认：D:\Tools\Python） |

**备份策略说明：**

- **preserve** (默认)：保留配置文件（.config）和工具链（local_pkgs），删除其他内容后重新安装
- **delete_all**：完全删除现有 ENV 目录，不保留任何内容
- **backup_all**：创建完整备份，保留所有内容，包括配置和工具链

**使用示例：**

**Windows (PowerShell)：**
```powershell
# 基本安装
.\install.ps1

# 使用中国镜像 + 自动安装
.\install.ps1 -c -y

# 安装便携式 Python
.\install.ps1 -p "D:\Tools\Python" -r "D:\RT-Env"

# 指定自定义 env 仓库分支
.\install.ps1 -E "https://github.com/RT-Thread/env.git#master"

# 安装 pyocd + 官方源
.\install.ps1 -d -o
```

**Linux/macOS (bash)：**
```bash
# 基本安装
./install.sh

# 使用中国镜像 + 自动安装
./install.sh -c -y

# 指定自定义 packages 仓库
./install.sh -P "https://gitee.com/RT-Thread/packages.git#master"

# 使用备份策略
./install.sh -b preserve

# 指定自定义 sdk 仓库
./install.sh -S "https://github.com/RT-Thread/sdk.git#master"
```

## 使用 Env 指南

详细使用说明请参考：

- [Env 工具使用指南](https://github.com/RT-Thread/rt-thread/blob/master/documentation/env/env.md)
- [Env 官方用户手册](https://www.rt-thread.org/document/site/#/development-tools/env/env)

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
2. 脚本会自动检测是否需要管理员权限，如需要会提示用户以管理员身份运行

---

## 相关文档

- [Env 工具完整文档](https://github.com/RT-Thread/rt-thread/blob/master/documentation/env/env.md)
- [QEMU 快速入门](https://github.com/RT-Thread/rt-thread/blob/master/documentation/quick-start/quick_start_qemu/quick_start_qemu_linux.md)
- [BSP 配置说明](https://github.com/RT-Thread/rt-thread/blob/master/documentation/env/env.md#bsp-configuration-menuconfig)

---

## 许可证

本项目采用 GPL-2.0 许可证开源。

---

## 相关链接

- [GitHub 仓库](https://github.com/RT-Thread/env)
- [RT-Thread 官方网站](https://www.rt-thread.org/)
- [RT-Thread 文档中心](https://www.rt-thread.io/document/site/)

---

## 贡献者

感谢所有为 RT-Thread Env 项目做出贡献的开发者。