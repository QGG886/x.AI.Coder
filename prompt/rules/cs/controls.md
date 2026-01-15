# 控件特定规则

---

## CheckBox 属性转换

**规则内容**：

- `Checked` → `IsChecked`
- 判断时需要与 `true` 或 `false` 比较（因为 `IsChecked` 是 `bool?` 类型）

**示例**：
```csharp
// WinForms
if (this.chkPendQuote.Checked)
{
    // ...
}

// WPF
if (this.chkPendQuote.IsChecked == true)
{
    // ...
}
```

---

## Content 属性转换

**规则内容**：

- `Button.Text` → `Button.Content`
- `Label.Text` → `Label.Content`
- `TextBlock` / `TextBox` 保持 `Text`

**示例**：
```csharp
// WinForms
this.btnSecuAccount.Text = "账户列表";
this.labelIRSDlgStatus.Text = string.Format("对话[{0}]", mktstatus);

// WPF
this.btnSecuAccount.Content = "账户列表";
this.labelIRSDlgStatus.Content = string.Format("对话[{0}]", mktstatus);
```

---

## 账户选择逻辑合并

**规则内容**：

将 `itemCmb_Click` 和 `itemTree_Click` 方法合并为一个方法（如 `BtnSecuAccount_SelectedIndexChanged`）

- 使用 `ItemClickEventArgs` 参数
- 通过 `e.Item.Content.ToString()` 判断选择的是"账户列表"还是"账户树"
- 根据 `e.Item.Content.ToString()` 的值执行相应的逻辑

**示例**：
```csharp
// WinForms
private void itemCmb_Click(object sender, EventArgs e)
{
    this.btnSecuAccount.Text = "账户列表";
    this.cmbSecuAccount.Visible = true;
    this.treeSecuAccount.Visible = false;
    this.cmbSecuAccount_EditValueChanged(null, null);
}

private void itemTree_Click(object sender, EventArgs e)
{
    this.btnSecuAccount.Text = "账户树";
    this.cmbSecuAccount.Visible = false;
    this.treeSecuAccount.Visible = true;
    this.treeSecuAccount_EditValueChanged(null, null);
}

// WPF
private void BtnSecuAccount_SelectedIndexChanged(object sender, ItemClickEventArgs e)
{
    if (e.Item.Content.ToString() == "账户树")
    {
        layoutControlItem27.Visibility = Visibility.Collapsed;
        panelTree.Visibility = Visibility.Visible;
        btnSecuAccount.Content = "账户树";
        this.treeSecuAccount_EditValueChanged(null, null);
    }
    else if (e.Item.Content.ToString() == "账户列表")
    {
        layoutControlItem27.Visibility = Visibility.Visible;
        panelTree.Visibility = Visibility.Collapsed;
        btnSecuAccount.Content = "账户列表";
        this.cmbSecuAccount_EditValueChanged(null, null);
    }
}
```

---

## ComboBox 编辑值访问方式变化

**规则内容**：

在 WinForms 中，ComboBox 的编辑值通过 `EditValue` 属性直接访问；在 WPF 中，对于多选 ComboBox，需要通过 `SelectedItems.SelectKeys()` 方法获取选中的键值列表。

**示例**：
```csharp
// WinForms
filter.Append("chkCmbOperator=" + this.chkCmbOperator.EditValue + "&");

// WPF
filter.Append("chkCmbOperator=" + string.Join(",", chkCmbOperator.SelectedItems.SelectKeys()) + "&");
```

---

## ComboBox Items 属性访问方式变化

**规则内容**：

在 WinForms 中，ComboBox 的 Items 通过 `Properties.Items` 属性访问，需要调用 `BeginUpdate()` 和 `EndUpdate()` 方法；在 WPF 中，直接通过 `ItemsSource` 属性赋值，无需调用更新方法。

**示例**：
```csharp
// WinForms
this.cmbFilters.Properties.BeginUpdate();
this.cmbFilters.Properties.Items.BeginUpdate();
try
{
    this.cmbFilters.Properties.Items.Clear();
    this.FilterTemplates.Keys.OrderBy(x => x).ToList().ForEach(key => this.cmbFilters.Properties.Items.Add(key));
}
finally
{
    this.cmbFilters.Properties.EndUpdate();
    this.cmbFilters.Properties.Items.EndUpdate();
}

// WPF
this.cmbFilters.ItemsSource = null;
this.cmbFilters.ItemsSource = this.FilterTemplates.SelectKeys().OrderBy(x => x);
```

---

## ComboBox 按键事件转换

**规则内容**：

1. **事件参数变化**：在 WinForms 中，按键事件通过 `KeyEventArgs` 参数，使用 `KeyCode` 属性；在 WPF 中，通过 `KeyEventArgs` 参数，使用 `Key` 属性。
2. **属性变化**：在 WinForms 中，ComboBox 的文本编辑通过 `Properties.TextEditStyle` 属性控制；在 WPF 中，通过 `IsTextEditable` 属性控制。

**示例**：
```csharp
// WinForms
this.cmbFilters.Properties.TextEditStyle = TextEditStyles.DisableTextEditor;
this.cmbFilters.KeyDown += (s, a) =>
{
    if (a.KeyCode == Keys.Back || a.KeyCode == Keys.Delete)
    {
        this.cmbFilters.EditValue = string.Empty;
    }
};

// WPF
cmbFilters.IsTextEditable = false;
this.cmbFilters.KeyDown += (s, a) =>
{
    if (a.Key == Key.Back || a.Key == Key.Delete)
    {
        this.cmbFilters.EditValue = string.Empty;
    }
};
```

---

## TabControl 转换

**规则内容**：

1. **事件转换**：事件从 `SelectedPageChanged` → `SelectionChanged`
2. **事件参数**：从 `TabPageChangedEventArgs` → `TabControlSelectionChangedEventArgs`
3. **选中项访问**：原访问 `SelectedTabPage` 的地方改为 `SelectedContainer` 或 `SelectedItem`
4. **删除更新方法**：删除 `BeginUpdate()` / `EndUpdate()` 调用
5. **页面可见性**：`PageVisible` 变成 `Visibility`，赋值时需要在 bool 后加上 `.ToVisibility()`

**示例**：
```csharp
// WinForms
this.xtraTabControlMain.SelectedPageChanged += this.xtraTabControlMain_SelectedPageChanged;
TabPage selectedPage = this.xtraTabControlMain.SelectedTabPage;
this.xtraTabPageDialog.PageVisible = true;

// WPF
this.xtraTabControlMain.SelectionChanged += this.xtraTabControlMain_SelectedPageChanged;
var selectedContainer = this.xtraTabControlMain.SelectedContainer;
this.xtraTabPageDialog.Visibility = true.ToVisibility();
```

---

## LayoutControl BeginUpdate/EndUpdate 删除

**规则内容**：

在 WinForms 中，LayoutControl 控件更新需要调用 `BeginUpdate()` 和 `EndUpdate()` 方法；在 WPF 中，这些方法不再需要，直接删除即可。

**示例**：
```csharp
// WinForms
this.layoutControl6.BeginUpdate();
try
{
    this.ShowTradeServiceStatus();
    this.ShowMktStatus();
}
finally
{
    this.layoutControl6.EndUpdate();
}

// WPF
this.ShowTradeServiceStatus();
this.ShowMktStatus();
```

---

## 状态灯 Paint 事件删除

**规则内容**：

在 WinForms 中，状态灯通过 Label 控件的 `Paint` 事件绘制；在 WPF 中，删除 `Paint` 事件订阅，改用 `CreateSolidIndicator` 方法创建 Ellipse 控件。

**示例**：
```csharp
// WinForms
if (CFETSParams.CFETSMonitorMarketStatus)
{
    this.labelBondRequestLight.Paint += this.BondRequstMktStatus_Paint;
    this.labelBondDialgLight.Paint += this.BondDialgMktStatus_Paint;
}

private void BondRequstMktStatus_Paint(object sender, PaintEventArgs e)
{
    // 绘制圆形指示灯
    e.Graphics.FillEllipse(brush, 0, 0, 12, 12);
    e.Graphics.DrawEllipse(Pens.Black, 0, 0, 12, 12);
}

// WPF
// 状态灯事件，无需重绘，页面初始化一次和refresh时变化即可

private Ellipse CreateSolidIndicator(Brush color)
{
    return new Ellipse
    {
        Width = 15,
        Height = 15,
        Fill = color,
        SnapsToDevicePixels = true
    };
}
```