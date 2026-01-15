### 设计规则

## 布局重构原则（必须严格遵守）
1. 直接迁移原有布局可能导致结构不合理。因此，首先需系统梳理现有布局逻辑，随后采用 Layout 框架的布局原则进行重构，以确保整体一致性和适应性。
2. 在使用 Layout 框架重构布局时，必须严格分析原有控件的名称（从 Name 属性转换为 x:Name 属性）。允许替换控件，但需合理地将原名称映射到新控件上，以维护代码的可读性和兼容性。
3. 移除或替换原有元素可能会破坏自适应布局中的固定尺寸或边距设置。因此，应采用 LayoutControl、LayoutGroup 和 LayoutItem 来重新实现布局，并确保其合理性。源代码中存在对 LayoutControl 的滥用现象，需要进行优化。具体而言，最终布局结构应以单一 LayoutControl 作为根节点（每个项目仅限一个），结合数量适中的 LayoutGroup（用于分组 Item 以适应布局需求）和 LayoutItem（最小单元，直接封装目标控件）。内部通过 Layout 相关属性实现多样化布局逻辑；禁止使用 dxlc:LayoutControl.Root 形式，仅允许 LayoutControl + LayoutGroup + LayoutItem + 直属控件的组合，且每个直属控件必须由 LayoutItem 封装后置于 LayoutControl 或 LayoutGroup 中。
4. 所有原 WinForms 属性如果在 WPF 中不存在或语义不同，应改写为等价的 WPF 属性；若无法明确对应，则添加注释说明。
5. 如果原有是窗体（即类以 Frm 开头），则改为 xb:FrmBase。如果原有是 UC（即类以 UC 开头），则改为 xb:UCBase。如果原有是自定义基类，则采用 local:原基类名称。
7. 自定义控件：若遇到自定义控件或第三方 WinForms 控件，则在 XAML 中以注释形式插入占位。
8. 生成代码中的控件所属 xmlns 不允许随意使用 local，除非明确确认是相关本业务的自定义控件。
9. 表格控件规则：任何原文表格（如 DataGridView、GridControl for WinForms 等）必须替换为 `XIRGridControl`，并将其 View 设置为 `XIRTableView`。必须严格参照以下示例代码用法进行替换：
   ```
   <xc:XIRGridControl
       x:Name="名字">
       <xc:XIRGridControl.View>
           <xc:XIRTableView x:Name="名字"/>
       </xc:XIRGridControl.View>
   </xc:XIRGridControl>
   ```
10. 原有的 EmptySpaceItem 应替换为一个空的 LayoutItem，并保持命名一致，因为 WPF DevExpress 中不存在 EmptySpaceItem 该控件。
11. 不允许使用双向绑定。
12. 源代码中的 namespace 如果存在 `xIR.UI` 片段，则需改为 `XUI`（例如 xQuant.xIR.UI.xxx -> xQuant.XUI.xxx），注意前后内容不要丢失。
13. 除 Label 外，其他控件不允许使用 WPF 原生控件，必须使用 DevExpress 的控件。
14. 原控件的文本显示属性必须迁移过来，例如 Content、Text、Label、NullValue、NullText 等这些需要显示的文本属性。
15. 原 WinForms 分隔条控件不需要使用，在 WPF 中，相邻的 LayoutGroup 只需设置 `LayoutGroup dxlc:LayoutControl.AllowVerticalSizing="True"` 该属性，即可显示分隔条。

## 控件事件替换规则
目前仅保留以下事件，事件名称不能改变：
1. Button 的 Click 事件。
2. CheckEdit 的 EditValueChanged 事件。

## 一些明确的控件替换规则
1. DevExpress.XtraEditors.PopupContainerEdit -> xc:XIRLookUpEdit。

## 已提前明确且必须遵守的 xmlns 限制
1. XIRGridControl、XIRLookUpEdit、XirCalcEdit 使用 xmlns:xc="http://www.xquant.com/controls"。
2. ComboBoxEdit、CheckEdit 使用 xmlns:dxe="http://schemas.devexpress.com/winfx/2008/xaml/editors"。
3. LayoutControl、LayoutGroup、LayoutItem 使用 xmlns:dxlc="http://schemas.devexpress.com/winfx/2008/xaml/layoutcontrol"。
4. DropDownButton、SimpleButton 使用 xmlns:dx="http://schemas.devexpress.com/winfx/2008/xaml/core"。
5. FrmBase、UCBase 使用 xmlns:xb="http://www.xquant.com/wpfbase"。
**注意**：对于本地自定义控件（local），用户会在最后手动声明 xmlns:local，但在生成的 XAML 代码中如果明确是本地自定义控件，则使用 local: 前缀。