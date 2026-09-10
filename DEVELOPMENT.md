# RT-Thread ENV 开发文档 / Development Guide

本文档面向开发者，说明如何用命令行参数实测安装器、激活器与 CLI 的行为。
This document explains how to exercise the installer, activation scripts, and CLI with command-line parameters.

> 所有测试请在**临时目录**进行，勿使用真实 `~/.rt-env`。
> Run all tests against a **temporary directory** — never your real `~/.rt-env`.

---

## 1. 安装器测试 / Installer Tests

命令：`python tools/touch_env.py [OPTIONS]`
Command: `python tools/touch_env.py [OPTIONS]`

### 1.1 参数面检查 / Parameter surface check

```bash
python tools/touch_env.py --help
```

预期结果 / Expected:

- 无 `--install-pyocd`、`--backup`、`--restore-config`（已删除）
- No `--install-pyocd`, `--backup`, `--restore-config` (removed)
- 存在 `--keep-toolchain {yes,no}`、`--env-root`、`--use-cn`、`--language`、`--auto-mode`、`--repo-env`、`--repo-packages`、`--repo-sdk`
- `--keep-toolchain {yes,no}`, `--env-root`, `--use-cn`, `--language`, `--auto-mode`, `--repo-env`, `--repo-packages`, `--repo-sdk` are present

### 1.2 保留工具链交互 / Keep-toolchain prompt

```bash
python tools/touch_env.py --env-root <临时目录> --language zh
```

- 首次安装（目录不存在）：不出现询问，直接安装
- 重复安装（目录已存在）：出现"保留已下载的工具链（local_pkgs）与配置？[Y/n]"
- 回车/Y：`local_pkgs/` 与 `tools/scripts/cmds/.config` 保留，`venv/`、`tools/scripts/`、`packages/` 被清理重装
- n：整个目录删除后全新安装

Expected on reinstall: prompt `[Y/n]` (default `Y` keeps `local_pkgs/` and `cmds/.config`; `n` wipes the directory).

### 1.3 `--keep-toolchain` 参数化测试（重点）/ Parameterized keep-toolchain test

预置标记文件后重装 / Seed a marker, then reinstall:

```bash
mkdir -p <tmp>/local_pkgs && echo marker > <tmp>/local_pkgs/toolchain.marker
echo config > <tmp>/tools/scripts/cmds/.config   # 如已存在则跳过

# 保留：marker 存活，venv 重建
python tools/touch_env.py --env-root <tmp> --keep-toolchain yes --auto-mode
test -f <tmp>/local_pkgs/toolchain.marker && echo KEEP-OK

# 全新：marker 消失
python tools/touch_env.py --env-root <tmp> --keep-toolchain no --auto-mode
test ! -f <tmp>/local_pkgs/toolchain.marker && echo WIPE-OK
```

预期：分别输出 `KEEP-OK`、`WIPE-OK`；`--auto-mode` 下不出现任何交互（默认保留并打印 auto-mode 提示）。
Expect `KEEP-OK` then `WIPE-OK`; with `--auto-mode` no prompt appears (defaults to keep, logs an auto-mode notice).

### 1.4 pyocd 直装验证 / pyocd installed by default

```bash
python tools/touch_env.py --env-root <tmp> --auto-mode
```

预期：安装完成后 `<tmp>/venv/rt-env/Scripts/pyocd.exe`（Windows）或 `<tmp>/venv/rt-env/bin/pyocd`（POSIX）存在。
Expect the pyocd executable inside the venv after installation.

### 1.5 非官方仓库测试（fork/镜像源）/ Custom repository sources

本地 bare 仓库模拟（离线可控）/ Simulate with a local bare repo (offline-friendly):

```bash
git init --bare /tmp/env.git
git push /tmp/env.git install-unified   # 从本仓库推送
```

单源自定义 / Single custom source:

```bash
python tools/touch_env.py --env-root <tmp> --repo-env file:///tmp/env.git
```

预期：日志出现"使用自定义仓库: …"（`using_custom_repo`）；`git -C <tmp>/tools/scripts remote -v` 指向 `file:///tmp/env.git`。
Expect the custom-repo log line and the cloned `tools/scripts` remote pointing at your URL.

分支片段 / Branch fragment:

```bash
python tools/touch_env.py --env-root <tmp> --repo-env file:///tmp/env.git#install-unified
```

预期：日志含分支名（`using_custom_repo_branch`），克隆后 HEAD 在 `install-unified`。
Expect the branch in the log and the clone HEAD on that branch.

三源全自定义 + 一键（CI 友好）/ All three sources + one-shot (CI-friendly):

```bash
python tools/touch_env.py --env-root <tmp> --auto-mode \
  --repo-env file:///tmp/env.git#install-unified \
  --repo-packages file:///tmp/packages.git \
  --repo-sdk file:///tmp/sdk.git
```

GitHub fork 场景（需网络）/ GitHub fork (network required):

```bash
python tools/touch_env.py --env-root <tmp> --repo-env https://github.com/<user>/env.git#<branch>
```

编排脚本转发链（长参数透传）/ Orchestrator pass-through:

```bash
bash tools/install.sh --env-root <tmp> --keep-toolchain no --auto --touch-env-url file:///path/to/touch_env.py
```

预期：`install.sh --help` 无任何单字母短参数；上述参数原样传递给 `touch_env.py`。
Expect long-only options in `install.sh --help` and faithful pass-through.

---

## 2. 激活器测试 / Activation Script Tests

隔离布局（Windows junction 示例）/ Isolated layout (Windows junction example):

```powershell
$d = "<tmp>"; New-Item -ItemType Directory -Force $d
Copy-Item env.ps1 $d\
cmd /c mklink /J "$d\venv" "<real-env>\venv"   # venv\<name>\Scripts\Activate.ps1 可达
pwsh -NoProfile -File $d\env.ps1
```

预期：出现 `rt-env --info` 青色欢迎横幅；无 venv 时输出 "Virtual environment ... not found" 并 `exit 1`。
Expect the `rt-env --info` banner after activation; the not-found error with exit code 1 without a venv.

POSIX 侧 / POSIX side:

```bash
bash -n env.sh                       # 语法检查 / syntax check
bash --posix -n env.sh               # POSIX 兼容 / POSIX compatibility
source ./env.sh                      # venv 缺失时: 报错 + return 1
```

---

## 3. CLI 测试 / CLI Tests

```bash
rt-env -v            # 预期: 单行版本号 "RT-Thread Env Tool v2.0.2" / one-line version
rt-env --info        # 预期: 环境信息横幅（ENV_ROOT/PKGS_ROOT 等）/ environment banner
rt-env --help        # 预期: usage 显示 "rt-env"（非 python.exe 全路径），含 plugin/webui 子命令
rt-env plugin --help # 预期: plugin 子命令帮助 / plugin subcommand help
rt-env webui --help  # 预期: webui 子命令帮助 / webui subcommand help
rt-env --info menuconfig   # 预期: 横幅后退出，不执行 menuconfig / banner then exit (short-circuit)
```

---

## 4. 打包测试 / Packaging Tests

```bash
python -m pip wheel --no-deps -w <tmp> .
```

一次性 venv 安装验证 / Throwaway-venv install check:

```bash
python -m venv <tmp>/qa_venv
<tmp>/qa_venv/Scripts/python -m pip install --no-deps <tmp>/rt_env-*.whl
# 验证 / verify:
#   importlib.metadata.version('rt-env')  -> 2.0.2（来自 env.json）
#   Scripts/ 下 6 个入口（rt-env/menuconfig/pkgs/sdk/system/webui）齐全
#   site-packages/env/plugins/webui/static/index.html 存在
```

editable 冒烟（勿动真实环境）/ Editable smoke (never against the real env):

```bash
python -m venv <tmp>/qa_editable
<tmp>/qa_editable/Scripts/python -m pip install -e .
```

预期：安装成功，`rt-env -v` 输出与 env.json 一致的版本号。
Expect a successful install and `rt-env -v` matching env.json.

---

## 5. 验证后清理 / Cleanup

```bash
Remove-Item -Recurse -Force <tmp>          # 删除全部临时目录 / remove temp dirs
```

勿遗留：临时 venv、junction、bare 仓库、wheel 输出目录。
Leave nothing behind: temp venvs, junctions, bare repos, wheel outputs.
