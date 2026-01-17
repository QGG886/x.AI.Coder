# 控件替换规则

## 表格控件规则

**规则内容**：

任何原文表格（如 DataGridView、GridControl for WinForms 等）必须替换为 `XIRGridControl`，并将其 View 设置为 `XIRTableView`。必须严格参照以下示例代码用法进行替换：

```xml
<xc:XIRGridControl
    x:Name="名字">
    <xc:XIRGridControl.View>
        <xc:XIRTableView x:Name="名字"/>
    </xc:XIRGridControl.View>
</xc:XIRGridControl>
```

---

## EmptySpaceItem 替换规则

**规则内容**：

原有的 EmptySpaceItem 应替换为一个空的 LayoutItem，并保持命名一致，因为 WPF DevExpress 中不存在 EmptySpaceItem 该控件。

---

## 双向绑定限制

**规则内容**：

不允许使用双向绑定。

---

## 命名空间替换规则

**规则内容**：

源代码中的 namespace 如果存在 `xIR.UI` 片段，则需改为 `XUI`（例如 xQuant.xIR.UI.xxx -> xQuant.XUI.xxx），注意前后内容不要丢失。

---

## 控件使用限制

**规则内容**：

除 Label 外，其他控件不允许使用 WPF 原生控件，必须使用 DevExpress 的控件。

---

## 文本属性迁移规则

**规则内容**：

原控件的文本显示属性必须迁移过来，例如 Content、Text、Label、NullValue、NullText 等这些需要显示的文本属性。

---

## 明确的控件替换规则

**规则内容**：

DevExpress.XtraEditors.PopupContainerEdit -> xc:XIRLookUpEdit。