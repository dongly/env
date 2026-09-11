# RT-Thread ENV 测试指南

本目录的测试覆盖安装器（`touch_env.py`）、编排脚本（`install.sh` / `install.ps1`）、激活器（`env.sh` / `env.ps1`）与 CLI（`rt-env`）。

> 所有测试均在**临时目录**进行，绝不触碰真实 `~/.rt-env`。

## 1. 快速开始

```bash
# 一键全跑（离线，无需网络）
bash tools/tests/run_all.sh

# 全量真实安装（需网络：真依赖 + pyocd + 真运行工具）
RT_ENV_TEST_FULL=1 bash tools/tests/run_all.sh
```

逐个运行（等价于 run_all.sh 的内容）：

```bash
bash tools/tests/test_install_sh.sh                     # install.sh 编排层（stub）
python tools/tests/test_touch_env_args.py               # touch_env.py 参数面
python tools/tests/test_touch_env_behavior.py           # touch_env.py 核心行为
bash tools/tests/test_touch_env_install.sh              # touch_env.py 真实安装 E2E
pwsh -NoProfile -File tools/tests/test_install_ps1.ps1  # install.ps1 编排层（stub）
pwsh -NoProfile -File tools/tests/test_install_ps1_install.ps1  # install.ps1 真实安装 E2E
```

> 每个脚本输出 `PASS/FAIL/SKIP` 行；存在 `FAIL` 时退出码非 0。`SKIP` 表示前置条件缺失，不算失败。

## 2. 测试套件一览

| 脚本 | 被测对象 | 覆盖范围 | 平台 |
|---|---|---|---|
| `test_install_sh.sh` | install.sh | 语法、帮助断言、`mktemp` 可移植性、参数转发（stub）、临时文件清理、`--lang` 生效 | Linux / macOS / Git Bash |
| `test_touch_env_args.py` | touch_env.py | 参数面（`--help` + AST）、中英消息对称、i18n 孤儿键、常量 | 任意 |
| `test_touch_env_behavior.py` | touch_env.py | `--keep-sdk` 三态（含 P0 回归）、`show_next_steps` 输出、`parse_repo_url`、安全删除、消息查找 | 任意 |
| `test_touch_env_install.sh` | touch_env.py | **真实安装**：本地 bare 三源 → 克隆 → venv → editable | Linux / macOS / Git Bash |
| `test_install_ps1.ps1` | install.ps1 | parser、帮助断言、`--lang` 生效、清理接线 | Windows |
| `test_install_ps1_install.ps1` | install.ps1 | **真实安装**：本地 HTTP 服务 + 本地 bare 三源 → 完整编排链 | Windows |

### 2.1 模式：离线 vs 全量

真实安装套件（`test_touch_env_install.sh`、`test_install_ps1_install.ps1`）支持两种模式：

| 模式 | 依赖安装 | pyocd | 真运行工具 | 网络 |
|---|---|---|---|---|
| 默认（离线） | 跳过（`PIP_NO_DEPS=1`） | ✗ | ✗ | 不需要 |
| `RT_ENV_TEST_FULL=1` | ✅ 全装 | ✅ | ✅ `-v`/`--info`/`--help` | 需要 |

```bash
bash tools/tests/test_touch_env_install.sh               # 离线
RT_ENV_TEST_FULL=1 bash tools/tests/test_touch_env_install.sh  # 全量
```

## 3. 真实安装测试（E2E，核心）

两条 E2E 链：`install.sh`（POSIX）与 `install.ps1`（Windows）各有对应的**编排层 stub 测试**（参数转发）和**真实安装测试**（跑完整流程）。

### 3.1 `test_touch_env_install.sh`（touch_env.py 直接安装）

```bash
bash tools/tests/test_touch_env_install.sh
```

1. 临时目录建三个本地 bare 仓库（env 由本仓库 push；packages/sdk 空仓库，HEAD 指向 master）
2. `touch_env.py --repo-* <file://本地源> --auto-mode --keep-sdk yes`
3. 断言：三仓库克隆、`venv/rt-env`、`rt-env` 入口、`importlib.metadata` 解析出 `rt-env 2.0.2`

要点：
- `PIP_NO_DEPS=1` 保证离线；全量模式（`RT_ENV_TEST_FULL=1`）装真依赖 + pyocd 并真运行工具
- 空仓库 `HEAD` 需 `git symbolic-ref HEAD refs/heads/master`，否则 `git clone` 得空工作树

### 3.2 `test_install_ps1_install.ps1`（install.ps1 完整编排链）

```powershell
pwsh -NoProfile -File tools/tests/test_install_ps1_install.ps1
$env:RT_ENV_TEST_FULL=1; pwsh -NoProfile -File tools/tests/test_install_ps1_install.ps1
```

1. 本地 bare 三源 + 本地 HTTP 服务提供真实 `touch_env.py`（`Invoke-WebRequest` 不支持 `file://`）
2. `install.ps1 --touch-env <url> --env-root <tmp> --yes --keep-sdk yes --env/--packages/--sdk <file://...>`
3. 断言：退出码 0、三仓库克隆、`venv/rt-env`、`rt-env.exe`、editable 元数据

要点：
- **参数名**：install.ps1 收 `--env/--packages/--sdk`（转发给 touch_env.py 时才变 `--repo-*`）；传错名会被静默忽略并回落到默认镜像源
- **提权**：仅当执行策略或长路径需修改时才要求管理员。本机两者已满足，免提权。需提权时：
  ```powershell
  sudo pwsh -NoProfile -File tools/tests/test_install_ps1_install.ps1
  ```

## 4. 手工测试（辅助验证）

自动化套件覆盖了绝大多数断言，下列步骤用于**需要人工观察行为**的场景。

### 4.1 安装器交互（touch_env.py）

```bash
python tools/touch_env.py --env-root <临时目录> --language zh
```

- 首次安装：直接安装，无询问
- 重装：出现「保留已下载的工具链（local_pkgs）与配置？[Y/n]」——回车/Y 保留 `local_pkgs/` 与 `cmds/.config` 并清理重装；n 整个目录删除
- `--keep-sdk yes|no` 参数化验证见 behavior 套件（已自动覆盖）

### 4.2 激活器（env.sh / env.ps1）

```bash
bash -n env.sh && bash --posix -n env.sh     # 语法 + POSIX 兼容
source ./env.sh                              # venv 缺失时：报错 + return 1
```

PowerShell 隔离布局（junction）验证 `rt-env --info` 横幅与"not found"错误路径。

### 4.3 CLI（rt-env）

```bash
rt-env -v            # 单行版本号 "RT-Thread Env Tool v2.0.2"
rt-env --info        # 环境信息横幅
rt-env --help        # usage 显示 "rt-env"，含 plugin/webui 子命令
rt-env --info menuconfig   # 横幅后退出（短路）
```

### 4.4 打包（wheel）

```bash
python -m pip wheel --no-deps -w <tmp> .
# 一次性 venv 安装：验证 6 个入口 + webui 静态资源 + metadata
```

### 4.5 编排脚本参数转发（stub）

用 stub 替换 `touch_env.py`，验证参数透传：

```bash
cat > /tmp/stub_touch_env.py <<'EOF'
import sys
print("ARGS: " + " ".join(sys.argv[1:]))
EOF

bash tools/install.sh --touch-env "file:///tmp/stub_touch_env.py" \
  --env-root /tmp/rt-env-test --cn --yes --keep-sdk no \
  --packages "https://example.com/p.git#dev"
# 预期 ARGS: --env-root ... --use-cn --language zh --auto-mode --keep-sdk no --repo-packages ...
```

- `--cn` 同时设语言为 `zh`
- 长参数原样转发；URL 片段保持完整（数组传递无拆词）

> Windows Git Bash：`python3` 常是商店占位符（`--version` 无输出），需包装脚本 shim；原生 `curl` 的 `file://` 用 Windows 路径（`file:///C:/...`）。

### 4.6 临时文件清理

- `install.sh`：随机名 + `trap cleanup EXIT INT TERM`，退出即删（含 Ctrl-C）
- `install.ps1`：`touch_env_<GUID>.py` + `try/finally` 立即删 + 退出事件兜底
- 回归验证：运行前后 `ls /tmp/tmp.*` 差集为空 / `%TEMP%` 无 `touch_env_*.py` 残留

## 5. 约定与注意

- **行尾**（`.gitattributes`）：`*.sh` 用 LF；`*.ps1` 用 CRLF + UTF-8 BOM（PowerShell 5.1 中文输出需要）；其余文本默认 LF
- **负向验证**：注入已知缺陷（`mktemp --suffix`、`--keep-sdk no` 字符串真值、损坏的 `VENV_DIR_RELATIVE`）确认套件变红，恢复后全绿——证明测试有效而非假绿
- **macOS**：`mktemp --suffix` 是 GNU 扩展、macOS 不支持——安装器已用裸 `mktemp`，回归测试必须跑
- **安全**：安装器下载并执行远程 `touch_env.py`，无完整性校验。`--touch-env` 可指向任意 URL——仅使用可信来源

## 6. 验证后清理

```bash
Remove-Item -Recurse -Force <tmp>
```

勿遗留：临时 venv、junction、bare 仓库、wheel 输出、`%TEMP%`/`/tmp` 下的 stub 与 shim。
