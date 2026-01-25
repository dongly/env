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
> **注意：** env v2.0 需要 Python kconfiglib（通过 `pip install kconfiglib` 安装），但 env v1.5.x 与 kconfiglib 冲突（请运行 `pip uninstall kconfiglib`）。

---

## 目录

- [Linux/macOS](#linuxmacos-使用指南)
  - [教程](#教程)
  - [安装](#安装-env)
  - [激活环境](#激活-env)
  - [使用](#使用-env)
- [Windows](#windows-使用指南)
  - [安装](#安装-env-1)
  - [激活环境](#激活-env-1)
- [故障排除](#故障排除)

---

## Linux/macOS 使用指南

### 教程

[如何在 Ubuntu 中安装 Env 工具并配合 QEMU 模拟器使用](https://github.com/RT-Thread/rt-thread/blob/master/documentation/quick-start/quick_start_qemu/quick_start_qemu_linux.md)

### 安装 Env

**统一安装脚本（Linux 和 macOS）**

```bash
wget https://raw.githubusercontent.com/RT-Thread/env/master/install.sh
chmod +x install.sh
./install.sh
rm install.sh
```

中国大陆用户：

```bash
wget https://gitee.com/RT-Thread-Mirror/env/raw/master/install.sh
chmod +x install.sh
./install.sh --cn
rm install.sh
```

**可用参数：**

| 参数 | 描述 |
|------|------|
| `--env-root <path>` | 设置自定义 .env 目录路径（覆盖默认的 `~/.env`） |
| `--cn` 或 `--gitee` | 使用中国镜像源（npmmirror、Gitee、清华 PyPI） |
| `--en` | 强制英文显示 |
| `--zh` | 强制中文显示 |

**使用示例：**

```bash
# 设置自定义安装路径
./install.sh --env-root /custom/path/to/env

# 使用中国镜像并设置自定义路径
./install.sh --env-root /custom/path/to/env --cn

# 默认安装（使用 ~/.env）
./install.sh
```

### 激活 RT-Thread ENV

安装完成后，在使用 RT-Thread 工具之前需要激活环境变量。

**方案 A：每次手动激活**

每 次 打开新终端时运行以下命令：

```bash
source ~/.env/env.sh
```

**方案 B：登录时自动激活（推荐）**

将激活命令添加到 shell 配置文件，使其自动运行：

```bash
# 对于 bash
echo 'source ~/.env/env.sh' >> ~/.bashrc

# 对于 zsh
echo 'source ~/.env/env.sh' >> ~/.zshrc
```

添加后，每次登录系统时会自动激活环境，无需再手动执行该命令。

### 使用 Env

详细使用说明请参考：
<https://github.com/RT-Thread/rt-thread/blob/master/documentation/env/env.md#bsp-configuration-menuconfig>

---

## Windows 使用指南

**已测试的 PowerShell 版本：**

- PSVersion 5.1.22621.963
- PSVersion 5.1.19041.2673

### 安装 Env

**前提条件：** 需要以管理员身份运行 PowerShell 来设置执行策略。

在 PowerShell 中执行：

```powershell
wget https://raw.githubusercontent.com/RT-Thread/env/master/install_windows.ps1 -O install_windows.ps1
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
.\install_windows.ps1
```

中国大陆用户：

```powershell
wget https://gitee.com/RT-Thread-Mirror/env/raw/master/install_windows.ps1 -O install_windows.ps1
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
.\install_windows.ps1 --cn
```

**可用参数：**

| 参数 | 描述 |
|------|------|
| `--env-root <path>` | 设置自定义 .env 目录路径（覆盖默认的 `~/.env`） |
| `--cn` 或 `--gitee` | 使用中国镜像源（npmmirror、Gitee、清华 PyPI） |
| `--en` | 强制英文显示 |
| `--zh` | 强制中文显示 |
| `-y` | 自动模式（结束时不暂停） |

**使用示例：**

```powershell
# 设置自定义安装路径
.\install_windows.ps1 --env-root "C:\custom\path\to\env"

# 使用中国镜像并设置自定义路径
.\install_windows.ps1 --env-root "C:\custom\path\to\env" --cn

# 默认安装（使用 ~/.env）
.\install_windows.ps1
```

**重要提示：**

1. ⚠️ 初始设置时必须以**管理员身份**运行 PowerShell。
2. ✅ 设置执行策略后，可以作为普通用户运行 PowerShell。
3. 🦠 杀毒软件可能会阻止安装，如有需要请暂时禁用。

### 激活 RT-Thread ENV

安装完成后，需要激活环境变量。

**方案 A：每次手动激活**

每 次启动新的 PowerShell 会话时运行以下命令：

```powershell
~/.env/env.ps1
```

**方案 B：启动时自动激活（推荐）**

创建或编辑 PowerShell 配置文件来自动激活环境：

```powershell
# 打开配置文件（如果不存在则创建）
notepad $PROFILE

# 在文件中添加以下行：
~/.env/env.ps1
```

PowerShell 配置文件位于：
`C:\Users\<用户名>\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`

如果 `WindowsPowerShell` 文件夹不存在，可能需要先创建它。添加激活命令后，每次重启 PowerShell 时会自动加载环境，无需再执行方案 A。

---

## 故障排除

### 镜像连接问题

如果下载缓慢或失败：

- 尝试使用 `--cn` 参数，使用 gitee 默认镜像
- 检查网络连接

### 权限问题（Linux/macOS）

```bash
# 修复权限问题
sudo chmod -R 755 ~/.env

# 如果 .env 属于 root 用户
sudo chown -R $USER:$USER ~/.env
```

### 权限问题（Windows）

如果遇到权限错误：

1. 以**管理员身份**运行 PowerShell
2. 检查杀毒软件是否阻止安装
3. 验证执行策略已设置：`Get-ExecutionPolicy -List`

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
