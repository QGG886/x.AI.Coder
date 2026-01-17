# x.AI.Coder

基于 AI 的 WinForms 到 WPF 转换工具。

## 系统要求

- **PowerShell 7.0 或更高版本**
- iflow CLI（推荐使用最新版本， 自行注册，国产免费的，使用GLM4.7模型）

## 安装

```bash
# 推荐方式（一键安装）
bash -c "$(curl -fsSL https://gitee.com/iflow-ai/iflow-cli/raw/main/install.sh)"

# 或已安装 Node.js 22+ 时
npm i -g @iflow-ai/iflow-cli@latest
```

## 目录结构

```
winform/                    # 放置待转换的 WinForms 文件（.cs 和 .Designer.cs）
wpf/                        # 转换结果输出目录 / Review 报告输出目录
wpf_fix/                    # 修复后的文件输出目录
rule_refinement/            # 放置需要分析规则的两个文件（用于完善规则库）
prompt/
  ├─ agents/                # 所有agent均支持iflow直接调用，所需参数iflow会自行询问
  │   ├─ transcode/         # 批量转换助手
  │   ├─ review/            # Code Review 助手
  │   ├─ fix/               # 代码修复助手
  │   ├─ rule_refinement/   # 规则完善助手
  │   └─ rules/             # 规则查询助手
  └─ rules/
      ├─ rule_index.md      # 规则索引文件（支持按需加载规则）
      ├─ cs/                # 后台代码转换规则（模块化）
      └─ designer/          # 设计器代码转换规则（模块化）
run_super.ps1               # 多步骤批量转换脚本
run_transcode.ps1           # 代码转换脚本（已被run_super包含，对应模式1）
run_review.ps1              # 代码review脚本（已被run_super包含，对应模式2）
```

---

## 注意事项

- 每次运行 `run_super.ps1` 前，建议清空 `wpf/` 和 `wpf_fix/` 目录以避免混淆
- 使用规则完善助手时，确保放入的文件是经过人工修复的正确版本
- 规则库会随着使用不断完善，转换准确率会逐步提高

---

## 功能说明

### 1. run_super - 多步骤批量转换脚本

自动完成 WinForms 到 WPF 的完整转换流程，包括转换、审查和修复。

**使用方法**：

```powershell
.\run_super.ps1
```

**执行流程**：

1. **转换**：将 WinForms 代码转换为 WPF 代码
2. **审查**：检查转换结果的正确性
3. **修复**：根据审查结果修复明显错误

**执行模式**：

- **模式 1：仅转换**
  - **使用前置条件**：
    - `winform/` 目录中存在待转换的 WinForms 文件（.cs 和 .Designer.cs）
    - 首次转换或需要重新转换时使用
  - **适用场景**：快速查看转换结果，或已经确认转换规则正确时

- **模式 2：仅审查**
  - **使用前置条件**：
    - `winform/` 目录中存在原始 WinForms 文件
    - `wpf/` 目录中已存在转换后的 WPF 文件
  - **适用场景**：检查之前转换的结果，或验证规则库的完整性

- **模式 3：全部执行（推荐）**
  - **使用前置条件**：
    - `winform/` 目录中存在待转换的 WinForms 文件（.cs 和 .Designer.cs）
  - **适用场景**：完整的转换流程，自动修复明显错误

**文件结构**：

```
winform/            # 放置待转换的 WinForms 文件（.cs 和 .Designer.cs）
wpf/                # 转换结果输出目录 / Review 报告输出目录
wpf_fix/            # 修复后的文件输出目录
```

**输出文件**：

- `wpf/{文件名}.xaml` - WPF XAML 文件
- `wpf/{文件名}.xaml.cs` - WPF 代码隐藏文件
- `wpf/{文件名}.trans.log.md` - 转换日志
- `wpf/{文件名}.review.log.md` - 审查报告
- `wpf_fix/{文件名}.xaml` - 修复后的 XAML 文件
- `wpf_fix/{文件名}.xaml.cs` - 修复后的代码隐藏文件
- `wpf_fix/{文件名}.super.log.md` - 修复日志

---

### 2. rule_refinement - 规则完善助手

当转换结果出现错误时，通过对比修复前后的文件，自动总结转换规则并完善到规则库中。

**使用场景**：

转换结果出现以下情况时：
- 属性映射错误
- 控件替换错误
- 事件绑定错误
- 命名空间错误
- 其他转换错误

**使用步骤**：

1. **修复转换错误**
   - 手动修复错误，确保代码正确

2. **准备文件**
   - 将原始 WinForms 文件和修复后的 WPF 文件放入 `rule_refinement/` 目录
   - 文件组合必须是以下两种之一，一次只能放入一组文件：
     - `.Designer.cs`（源文件）+ `.xaml`（修复后的文件）
     - `.cs`（源文件）+ `.cs`（修复后的文件）

   **示例**：
   ```
   rule_refinement/
   ├── UCQuoteEnquiry.Designer.cs    # 原始 WinForms 设计器代码
   └── UCQuoteEnquiry.xaml           # 人工修复后的 WPF XAML 代码
   ```

3. **启动 iflow**
   ```bash
   iflow
   ```

4. **调用规则完善 Agent**
   ```
   @prompt/agents/rule_refinement/rule_refinement.agent.md
   ```

5. **与 Agent 交互**
   - Agent 会读取两个文件并分析差异
   - Agent 会将提取的规则与已有规则比较
   - Agent 会逐条向你展示差异点（新增规则和冲突规则）
   - 你确认后，Agent 会智能合并到规则库中

**工作流程**：

```
转换错误 → 人工修复 → 放入 rule_refinement/ → 调用规则完善助手 → 规则库更新 → 重新转换
```

**注意事项**：

- 每次只允许放入 2 个文件
- 放入的文件必须是转换成功且经过人工修复的正确版本
- Agent 会逐条向你展示差异点，等待你的确认
- Agent 不会自动写入规则文件，必须经过你的确认

---

### 3. 规则查询代理

通过 iflow 直接查询转换规则，快速找到相关的转换规则和解决方案。

**使用方法**：

1. **启动 iflow**
   ```bash
   iflow
   ```

2. **调用规则查询 Agent**
   ```
   @prompt/agents/rules/rules.agent.md
   ```

3. **描述你的问题**
   - 描述你遇到的转换问题或需要查询的规则
   - 包含相关的关键词（如控件名称、属性名称、事件名称等）

**使用示例**：

你可以询问以下类型的问题：

- "CheckBox 的 Checked 属性在 WPF 中如何转换？"
- "表格的 DataSource 属性在 WPF 中应该用什么？"
- "定时器的 Interval 属性类型有什么变化？"
- "如何处理 WinForms 中的 Paint 事件？"
- "LayoutVisibility.Never 应该转换为什么？"
- 复制一段winform代码 询问怎么处理成wpf版本

**Agent 会**：

- 根据你的问题关键词，搜索相关的规则文件
- 提供完整的规则内容和示例代码
- 如果找不到相关规则，提供下一步建议（如使用规则完善工具）

**规则查询流程**：

```
启动 iflow → 调用规则查询 Agent → 描述问题 → 获取规则和解决方案 → 应用到你的代码中
```

**注意事项**：

- 尽量使用准确的关键词进行搜索（如控件名称、属性名称、事件名称）
- 如果找不到相关规则，可以考虑使用规则完善助手将新的转换规则添加到规则库中

---

## 转换错误处理

当转换结果出现错误时，按照以下步骤处理：

### 处理流程

```
转换错误 → 查看日志 → 人工修复 → 使用规则完善助手 → 规则库更新 → 重新转换
```

### 详细步骤

1. **查看转换日志**
   - 打开 `wpf/{文件名}.trans.log.md` 了解转换过程
   - 打开 `wpf/{文件名}.review.log.md` 了解具体错误

2. **人工修复错误**
   - 在 `wpf/` 目录中找到转换错误的文件
   - 手动修复错误，确保代码正确

3. **使用规则完善助手**
   - 将原始 WinForms 文件和修复后的 WPF 文件放入 `rule_refinement/` 目录
   - 启动 iflow 并调用 `@prompt/agents/rule_refinement/rule_refinement.agent.md`
   - 确认规则后，规则会自动添加到规则库

4. **重新转换**
   - 运行 `run_super.ps1`，新规则会自动应用到后续转换中

### 为什么转换结果需要人工修复？

由于 WinForms 和 WPF 的架构差异，某些转换需要人工判断：

- 布局结构的重构（WPF 使用 LayoutControl 等布局容器）
- 事件处理方式的调整
- 第三方控件的替换
- 自定义控件的适配
- 复杂业务逻辑的迁移

规则完善助手的作用就是将这些人工修复的经验转化为规则，逐步提高自动转换的准确率。

### 如何提高转换准确率？

遵循以下最佳实践：

1. **持续完善规则库**：每次修复转换错误后，使用规则完善助手将修复经验转化为规则
2. **参考转换日志**：仔细阅读转换日志，了解转换过程中的注意事项
3. **参考审查报告**：根据审查报告中的问题分类，针对性地修复错误
4. **保持代码风格一致**：在修复时遵循 WPF 的最佳实践和项目规范
5. **定期更新规则库**：随着修复经验的积累，规则库会越来越完善，转换准确率会逐步提高

---
