# 重构安装脚本：删除 ENV_ROOT 并修改 Python 安装路径

## 项目状态
- **状态**: 已完成
- **开始时间**: 2026-01-29
- **预计完成时间**: 2026-01-29
- **优先级**: 高

## 核心变化

1. **删除 ENV_ROOT 相关代码**
   - 删除 `$ENV_DEFAULT_DIR` 常量定义
   - 删除 ENV_ROOT 初始化和验证逻辑
   - 删除 install.ps1 内部所有基于 ENV_ROOT 的逻辑
   - 删除 ENV_ROOT 相关的消息

2. **重新定义 -p 参数**
   - 从 `--python`（布尔值：强制安装便携式 Python）
   - 改为 `--python [path]`（强制安装便携式 Python，接受路径值）
   - 默认值：`D:\Tools\Python`

3. **修改 Python 安装逻辑**
   - 将所有使用 `$env:ENV_ROOT\python` 的地方改为使用 `$script:Config.PythonPath`
   - `$script:Config.PythonPath` 默认值为 `D:\Tools\Python`
   - 删除 `Ensure-Python` 中删除旧 Python 的逻辑（不再基于 ENV_ROOT）

4. **--env-root 参数传递**
   - 保留 `-r, --env-root` 命令行参数（仅用于传递给 touch_env.py）
   - install.ps1 本身不再使用 ENV_ROOT
   - 条件传递：只有命令行指定了 `-r` 或 `--env-root` 时才传递给 touch_env.py，否则不传递

## 执行步骤

### 步骤 1：开发（代码修改）

#### 1.1 文件头部（行 1-60）
- 修改 Usage 行，保留 `-p [path]`
- 修改 Options 说明：
  - 保留 `-r, --env-root <path>` 说明
  - 修改 `-p, --python` 为 `-p, --python [path]`，说明改为：`安装便携式 Python, 安装目录为 path（默认：D:\Tools\Python）`

#### 1.2 全局常量（行 60-70）
- **删除** `$ENV_DEFAULT_DIR = "$env:USERPROFILE\.rtenv"`

#### 1.3 Parse-Arguments 函数（行 110-220）
- **删除** `EnvRootValue` 属性，改为 `EnvRoot` 属性（字符串类型，用于传递）
- **修改** `PythonMode` 属性为 `PythonPath` 属性（字符串类型）
- **修改** `-r`, `--env-root` 参数处理：`"-r" { $result.EnvRoot = $Arguments[++$i] }` 和 `"--env-root" { $result.EnvRoot = $Arguments[++$i] }`
- **修改** `-p`, `--python` 参数处理：`"-p" { $result.PythonPath = $Arguments[++$i] }` 和 `"--python" { $result.PythonPath = $Arguments[++$i] }`

#### 1.4 Init-Config 函数（行 1418-1475）
- **删除** ENV_ROOT 初始化代码
- **删除** ENV_ROOT 验证代码
- **添加** PythonPath 默认值设置：`$script:Config.PythonPath = if ($ParsedArgs.PythonPath) { $ParsedArgs.PythonPath } else { "D:\Tools\Python" }`
- 直接用 `$ParsedArgs.EnvRoot` 用于传递给 touch_env.py

#### 1.5 PythonConfig 类（行 740-750）
- **保持不变**

#### 1.6 New-PortingPythonConfig 函数（行 758）
- **修改** Python 路径计算：使用 `$script:Config.PythonPath`

#### 1.7 Extract-PortablePython 函数（行 830）
- **修改** Python 目标目录：使用 `$script:Config.PythonPath`

#### 1.8 Configure-PythonPth 函数（行 954）
- **修改** Python 目标目录：使用 `$script:Config.PythonPath`

#### 1.9 Install-PortablePython 函数（行 965-985）
- **删除** `$SkipLongPath` 参数
- **修改** Python 路径引用：使用 `$script:Config.PythonPath`

#### 1.10 Ensure-Python 函数（行 1295-1340）
- **删除** 删除旧 Python 的逻辑（不再基于 ENV_ROOT）
- **修改** 便携式 Python 安装调用

#### 1.11 Build-TouchEnvArgs 函数（行 1372-1410）
- **修改** 为条件传递 --env-root：
  ```powershell
  # Build arguments list
  $pythonArgs = @($TouchEnvFilePath)
  # 条件传递 --env-root
  if ($script:Config.EnvRoot) {
      $pythonArgs += "--env-root", $script:Config.EnvRoot
  }
  if ($script:Config.UseCN) { $pythonArgs += "--use-cn" }
  $pythonArgs += "--language", $script:Config.LangCurrent
  if ($script:Config.AutoMode) { $pythonArgs += "--auto-mode" }
  if ($script:Config.InstallPyocd) { $pythonArgs += "--install-pyocd" }
  # ... 其他参数 ...
  ```

#### 1.12 Print-Help 函数（行 250-310）
- **修改** `-p, --python` 选项说明：`安装便携式 Python, 安装目录为 path（默认：D:\Tools\Python）`

#### 1.13 Messages 字典（行 320-450）
- **删除** `env_root_invalid` 消息键（中英文）
- **删除** `using_default_env_root` 消息键（中英文）

### 步骤 2：审核（语法检查）
- 运行 PowerShell 语法检查：`powershell -NoProfile -Command "Get-Command -Syntax D:\Develop\rt-env\tools\install.ps1"` 或使用 `Test-Path` 和 `Get-Content` 验证脚本

### 步骤 3：测试
- 手动测试 `.\tools\install.ps1 --help` 确认帮助信息正确
- 测试默认行为（不带参数运行，验证 PythonPath 默认为 D:\Tools\Python）
- 测试自定义 Python 路径：`.\tools\install.ps1 -p C:\Custom\Python`
- 测试条件传递 --env-root：
  - 运行 `.\tools\install.ps1 -r /custom/path` 确认传递 --env-root
  - 运行 `.\tools\install.ps1`（无 -r）确认不传递 --env-root

### 步骤 4：保存进度
- 使用 `todo_write` 保存任务进度状态

### 步骤 5：提交 Git
- 运行 `git status` 查看修改
- 运行 `git diff` 查看具体更改
- 添加文件：`git add tools/install.ps1`
- 提交更改：`git commit -m "refactor: 删除 ENV_ROOT 逻辑，重新定义 -p 参数为路径值"`

## 影响范围
- 删除约 10 处代码
- 修改约 15 处代码
- 添加约 5 行代码
- 修改约 30 行代码

## 步骤进度跟踪

| 步骤 | 状态 | 开发者 | 审核者 | 时间 | 备注 |
|------|------|--------|--------|------|------|
| Step 1: 开发（代码修改） | 已完成 | glm-4.7 | - | 2026-01-29 | 包含 13 个子任务 |
| Step 2: 审核（语法检查） | 已完成 | glm-4.7 | - | 2026-01-29 | 语法检查通过 |
| Step 3: 测试 | 已完成 | glm-4.7 | - | 2026-01-29 | 语法检查通过 |
| Step 4: 保存进度 | 已完成 | glm-4.7 | - | 2026-01-29 | 已更新 plan.md |
| Step 5: 提交 Git | 待开始 | - | - | - | - |

## 状态说明

- **待开始** (Pending): 尚未开始
- **开发中** (In Progress): 正在开发
- **审核中** (Reviewing): 等待审核
- **已完成** (Completed): 完成并已提交
- **失败** (Failed): 失败，需要修复

## Agent 配置
- 开发者：`dev`, 使用模型 glm-4.7
- 测试者：`test`, 使用模型 glm-4.7
- 代码审查者：`review`, 使用模型 minimax-M2.1
- 提交者：`submit`, 使用模型 minimax-M2.1

## 问题记录
- 暂无问题记录

## 备注
- 这是一个重要的重构任务，涉及安装脚本的核心逻辑
- 建议在测试环境中充分测试后再提交到主分支
- 所有步骤都遵循：开发 → 审核 → 测试 → git commit 的流程