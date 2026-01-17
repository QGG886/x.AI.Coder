# 规则索引文件

本文件是规则加载的权威指南，所有Agent在加载规则时都应遵循本文件的指引。

---

## 规则文件结构

```
prompt/rules/
├── rule_index.md           # 本文件：规则索引和加载指南
├── cs/                     # 后台代码转换规则
│   ├── common.md           # 通用属性规则（始终加载）
│   ├── controls.md         # 控件特定规则
│   ├── grid.md             # 表格规则
│   ├── timer.md            # 定时器规则
│   └── special.md          # 特殊场景规则
└── designer/               # 设计器代码转换规则
    ├── layout.md           # 布局规则（始终加载）
    ├── controls.md         # 控件替换规则
    └── events.md           # 事件规则
```

---

## 规则加载流程

所有Agent在加载规则时，必须遵循以下标准流程：

### 第一步：读取规则索引
始终读取 `prompt/rules/rule_index.md` 了解规则文件结构。

### 第二步：根据任务类型选择加载策略

#### 后台代码转换/审查（CS）
**始终加载**：`prompt/rules/cs/common.md`

**按需加载**：
- 包含 CheckBox/Button/Label/ComboBox/TabControl → `prompt/rules/cs/controls.md`
- 包含 Timer → `prompt/rules/cs/timer.md`
- 包含 GridControl/GridView → `prompt/rules/cs/grid.md`
- 包含窗体关闭事件/特殊方法调用/状态灯/分隔条 → `prompt/rules/cs/special.md`

#### 设计器代码转换/审查（Designer）
**始终加载**：`prompt/rules/designer/layout.md`

**按需加载**：
- 包含表格控件 → `prompt/rules/designer/controls.md`
- 包含需要事件绑定的控件 → `prompt/rules/designer/events.md`

#### 规则完善（Rule Refinement）
根据规则内容判断应该更新哪个模块化文件：
- Designer + XAML → `prompt/rules/designer/` 下的相应文件
- CS + CS → `prompt/rules/cs/` 下的相应文件

### 第三步：加载规则

**后台代码加载顺序**：
1. `cs/common.md`
2. `cs/controls.md`（如果包含相关控件）
3. `cs/grid.md`（如果包含表格）
4. 其他专项规则文件

**设计器代码加载顺序**：
1. `designer/layout.md`
2. `designer/controls.md`
3. `designer/events.md`

---

## 规则内容索引

### CS 规则（后台代码）

#### 1. 通用规则（common.md）
适用于所有转换场景的基础规则：
- 命名空间替换
- Visibility 属性转换
- Color 类型转换
- 菜单项属性转换

#### 2. 控件规则（controls.md）
各类控件的属性、事件和行为转换：
- **基础控件**：CheckBox、Content
- **ComboBox**：编辑值、Items、按键事件
- **TabControl**：控件转换、选中项访问、页面可见性
- **其他**：账户选择、LayoutControl、状态灯

#### 3. 表格规则（grid.md）
GridControl/GridView 相关的所有转换规则：
- **属性和方法**：表格属性转换、数据访问转换
- **事件转换**：10个具体事件规则（绘制、选择、右键菜单、过滤、双击、当前项、行数据、选择参数、行数、列显示文本）
- **初始化**：表格初始化转换

#### 4. 定时器规则（timer.md）
Timer 控件相关转换

#### 5. 特殊场景规则（special.md）
窗体、方法和特殊控件的转换：
- 窗体关闭事件转换
- 方法参数转换
- 状态灯修改方案
- 分隔条用法变化

### Designer 规则（设计器代码）

#### 1. 布局规则（layout.md）
XAML 布局重构和控件放置规则

#### 2. 控件替换规则（controls.md）
WinForms 控件到 WPF 控件的映射规则

#### 3. 事件规则（events.md）
设计器中的事件绑定规则

---

## 规则文件格式标准

所有模块化规则文件应遵循统一的格式：

```markdown
# [规则类别]

## [规则名称]

**规则内容**：
[详细说明]

**示例**：
```csharp
// WinForms
[代码]

// WPF
[代码]
```

**注意事项**：
[特殊情况说明]
```

---

## 重要说明

- **本文件是规则加载的权威指南**，所有Agent在加载规则时都应遵循本文件的指引
- **不要在各个Agent中重复编写规则加载逻辑**，只需引用本文件即可
- **规则文件路径都是相对于 `prompt/rules/` 目录的**