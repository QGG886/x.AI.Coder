# x.Coder

基于 AI 的 WinForms 到 WPF 转换工具。

## 目录结构

```
winform/            # 放置待转换的 WinForms 文件（.cs 和 .Designer.cs）
wpf/                # 转换结果输出目录 / Review 报告输出目录
prompt/
  ├─ agents/
  │   ├─ transcode/                   # 批量转换助手
  │   ├─ rule_refinement/             # 规则完善助手
  │   ├─ rules/                       # 规则查询助手
  │   └─ review/                      # Code Review 助手
  └─ rules/
      ├─ rule_index.md                # 规则索引文件（支持按需加载规则）
      ├─ cs/                          # 后台代码转换规则（模块化）
      ├─ designer/                    # 设计器代码转换规则（模块化）
rule_refinement/    # 放置需要分析规则的两个文件（用于完善规则库）
run_transcode.ps1   # 批量转换脚本
run_review.ps1      # 批量审查脚本
```

## 安装

```bash
# 推荐方式（一键安装）
bash -c "$(curl -fsSL https://gitee.com/iflow-ai/iflow-cli/raw/main/install.sh)"

# 或已安装 Node.js 22+ 时
npm i -g @iflow-ai/iflow-cli@latest
```

## 功能说明

### 1. 批量转换助手

自动将 WinForms 代码转换为 WPF 代码，支持批量处理。

**使用方法**：

```powershell
.\run_transcode.ps1
```

脚本会自动扫描 `winform/` 目录中的所有文件，按文件前缀分组后批量转换，结果输出到 `wpf/` 目录。

**转换内容**：
- `.Designer.cs` → `.xaml`（设计器代码转 XAML）
- `.cs` → `.cs`（后台代码转换）

**转换日志**：
- 每个文件组生成一个转换日志
- 日志文件与转换文件在同一目录
- 日志文件名格式：`{文件组}.trans.log.md`
- 日志包含转换详情、改动记录和问题说明

### 2. 规则完善助手

当发现转换结果需要人工修复后，可以将修复前后的文件放入 `rule_refinement/` 目录，自动总结转换规则并完善到规则库中。

**使用步骤**：

1. 准备两个文件放入 `rule_refinement/` 目录：
   - **Designer + XAML**: `.Designer.cs`（源文件）+ `.xaml`（修复后的目标文件）
   - **CS + CS**: `.cs`（源文件）+ `.cs`（修复后的目标文件）

2. 启动 iflow：
   ```bash
   iflow
   ```

3. 调用规则完善 Agent：
   ```
   @prompt/agents/rule_refinement/rule_refinement.agent.md
   ```

4. Agent 会：
   - 读取两个文件并分析差异
   - 提取转换规则并展示给你
   - 与你确认后，智能合并到 `prompt/rules/designer_rule.md` 或 `prompt/rules/cs_rule.md`

**示例**：

假设你发现 `UCQuoteEnquiry.Designer.cs` 转换后的 `UCQuoteEnquiry.xaml` 中某个属性映射错误，修复后可以这样完善规则：

```
rule_refinement/
├── UCQuoteEnquiry.Designer.cs    # 原始 WinForms 设计器代码
└── UCQuoteEnquiry.xaml           # 人工修复后的 WPF XAML 代码
```

启动 iflow 并调用规则完善 Agent，它会分析这两个文件的差异，提取出正确的转换规则并更新到规则库中。

**注意**：
- 每次只允许放入 2 个文件
- 放入的文件必须是转换成功且经过人工修复的
- Agent 会与你在关键节点交互确认，不会自动写入规则文件

### 3. 规则查询助手

根据您的问题，从已知的转换规则中查找相关的规则，并提供解决方案。

**使用方法**：

启动 iflow：
```bash
iflow
```

调用规则查询 Agent：
```
@prompt/agents/rules/rules.agent.md
```

**使用场景**：

1. **查找特定转换规则**：当您需要了解某个控件、属性或事件的转换规则时
2. **解决转换问题**：当转换过程中遇到问题时，查找相关的规则和解决方案
3. **学习转换规则**：当您想了解某个特定场景的转换规则时

**示例**：

您可以询问以下类型的问题：
- "CheckBox 的 Checked 属性在 WPF 中如何转换？"
- "表格的 DataSource 属性在 WPF 中应该用什么？"
- "定时器的 Interval 属性类型有什么变化？"
- "如何处理 WinForms 中的 Paint 事件？"

Agent 会：
- 从规则文件中搜索相关的规则
- 提供完整的规则内容和示例代码
- 如果找不到相关规则，提供下一步建议（如使用规则完善工具）

### 4. Code Review 助手

对已转换的 WPF 代码进行审查，基于转换规则检查转换的正确性，生成详细的审查报告。

**使用方法**：

```powershell
.\run_review.ps1
```

脚本会自动扫描 `winform/` 和 `wpf/` 目录中的文件，按文件前缀分组后批量审查，生成审查报告到 `wpf/` 目录。

**审查内容**：
- 检查后台代码转换的正确性（基于 cs_rule.md）
- 检查设计器代码转换的正确性（基于 designer_rule.md）
- 记录错改、漏改、多改、需确认的问题
- 生成详细的审查报告（.review.md）

**审查报告**：
- 每个文件组生成一个审查报告
- 报告文件与 WPF 文件在同一目录
- 报告文件名格式：`{文件组}.review.log.md`
- 报告包含问题分类、严重程度评估和修复建议

## 注意事项

- 转换结果需人工检查和完善，特别是事件处理、布局细节、资源引用等部分。
- 规则完善时，请确保放入的文件是经过人工修复的正确版本，以便提取准确的转换规则。
- 每次运行批量转换前，建议清空 `wpf/` 目录以避免混淆。

## 规则文件结构

本项目采用模块化的规则文件结构，支持按需加载规则以减少上下文长度，提高转换准确性。

### 模块化模式（推荐）

规则文件按类别拆分为多个小文件：
- `prompt/rules/rule_index.md`：规则索引文件，包含所有规则的索引和加载指南
- `prompt/rules/cs/`：后台代码转换规则（按类别拆分）
- `prompt/rules/designer/`：设计器代码转换规则（按类别拆分）

**优势**：
- 减少单次加载的规则文件大小
- 提高规则查找效率
- 便于规则维护和更新
- 可以根据实际需求动态加载规则

### 按需加载规则

系统会根据文件内容自动识别需要加载的规则文件：
- 后台代码转换：根据包含的控件类型加载相应的规则文件
- 设计器代码转换：根据控件类型和布局需求加载相应的规则文件
- 代码审查：与转换过程相同的加载策略
- 规则完善：根据规则内容判断应该更新哪个模块化文件

## 脚本配置说明

### run_transcode.ps1 配置

脚本支持以下配置参数（在脚本开头定义）：

- `$TEST_MODE`：测试模式，设为 `$true` 时跳过实际转换，仅显示将要处理的文件（默认：`$false`）
- `$TIMEOUT_SEC`：超时时间，单位为秒（默认：`21600`，即 6 小时）
- `$MAX_WORKERS`：最大并发工作数（默认：`1`，开会员才能并发）

**修改配置**：
1. 使用文本编辑器打开 `run_transcode.ps1`
2. 找到相应的配置变量
3. 修改为所需值
4. 保存文件

### run_review.ps1 配置

脚本支持以下配置参数（在脚本开头定义）：

- `$TEST_MODE`：测试模式，设为 `$true` 时跳过实际审查，仅显示将要审查的文件（默认：`$false`）
- `$TIMEOUT_SEC`：超时时间，单位为秒（默认：`21600`，即 6 小时）
- `$MAX_WORKERS`：最大并发工作数（默认：`1`，暂不支持并发）

**修改配置**：
1. 使用文本编辑器打开 `run_review.ps1`
2. 找到相应的配置变量
3. 修改为所需值
4. 保存文件