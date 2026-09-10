# RT-Thread ENV 测试指南

本目录包含安装器、编排脚本与 CLI 的自动化测试脚本和手工测试步骤。

> 所有测试请在**临时目录**进行，勿使用真实 `~/.rt-env`。
> 编排脚本（install.sh/install.ps1）的参数转发测试一律用 stub 替换 `touch_env.py`；安装器本体的真实安装由 `test_touch_env_install.sh` 在隔离 `ENV_ROOT` 内覆盖。

## 自动化测试（推荐，改动后必跑）

```bash
bash tools/tests/test_install_sh.sh                    # install.sh 编排层
python tools/tests/test_touch_env_args.py              # touch_env.py 参数面
python tools/tests/test_touch_env_behavior.py          # touch_env.py 核心行为
bash tools/tests/test_touch_env_install.sh             # touch_env.py 真实安装（离线 E2E）
pwsh -NoProfile -File tools/tests/test_install_ps1.ps1 # install.ps1 编排层
pwsh -NoProfile -File tools/tests/test_install_ps1_install.ps1  # install.ps1 真实安装
```

一键全跑（离线）：

```bash
bash tools/tests/test_install_sh.sh && \
  python tools/tests/test_touch_env_args.py && \
  python tools/tests/test_touch_env_behavior.py && \
  bash tools/tests/test_touch_env_install.sh && \
  pwsh -NoProfile -File tools/tests/test_install_ps1.ps1 && \
  pwsh -NoProfile -File tools/tests/test_install_ps1_install.ps1
```

全量真实安装（需网络，真依赖 + pyocd + 真运行工具）：

```bash
RT_ENV_TEST_FULL=1 bash tools/tests/test_touch_env_install.sh
```

### 覆盖映射

| 脚本 | 覆盖 | 平台 | 本机实测 |
|---|---|---|---|
| `test_install_sh.sh` | install.sh：语法、帮助断言、`mktemp` 可移植性、参数转发（含 `--official`/`--env`/`--sdk`）、临时文件清理、`--lang` 生效 | Linux / macOS / Git Bash | 12 PASS / 0 FAIL |
| `test_touch_env_args.py` | touch_env.py：参数面（AST + `--help`）、中英消息对称、i18n 孤儿键检测、常量 | 任意 | 13 tests OK |
| `test_touch_env_behavior.py` | touch_env.py：`--keep-sdk` 三态决策（P0 回归）、`show_next_steps` 输出、`parse_repo_url`、安全删除、消息查找 | 任意 | 15 tests OK |
| `test_touch_env_install.sh` | **真实安装端到端**：离线模式（本地 bare 三源克隆 → venv → editable 元数据）；`RT_ENV_TEST_FULL=1` 全量模式（真依赖 + pyocd + 真运行 rt-env -v/--info/--help） | Linux / macOS / Git Bash | 离线 8 PASS；全量 12 PASS |
| `test_install_ps1.ps1` | install.ps1：parser、帮助断言、`--lang` 生效、清理接线；参数转发经 `RT_ENV_PS1_STUB_URL` 启用 | Windows | 10 PASS / 0 FAIL / 1 SKIP |
| `test_install_ps1_install.ps1` | **install.ps1 真实安装端到端**：本地 bare 三源 + 本地 HTTP 服务提供 touch_env.py；离线模式（PIP_NO_DEPS）；`RT_ENV_TEST_FULL=1` 全量（真依赖 + pyocd + 真运行 rt-env） | Windows | 离线 8 PASS；全量 12 PASS |

### 约定

- 输出 `PASS/FAIL/SKIP` 行；有 `FAIL` 时退出码非 0。`SKIP` 表示前置条件缺失（无可用 `python3`、未配置 HTTP stub、未开启 FULL 模式等），**不算失败**。
- 负向验证：曾分别注入 `mktemp --suffix`（macOS 缺陷）、`--keep-sdk no` 字符串真值（P0）、损坏的 `VENV_DIR_RELATIVE`（touch_env 与 install.ps1 两条真实安装链各一次）共四处缺陷，确认对应套件正确变红，恢复后回到全绿。
- 行尾（`.gitattributes`）：`*.sh` 用 **LF**；`*.ps1` 用 **CRLF + UTF-8 BOM**（PowerShell 5.1 中文输出需要）；其余文本默认 **LF**。

---

## 1. 安装器手工测试（touch_env.py）

命令：`python tools/touch_env.py [OPTIONS]`

### 1.1 参数面检查

```bash
python tools/touch_env.py --help
```

预期：无 `--install-pyocd`、`--backup`、`--restore-config`（已删除）；存在 `--keep-sdk {yes,no}`、`--env-root`、`--use-cn`、`--language`、`--auto-mode`、`--repo-env`、`--repo-packages`、`--repo-sdk`。

### 1.2 保留工具链交互

```bash
python tools/touch_env.py --env-root <临时目录> --language zh
```

- 首次安装（目录不存在）：不出现询问，直接安装
- 重复安装（目录已存在）：出现「保留已下载的工具链（local_pkgs）与配置？[Y/n]」
- 回车/Y：`local_pkgs/` 与 `tools/scripts/cmds/.config` 保留，`venv/`、`tools/scripts/`、`packages/` 被清理重装
- n：整个目录删除后全新安装

### 1.3 `--keep-sdk` 参数化测试（重点）

预置标记文件后重装：

```bash
mkdir -p <tmp>/local_pkgs && echo marker > <tmp>/local_pkgs/toolchain.marker
echo config > <tmp>/tools/scripts/cmds/.config   # 如已存在则跳过

# 保留：marker 存活，venv 重建
python tools/touch_env.py --env-root <tmp> --keep-sdk yes --auto-mode
test -f <tmp>/local_pkgs/toolchain.marker && echo KEEP-OK

# 全新：marker 消失
python tools/touch_env.py --env-root <tmp> --keep-sdk no --auto-mode
test ! -f <tmp>/local_pkgs/toolchain.marker && echo WIPE-OK
```

预期：分别输出 `KEEP-OK`、`WIPE-OK`；`--auto-mode` 下不出现任何交互（默认保留并打印 auto-mode 提示）。

> 此场景已由 `test_touch_env_behavior.py` 的 `CheckExistingEnvTest` 自动覆盖（含 P0 回归用例）。

### 1.4 pyocd 直装验证

```bash
python tools/touch_env.py --env-root <tmp> --auto-mode
```

预期：安装完成后 `<tmp>/venv/rt-env/Scripts/pyocd.exe`（Windows）或 `<tmp>/venv/rt-env/bin/pyocd`（POSIX）存在。

### 1.5 非官方仓库测试（fork/镜像源）

本地 bare 仓库模拟（离线可控）：

```bash
git init --bare /tmp/env.git
git push /tmp/env.git install-unified   # 从本仓库推送
```

单源自定义：

```bash
python tools/touch_env.py --env-root <tmp> --repo-env file:///tmp/env.git
```

预期：日志出现「使用自定义仓库: …」（`using_custom_repo`）；`git -C <tmp>/tools/scripts remote -v` 指向 `file:///tmp/env.git`。

分支片段：

```bash
python tools/touch_env.py --env-root <tmp> --repo-env file:///tmp/env.git#install-unified
```

预期：日志含分支名（`using_custom_repo_branch`），克隆后 HEAD 在 `install-unified`。

三源全自定义 + 一键（CI 友好）：

```bash
python tools/touch_env.py --env-root <tmp> --auto-mode \
  --repo-env file:///tmp/env.git#install-unified \
  --repo-packages file:///tmp/packages.git \
  --repo-sdk file:///tmp/sdk.git
```

GitHub fork 场景（需网络）：

```bash
python tools/touch_env.py --env-root <tmp> --repo-env https://github.com/<user>/env.git#<branch>
```

编排脚本转发链（长参数透传）：

```bash
bash tools/install.sh --env-root <tmp> --keep-sdk no --auto --touch-env file:///path/to/touch_env.py
```

预期：`install.sh --help` 无任何单字母短参数；上述参数原样传递给 `touch_env.py`。

### 1.6 真实安装端到端（自动化）

`test_touch_env_install.sh` 真跑完整安装流程，全程隔离；默认离线，全量模式走网络：

1. 在临时目录创建三个本地 bare 仓库（env 由本仓库 `push` 生成，packages/sdk 为空仓库并把 HEAD 指向 master）
2. 以 `--repo-env/--repo-packages/--repo-sdk` 指向本地源、`--auto-mode --keep-sdk yes` 运行 `touch_env.py`
3. 断言产物：三个仓库克隆到位、`venv/rt-env` 创建、`rt-env` 入口存在、`importlib.metadata` 解析出 `rt-env 2.0.2`

```bash
bash tools/tests/test_touch_env_install.sh
```

要点：
- 设 `PIP_NO_DEPS=1` 使 venv 引导不下载第三方依赖（editable 元数据仍可解析），保证离线可跑
- 全程在临时 `ENV_ROOT` 内，绝不触碰真实 `~/.rt-env`；结束自动清理
- 空仓库的 `HEAD` 需显式指向被推入的分支（`git symbolic-ref HEAD refs/heads/master`），否则 `git clone` 得到空工作树

**全量模式（真正的真实安装，需网络）**：

```bash
RT_ENV_TEST_FULL=1 bash tools/tests/test_touch_env_install.sh
```

与离线模式的差异：
- **安装全部第三方依赖**（SCons/requests/psutil/tqdm/kconfiglib/pyyaml）与 **pyocd**，真实走网络
- **真运行已安装的工具**：`rt-env -v`（单行版本号）、`rt-env --info`（环境横幅）、`rt-env --help`（usage + webui 子命令）
- 断言 12 项（离线 8 项 + pyocd/运行时 4 项）；耗时较长（依赖下载）

---

## 2. 激活器手工测试（env.sh / env.ps1）

隔离布局（Windows junction 示例）：

```powershell
$d = "<tmp>"; New-Item -ItemType Directory -Force $d
Copy-Item env.ps1 $d\
cmd /c mklink /J "$d\venv" "<real-env>\venv"   # venv\<name>\Scripts\Activate.ps1 可达
pwsh -NoProfile -File $d\env.ps1
```

预期：出现 `rt-env --info` 青色欢迎横幅；无 venv 时输出 "Virtual environment ... not found" 并 `exit 1`。

POSIX 侧：

```bash
bash -n env.sh                       # 语法检查
bash --posix -n env.sh               # POSIX 兼容
source ./env.sh                      # venv 缺失时: 报错 + return 1
```

---

## 3. CLI 手工测试

```bash
rt-env -v            # 预期: 单行版本号 "RT-Thread Env Tool v2.0.2"
rt-env --info        # 预期: 环境信息横幅（ENV_ROOT/PKGS_ROOT 等）
rt-env --help        # 预期: usage 显示 "rt-env"（非 python.exe 全路径），含 plugin/webui 子命令
rt-env plugin --help # 预期: plugin 子命令帮助
rt-env webui --help  # 预期: webui 子命令帮助
rt-env --info menuconfig   # 预期: 横幅后退出，不执行 menuconfig（短路）
```

---

## 4. 打包手工测试

```bash
python -m pip wheel --no-deps -w <tmp> .
```

一次性 venv 安装验证：

```bash
python -m venv <tmp>/qa_venv
<tmp>/qa_venv/Scripts/python -m pip install --no-deps <tmp>/rt_env-*.whl
# 验证:
#   importlib.metadata.version('rt-env')  -> 2.0.2（来自 env.json）
#   Scripts/ 下 6 个入口（rt-env/menuconfig/pkgs/sdk/system/webui）齐全
#   site-packages/env/plugins/webui/static/index.html 存在
```

editable 冒烟（勿动真实环境）：

```bash
python -m venv <tmp>/qa_editable
<tmp>/qa_editable/Scripts/python -m pip install -e .
```

预期：安装成功，`rt-env -v` 输出与 env.json 一致的版本号。

---

## 5. 编排脚本手工测试（install.sh / install.ps1）

`tools/install.sh` 与 `tools/install.ps1` 是编排层：下载 `touch_env.py` 并把参数转发给它。

> ⚠️ 除 `--help` / `-h` 外，任何参数都会进入真实安装流程。测试参数转发时务必用 **stub** 替换 `touch_env.py`，不要直接运行真实安装。

### 5.1 语法与帮助（静态，安全）

```bash
bash -n tools/install.sh
bash --posix -n tools/install.sh
bash tools/install.sh --help
```

断言：无单字母短参数（`-h` 除外）；含 `--keep-sdk`；不含 `--english`/`--chinese`/`--pyocd`/`--backup`。

```powershell
$errs = $null
[System.Management.Automation.PSParser]::Tokenize((Get-Content tools/install.ps1 -Raw), [ref]$errs) | Out-Null
$errs.Count          # 预期 0
pwsh -NoProfile -File tools/install.ps1 -h
```

同上断言（中英两份帮助输出各校验一次）。

### 5.2 参数转发（install.sh → touch_env.py）

用 stub 替代真实安装：

```bash
cat > /tmp/stub_touch_env.py <<'EOF'
import sys
print("ARGS: " + " ".join(sys.argv[1:]))
EOF

bash tools/install.sh --touch-env "file:///tmp/stub_touch_env.py" \
  --env-root /tmp/rt-env-test --cn --yes --keep-sdk no \
  --packages "https://example.com/p.git#dev"
```

预期输出（实测样例）：

```
ARGS: --env-root /tmp/rt-env-test --use-cn --language zh --auto-mode --keep-sdk no --repo-packages https://example.com/p.git#dev
```

要点：
- `--cn` 同时把语言设为 `zh`
- 长参数按原样转发；带空格/片段的仓库 URL 保持完整（数组传递，无拆词）

Windows Git Bash 适配：
- `install.sh` 面向 Linux/macOS；Windows 使用 `install.ps1`。在 Git Bash 下测试需 **PATH 上有可用的 `python3`**——Windows 自带的 `python3` 常是微软商店占位符（`python3 --version` 无输出）。可建包装脚本 shim：
  ```bash
  printf '#!/bin/sh\nexec "/c/Path/To/python.exe" "$@"\n' > /tmp/bin/python3 && chmod +x /tmp/bin/python3
  PATH="/tmp/bin:$PATH" bash tools/install.sh ...
  ```
- `curl` 为 Windows 原生程序，`file://` 需 Windows 路径：`file:///C:/Users/.../stub_touch_env.py`（MSYS 的 `/tmp/...` 不可见）
- `--touch-env` 的 `file://` 仅用于离线测试；真实安装走 http(s)

### 5.3 install.ps1 参数转发（可选，需本地 HTTP stub）

`Invoke-WebRequest` 不支持 `file://`，需本地 HTTP 服务：

```powershell
New-Item -ItemType Directory -Force $env:TEMP\stub | Out-Null
Set-Content $env:TEMP\stub\stub_touch_env.py 'import sys; print("ARGS: " + " ".join(sys.argv[1:]))'
Start-Process python -ArgumentList "-m","http.server","8765" -WorkingDirectory $env:TEMP\stub
pwsh -NoProfile -File tools/install.ps1 --touch-env http://127.0.0.1:8765/stub_touch_env.py --yes
```

> ⚠️ 该路径会经过 `Ensure-Python` / `Ensure-Git` / Windows 环境初始化，**可能需要管理员权限**。若不便，完成 5.1 与 5.4 即可。

### 5.4 临时文件清理验证（回归）

`install.sh`（`trap` + 裸 `mktemp`，macOS 兼容）：

```bash
before=$(ls /tmp/tmp.* 2>/dev/null | sort)
bash tools/install.sh --touch-env "file:///tmp/stub_touch_env.py" --yes
after=$(ls /tmp/tmp.* 2>/dev/null | sort)
test -z "$(comm -13 "$before" "$after")" && echo CLEANUP-OK
```

预期：`CLEANUP-OK`（临时文件随退出删除，无新增残留）。

`install.ps1`（唯一名 + `finally` 即时清理）：

```powershell
Get-ChildItem $env:TEMP -Filter 'touch_env_*.py'   # 安装结束后预期为空
```

并发安全：两次安装使用不同 GUID 文件名，互不覆盖。

代码级确认点：
- `install.sh`: `touch_env_dest=$(mktemp)`（无 `--suffix`）+ `trap cleanup EXIT INT TERM`
- `install.sh` sudo 分支：`chmod a+r` + `sudo -u "$REAL_USER" python3 <file> "${python_args[@]}"`（数组传递）
- `install.ps1`: `touch_env_<GUID>.py` + `try/finally` 立即删除，退出事件兜底

### 5.5 平台与权限矩阵

| 测试 | 自动化脚本 | Windows Git Bash | Linux | macOS | 说明 |
|---|---|---|---|---|---|
| 一键全跑（离线） | 六个脚本全跑 | ✅ 需 pwsh | ✅ | ✅ | 改动后推荐 |
| 语法与帮助 | `test_install_sh.sh` §1–2、`test_install_ps1.ps1` §1–2 | ✅ | ✅ | ✅ | 安全，每次改动必跑 |
| sh 参数转发（stub） | `test_install_sh.sh` §4 | ⚠️ 自动建 python3 shim | ✅ | ✅ | 需 git + python3 + curl/wget |
| ps1 参数转发 | `test_install_ps1.ps1` §4（`RT_ENV_PS1_STUB_URL`） | ⚠️ 需管理员 | — | — | 仅 Windows |
| 清理回归 | `test_install_sh.sh` §3+§5、`test_install_ps1.ps1` §3 | ✅ | ✅ | ✅ | macOS 关键回归点 |
| 参数面与行为 | `test_touch_env_args.py` + `test_touch_env_behavior.py` | ✅ | ✅ | ✅ | AST + 行为，无副作用 |
| 真实安装（离线） | `test_touch_env_install.sh`、`test_install_ps1_install.ps1` | ✅ | ✅ | ✅ | 本地 bare 三源，无网络 |
| 真实安装（全量） | 上述两个脚本 + `RT_ENV_TEST_FULL=1` | ✅ | ✅ | ✅ | 需网络：真依赖 + pyocd + 真运行 |

> 本机实测（2026-09-10）：sh 套件 12 PASS/0 FAIL；args 套件 13 OK；behavior 套件 15 OK；install 套件（touch_env）离线 8 PASS、全量 12 PASS；install 套件（install.ps1）离线 8 PASS、全量 12 PASS；ps1 套件 10 PASS/0 FAIL/1 SKIP（参数转发需管理员）。四处负向验证通过（注入缺陷 → 变红，恢复 → 全绿）。

### 5.6 install.ps1 真实安装端到端（自动化）

`test_install_ps1_install.ps1` 真跑 `install.ps1` 完整流程，隔离、默认离线：

1. 本地 bare 三源（env 由本仓库 push，packages/sdk 为空仓库）
2. 本地 HTTP 服务提供真实 `touch_env.py`（`Invoke-WebRequest` 不支持 `file://`）
3. `install.ps1 --touch-env <url> --env-root <tmp> --yes --keep-sdk yes --env/--packages/--sdk <file://...>`
4. 断言：退出码 0、三仓库克隆、`venv/rt-env`、`rt-env.exe`、editable 元数据（`rt-env 2.0.2`）

```powershell
pwsh -NoProfile -File tools/tests/test_install_ps1_install.ps1
# 全量（真依赖 + pyocd + 真运行 rt-env -v/--info/--help，需网络）
$env:RT_ENV_TEST_FULL=1; pwsh -NoProfile -File tools/tests/test_install_ps1_install.ps1
```

要点：
- **参数名**：install.ps1 收 `--env/--packages/--sdk`（转发给 touch_env.py 时才变成 `--repo-*`）；传错名会被静默忽略并回落到默认镜像源
- **提权**：仅当执行策略或长路径需更改时才要求管理员。本机两者已满足，免提权。若你的机器需提权，可用 Windows 内置 `sudo`：
  ```powershell
  sudo pwsh -NoProfile -File tools/tests/test_install_ps1_install.ps1
  ```
- 全程在临时 `ENV_ROOT` 内，结束自动清理（含 HTTP 服务作业）

> macOS 提示：完整安装必须验证语法/转发/清理——此前的 `mktemp --suffix` 缺陷会让 macOS 安装直接失败。

---

## 6. 安全注意

- 安装器下载并执行远程 `touch_env.py`，无完整性校验。`--touch-env` 可指向任意 URL——**仅使用可信来源**。
- 临时文件：`install.sh` 用随机名并随脚本退出清理（`trap`）；`install.ps1` 用唯一名并在运行后立即清理（`finally`），退出事件兜底。

---

## 7. 验证后清理

```powershell
Remove-Item -Recurse -Force <tmp>          # 删除全部临时目录
```

勿遗留：临时 venv、junction、bare 仓库、wheel 输出目录、`%TEMP%`/`/tmp` 下的 stub 与 shim。
