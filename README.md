# Python Scripts for RT-Thread Env

**[中文文档](README_ZH.md)**

> **⚠️ Important Notice**
>
> [env v2.0](https://github.com/RT-Thread/env/tree/master) and [env-windows v2.0](https://github.com/RT-Thread/env-windows/tree/v2.0.0) only **fully support** RT-Thread > v5.1.0 or the [master](https://github.com/rt-thread/rt-thread) branch. If you are using RT-Thread <= v5.1.0, please use [env v1.5.x](https://github.com/RT-Thread/env/tree/v1.5.x) (for Linux) or [env-windows v1.5.2](https://github.com/RT-Thread/env-windows/tree/v1.5.2) (for Windows).
>
> **Key Changes in v2.0:**
> - Upgraded Python version from v2 to v3
> - Replaced kconfig-frontends with Python kconfiglib
>
> **Note:** env v2.0 requires Python kconfiglib (now automatically installed by the installer), but env v1.5.x conflicts with kconfiglib (please run `pip uninstall kconfiglib`).

---

## Table of Contents

- [Windows Installation Guide](#windows-installation-guide)
  - [Install Env](#install-env)
  - [Activate Environment](#activate-rt-thread-env)
- [Linux/macOS Installation Guide](#linuxmacos-installation-guide)
  - [Install Env](#install-env-1)
  - [Activate Environment](#activate-rt-thread-env-1)
- [Installation Script Parameters](#installation-script-parameters)
- [Env Usage Guide](#env-usage-guide)
- [Troubleshooting](#troubleshooting)
- [Related Documents](#related-documents)
- [License](#license)
- [Related Links](#related-links)

---

## Windows Installation Guide

### Install Env

**Prerequisites:**
- First-time installation requires administrator privileges (to set script execution policy and enable long path support)
- Subsequent updates can use normal user privileges

**Supported PowerShell Versions:**
- Windows PowerShell (PowerShell v5.1 and above)
- PowerShell 7+ (cross-platform version)

**Important Compatibility Notice:**

> ⚠️ **PowerShell Encoding Compatibility**
>
> - **Windows PowerShell**: On Chinese Windows systems, the default encoding is GB2312. Downloaded .ps1 scripts are typically UTF-8 encoded, but Windows PowerShell does not support UTF-8 files without BOM. It can only read UTF-8 with BOM encoded files.
>
> - **PowerShell 7+**: Native UTF-8 support, no encoding issues.
>
> Installation scripts are configured as UTF-8 with BOM encoding to ensure compatibility.

**Windows Installation Command:**

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass Process; irm https://raw.githubusercontent.com/RT-Thread/env/master/tools/install.ps1 | Out-File -Encoding utf8 .\install.ps1; .\install.ps1; Remove-Item .\install.ps1
```

For users in China (optional):

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass Process; irm https://gitee.com/RT-Thread-Mirror/env/raw/master/tools/install.ps1 | Out-File -Encoding utf8 .\install.ps1; .\install.ps1; Remove-Item .\install.ps1
```

**Notes:**
- Installation script automatically selects mirror sources based on geographic location (can be specified using `--cn` or `--official` parameters)
- First-time installation requires administrator privileges

For complete parameter descriptions, see [Installation Script Parameters](#installation-script-parameters).

**Important Tips:**

1. ✅ Installation script requires administrator privileges for script execution policy and long path support settings
2. ⚠️ When running without administrator privileges, if the above settings are required, it will prompt and exit
3. 🦠 Antivirus software may block installation, please temporarily disable if needed

### Activate RT-Thread ENV

After installation, you need to activate the environment variables.

**Option A: Manual Activation Each Time**

Run the following command each time you start a new PowerShell session:

```powershell
~/.rt-env/env.ps1
```

**Option B: Auto Activation on Startup (Recommended)**

Create or edit a PowerShell configuration file to automatically activate the environment:

```powershell
# Open configuration file (creates if it doesn't exist)
notepad $PROFILE

# Add the following line to the file:
~/.rt-env/env.ps1
```

**Configuration File Paths:**

| PowerShell Version | Configuration File Path |
|-------------------|------------------------|
| Windows PowerShell (v5.1) | `C:\Users\<username>\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1` |
| PowerShell 7+ | `C:\Users\<username>\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` |

After adding the activation command, the environment will be loaded automatically each time you restart PowerShell, no need to execute Option A.

---
## Linux/macOS Installation Guide

**Unified Installation Script (Linux and macOS)**

```bash
wget -O- https://raw.githubusercontent.com/RT-Thread/env/master/tools/install.sh | bash
```

For users in China (optional):

```bash
wget -O- https://gitee.com/RT-Thread-Mirror/env/raw/master/tools/install.sh | bash --cn
```

**Notes:**
- Installation script automatically selects mirror sources based on geographic location (can be specified using `--cn` or `--official` parameters)
- Linux installation script automatically uses `sudo` to elevate privileges as needed, no need to manually run as root
- All systems support installation with normal user privileges, installation script automatically handles privilege elevation

For complete parameter descriptions, see [Installation Script Parameters](#installation-script-parameters).

### Activate RT-Thread ENV

After installation, you need to activate the environment variables before using RT-Thread tools.

**Option A: Manual Activation Each Time**

Run the following command each time you open a new terminal:

```bash
source ~/.rt-env/env.sh
```

**Option B: Auto Activation on Login (Recommended)**

Add the activation command to your shell configuration file to make it run automatically:

```bash
# For bash
echo 'source ~/.rt-env/env.sh' >> ~/.bashrc

# For zsh
echo 'source ~/.rt-env/env.sh' >> ~/.zshrc
```

After adding, the environment will be automatically activated each time you log in, no need to manually execute the command.

### Tutorial

**Env Tool Tutorials:**

- [Install Env with QEMU Simulator in Ubuntu](https://github.com/RT-Thread/rt-thread/blob/master/documentation/quick-start/quick_start_qemu/quick_start_qemu_linux.md)

---
## Installation Script Parameters

The following are the parameter descriptions common to all installation scripts:

| Parameter | Description |
|-----------|-------------|
| `-y`, `--yes`, `--auto` | Automatic installation, no interaction |
| `-c`, `--cn`, `--gitee` | Use China mirror sources (Gitee, PyPI TUNA) |
| `-o`, `--official` | Force use of official sources |
| `-d`, `--pyocd` | Install pyocd (for debugging) |
| `-r`, `--env-root <path>` | Set custom .rt-env directory path (overrides default `~/.rt-env`) |
| `-e`, `--en`, `--english` | Force English display |
| `-z`, `--zh`, `--chinese` | Force Chinese display |
| `-P`, `--packages <repo>[#<branch>]` | Specify packages repository address and branch, format: url[#branch] |
| `-E`, `--env <repo>[#<branch>]` | Specify env repository address and branch, format: url[#branch] |
| `-S`, `--sdk <repo>[#<branch>]` | Specify sdk repository address and branch, format: url[#branch] |
| `-b`, `--backup <strategy>` | Backup strategy: preserve (keep configs and toolchains), delete_all (delete all), backup_all (full backup) |
| `-t`, `--touch-env-url <url>` | Specify touch_env.py download URL |
| `-h`, `--help` | Display help information |
| `-p`, `--python [path]` | Install portable Python, installation directory is path (Windows only, default: D:\Tools\Python) |

**Backup Strategy Description:**

- **preserve** (default): Keep configuration files (.config) and toolchains (local_pkgs), delete other content and reinstall
- **delete_all**: Completely delete existing ENV directory, keep nothing
- **backup_all**: Create full backup, keep all content including configurations and toolchains

**Usage Examples:**

**Windows (PowerShell):**
```powershell
# Basic installation
.\install.ps1

# Use China mirror + automatic installation
.\install.ps1 -c -y

# Install portable Python
.\install.ps1 -p "D:\Tools\Python" -r "D:\RT-Env"

# Specify custom env repository branch
.\install.ps1 -E "https://github.com/RT-Thread/env.git#master"

# Install pyocd + official source
.\install.ps1 -d -o
```

**Linux/macOS (bash):**
```bash
# Basic installation
./install.sh

# Use China mirror + automatic installation
./install.sh -c -y

# Specify custom packages repository
./install.sh -P "https://gitee.com/RT-Thread/packages.git#master"

# Use backup strategy
./install.sh -b preserve

# Specify custom sdk repository
./install.sh -S "https://github.com/RT-Thread/sdk.git#master"
```

## Env Usage Guide

For detailed usage instructions, please refer to:

- [Env Tool Usage Guide](https://github.com/RT-Thread/rt-thread/blob/master/documentation/env/env.md)
- [Env Official User Manual](https://www.rt-thread.org/document/site/#/development-tools/env/env)

---
## Troubleshooting

### Mirror Connection Issues

If download is slow or fails:

- Try using `--cn` parameter to use gitee default mirror
- Check network connection

### Permission Issues (Linux/macOS)

The Linux installation script automatically uses `sudo` to install system dependencies, no need to manually execute permission-related commands.

If you encounter permission issues:

```bash
# Check .rt-env directory permissions
ls -la ~/.rt-env

# If .rt-env belongs to root user, try the following command
sudo chown -R $USER:$USER ~/.rt-env
```

### Permission Issues (Windows)

If you encounter permission errors:

1. Check if antivirus software is blocking the installation
2. The script automatically detects if administrator privileges are needed and will prompt you to run as administrator if required

---

## Related Documents

- [Env Tool Complete Documentation](https://github.com/RT-Thread/rt-thread/blob/master/documentation/env/env.md)
- [QEMU Quick Start](https://github.com/RT-Thread/rt-thread/blob/master/documentation/quick-start/quick_start_qemu/quick_start_qemu_linux.md)
- [BSP Configuration Guide](https://github.com/RT-Thread/rt-thread/blob/master/documentation/env/env.md#bsp-configuration-menuconfig)

---

## License

This project is open-sourced under the GPL-2.0 license.

---

## Related Links

- [GitHub Repository](https://github.com/RT-Thread/env)
- [RT-Thread Official Website](https://www.rt-thread.org/)
- [RT-Thread Documentation Center](https://www.rt-thread.io/document/site/)

---

## Contributors

Thanks to all developers who have contributed to the RT-Thread Env project.