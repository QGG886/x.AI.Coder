# 布局规则

## 规则格式说明

本文件采用 Markdown 格式组织转换规则，每条规则包含以下部分：

- **规则内容**：详细说明转换规则
- **示例**：提供 WinForms 和 WPF 的代码对比示例（如适用）
- **注意事项**：特殊情况说明（如适用）

**添加新规则时**：
1. 在相应章节下添加新规则
2. 提供清晰的示例代码
3. 使用代码块展示转换前后对比
4. 如有特殊情况，添加注意事项说明

---

## 布局重构原则（必须严格遵守）

**规则内容**：

1. 直接迁移原有布局可能导致结构不合理。因此，首先需系统梳理现有布局逻辑，随后采用 Layout 框架的布局原则进行重构，以确保整体一致性和适应性。
2. 在使用 Layout 框架重构布局时，必须严格分析原有控件的名称（从 Name 属性转换为 x:Name 属性）。允许替换控件，但需合理地将原名称映射到新控件上，以维护代码的可读性和兼容性。
3. 移除或替换原有元素可能会破坏自适应布局中的固定尺寸或边距设置。因此，应采用 LayoutControl、LayoutGroup 和 LayoutItem 来重新实现布局，并确保其合理性。源代码中存在对 LayoutControl 的滥用现象，需要进行优化。具体而言，最终布局结构应以单一 LayoutControl 作为根节点（每个项目仅限一个），结合数量适中的 LayoutGroup（用于分组 Item 以适应布局需求）和 LayoutItem（最小单元，直接封装目标控件）。内部通过 Layout 相关属性实现多样化布局逻辑；禁止使用 dxlc:LayoutControl.Root 形式，仅允许 LayoutControl + LayoutGroup + LayoutItem + 直属控件的组合，且每个直属控件必须由 LayoutItem 封装后置于 LayoutControl 或 LayoutGroup 中。
4. 所有原 WinForms 属性如果在 WPF 中不存在或语义不同，应改写为等价的 WPF 属性；若无法明确对应，则添加注释说明。
5. 如果原有是窗体（即类以 Frm 开头），则改为 xb:FrmBase。如果原有是 UC（即类以 UC 开头），则改为 xb:UCBase。如果原有是自定义基类，则采用 local:原基类名称。
6. 自定义控件：若遇到自定义控件或第三方 WinForms 控件，则在 XAML 中以注释形式插入占位。
7. 生成代码中的控件所属 xmlns 不允许随意使用 local，除非明确确认是相关本业务的自定义控件。

---

## 已提前明确且必须遵守的 xmlns 限制

**规则内容**：

1. XIRGridControl、XIRLookUpEdit、XirCalcEdit 使用 xmlns:xc="http://www.xquant.com/controls"。
2. ComboBoxEdit、CheckEdit 使用 xmlns:dxe="http://schemas.devexpress.com/winfx/2008/xaml/editors"。
3. LayoutControl、LayoutGroup、LayoutItem 使用 xmlns:dxlc="http://schemas.devexpress.com/winfx/2008/xaml/layoutcontrol"。
4. DropDownButton、SimpleButton 使用 xmlns:dx="http://schemas.devexpress.com/winfx/2008/xaml/core"。
5. FrmBase、UCBase 使用 xmlns:xb="http://www.xquant.com/wpfbase"。
6. **注意**：对于本地自定义控件（local），用户会在最后手动声明 xmlns:local，但在生成的 XAML 代码中如果明确是本地自定义控件，则使用 local: 前缀。

---

## 分隔条控件处理

**规则内容**：

原 WinForms 分隔条控件不需要使用，在 WPF 中，相邻的 LayoutGroup 只需设置 `LayoutGroup dxlc:LayoutControl.AllowVerticalSizing="True"` 该属性，即可显示分隔条。