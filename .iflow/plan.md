# touch_env.py 备份机制改进计划

## 实施概述

修改 touch_env.py 的安装流程，当旧安装存在时先备份再安装，安装成功/失败后根据策略处理备份。

## 主要改动

1. **新增备份机制**：检测到旧安装时，先备份整个目录（带时间戳命名）
2. **修改删除策略**：不再直接删除，而是先备份再安装
3. **安装成功处理**：根据策略删除备份或恢复保留项（`.config` + `local_pkgs`）
4. **安装失败处理**：提供选项恢复备份 / 保留当前状态

## 完整流程图

```
main()
  │
  ├→ parse_arguments()
  │     ├→ argparse.ArgumentParser()
  │     ├→ parser.parse_args()
  │     └→ args.custom_repos = {...}
  │
  └→ run_touch_env(args)
        │
        ├→ TouchEnvConfig(args)
        │     ├→ set_language(args.language)
        │     ├→ self._compute_paths()
        │     └→ self._validate()
        │
        ├→ check_existing_env(config)
        │     ├→ os.path.exists(config.env_root)
        │     ├→ show_deletion_options(config) [交互模式]
        │     │     └→ input()
        │     └→ create_backup_directory(config) [新增]
        │           ├→ get_backup_timestamp()
        │           ├→ shutil.disk_usage()
        │           └→ shutil.move()
        │
        ├→ backup_config_file(config)
        ├→ setup_repositories(config)
        ├→ create_venv(config)
        ├→ prompt_pyocd(config)
        ├→ install_packages(config)
        ├→ restore_config(config)
        │
        ├→ [新增] 处理备份（安装成功）
        │     ├→ restore_backup() [策略 Y]
        │     └→ cleanup_backup_directory() [策略 A]
        │
        └→ [新增] 处理备份（安装失败）
              └→ handle_installation_failure()
                    ├→ R: 恢复备份
                    ├→ K: 保留当前
                    └→ D: 删除备份
```

## 实施步骤（16步）

### 阶段1：准备工作

#### Step 1: 添加时间戳生成函数
- 位置：touch_env.py，在 _safe_remove 之前
- 功能：生成时间戳格式 YYYYMMDD_HHMMSS
- 导入：from datetime import datetime

#### Step 2: 添加国际化消息
- 位置：MESSAGES 字典
- 内容：11条新消息（中英文）
- 覆盖：备份创建、恢复、失败处理等

### 阶段2：备份机制实现

#### Step 3: 实现备份创建函数
- 函数：create_backup_directory(config)
- 功能：备份整个目录，检查磁盘空间
- 命名：{env_root}.backup.{timestamp}

#### Step 4: 优化磁盘空间计算
- 优化：大目录性能优化
- 容错：无法计算时使用默认值（1GB）
- 安全：20% 余量

### 阶段3：恢复机制实现

#### Step 5: 实现备份恢复函数
- 函数：restore_backup(config, backup_path, preserve_items)
- 策略 Y：恢复 .config 和 local_pkgs
- 策略 A：删除备份

#### Step 6: 添加安全删除函数
- 函数：cleanup_backup_directory(backup_path)
- 功能：安全删除备份目录

### 阶段4：失败处理实现

#### Step 7: 实现安装失败处理函数
- 函数：handle_installation_failure(config, backup_path, strategy)
- 选项：R(恢复)/K(保留)/D(删除)
- 自动模式：自动恢复

### 阶段5：配置类修改

#### Step 8: 修改 TouchEnvConfig 类
- 添加：backup_path = None
- 添加：strategy = None

### 阶段6：主流程修改

#### Step 9: 修改 check_existing_env 函数
- 移除：remove_env_directory 调用
- 添加：create_backup_directory 调用
- 保存：backup_path 和 strategy

#### Step 10: 修改 run_touch_env 函数
- 添加：Step 8 处理备份（成功）
- 添加：except 块处理备份（失败）

### 阶段7：清理和优化

#### Step 11: 标记 remove_env_directory 为废弃
- 添加：deprecated 警告
- 说明：新流程使用备份机制

#### Step 12: 代码审查和优化
- 检查：代码风格、注释、性能
- 优化：重复代码、安全检查

### 阶段8：测试准备

#### Step 13: 创建测试脚本
- 文件：test_touch_env.py
- 覆盖：T1-T26 测试场景

#### Step 14: 运行测试并修复
- 执行：所有测试
- 修复：发现的问题
- 目标：90%+ 通过率

### 阶段9：文档和发布

#### Step 15: 更新文档
- 文件：README.md
- 内容：安装流程、备份机制、故障排除

#### Step 16: 最终审查和发布准备
- 审查：功能、代码、测试、文档
- 准备：版本号、变更说明

## 测试流程（26个场景）

### Phase 1: 基础功能测试（T1-T5）
- T1: 首次安装（无旧安装）
- T2: 首次安装 + 中国镜像
- T3: 自动模式首次安装
- T4: 自定义仓库
- T5: 中英文切换

### Phase 2: 旧安装处理测试（T6-T11）
- T6: 策略 Y + 安装成功
- T7: 策略 A + 安装成功
- T8: 策略 N（取消）
- T9: 自动模式 + 旧安装
- T10: 无效仓库
- T11: 权限错误

### Phase 3: 错误恢复测试（T12-T15）
- T12: 安装失败 + 恢复备份
- T13: 安装失败 + 保留当前
- T14: 安装失败 + 删除备份
- T15: 恢复失败

### Phase 4: 边界条件测试（T16-T20）
- T16: 磁盘空间不足
- T17: 路径包含特殊字符
- T18: 超长路径
- T19: 并发安装
- T20: 网络中断

### Phase 5: 跨平台测试（T21-T23）
- T21: Windows 完整流程
- T22: Linux 完整流程
- T23: macOS 完整流程

### Phase 6: 性能测试（T24-T26）
- T24: 大备份测试
- T25: 网络慢速测试
- T26: 多次重复安装

## 开发审核流程

- **开发 Agent**: glm-4.7
- **审核 Agent**: minimax-m2.1
- **流程**: 一步开发 → 一步审核 → 测试 --成功--> git commit → 继续
                 |-<-----失败-------|
## Git 保存策略

- 每个步骤完成后立即 git add
- 每个步骤完成后立即 git commit
- 提交信息格式：`Step N: 步骤名称`
- 更新 .iflow/plan.md 和 .iflow/progress.md
- 确保每次提交都是可独立回滚的

## 预期结果

- 所有16个步骤自动完成
- 每个步骤都有独立的 git commit
- 26个测试场景自动执行
- 代码质量自动审核
- 文档自动生成和更新
- 完整的 git 历史记录