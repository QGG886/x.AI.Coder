# 通用属性规则

## 规则格式说明

本文件采用 Markdown 格式组织转换规则，每条规则包含以下部分：

- **规则内容**：详细说明转换规则
- **示例**：提供 WinForms 和 WPF 的代码对比示例
- **注意事项**：特殊情况说明（如适用）

**添加新规则时**：
1. 在相应章节下添加新规则
2. 提供清晰的示例代码
3. 使用代码块展示转换前后对比
4. 如有特殊情况，添加注意事项说明

---

## 命名空间替换


**规则内容**：

将以下命名空间进行替换或删除：

**需要替换：**
- `xQuant.xIR.UI` → `xQuant.XUI`

**需要删除（WinForms 相关）：**
- `System.Drawing`
- `System.Windows.Forms`
- `DevExpress.Utils.Menu`
- `DevExpress.XtraEditors.Controls`
- `DevExpress.XtraGrid.Columns`
- `DevExpress.XtraGrid.Views.Base`
- `DevExpress.XtraGrid.Views.Grid`
- `DevExpress.XtraLayout.Utils`
- `DevExpress.XtraTab`
- `xQuant.UI.Assist`
- `xQuant.UI.Base`
- `xQuant.xIR.UI.OTCTrade`

**WPF 相关命名空间（自动引入）：**
- `InvokeHelper` → `xQuant.XUI.Utils.Helper`
- `CFETSTradeGridInitial` → `xQuant.XUI.CFETSTrade.Helper`
- `GridColumn` → `DevExpress.Xpf.Grid`
- `DefaultBoolean` → `DevExpress.Utils`
- `CFETSTradeUIHelper` → `xQuant.XUI.CFETSTrade`
- `DXMenuItem` → `xQuant.XUI.Controls`
- `EditControlOfIntSecuAcct` → `xQuant.XUI.Common`
- `TabControlSelectionChangedEventArgs` → `DevExpress.Xpf.Core`
- `GridColumnDataEventArgs` → `DevExpress.Xpf.Grid`
- `GridAssist` → `xQuant.XUI.Base`
- `EditControlOfCounterParty` → `xQuant.XUI.Common`
- `XirCalcEdit` → `xQuant.XUI.Controls`
- `XirHelper` → `xQuant.XUI.Common`
- `UCBase` → `xQuant.XUI.Base`

**示例：**
```csharp
// WinForms
using xQuant.xIR.UI.CFETSTrade;

// WPF
using xQuant.XUI.CFETSTrade;
```

---

## Visibility 属性转换


**规则内容**：

- `LayoutVisibility.Never` → `Visibility.Collapsed`
- `LayoutVisibility.Always` → `Visibility.Visible`
- `PageVisible = true` → `Visibility = Visibility.Visible`
- `PageVisible = false` → `Visibility = Visibility.Collapsed`
- `Visible = true` → `Visibility = Visibility.Visible`
- `Visible = false` → `Visibility = Visibility.Collapsed`
- 判断时与 `Visibility.Visible` 比较

**示例：**
```csharp
// WinForms
this.layoutCISpiltMatch.Visibility = LayoutVisibility.Never;
this.xtraTabPageDialog.PageVisible = BizDict.CFETSHasIRSwapDlgRight;
this.cmbSecuAccount.Visible = true;
if (this.pageQuoteDeal.PageVisible)
{
    // ...
}

// WPF
this.layoutCISpiltMatch.Visibility = Visibility.Collapsed;
this.xtraTabPageDialog.Visibility = BizDict.CFETSHasIRSwapDlgRight ? Visibility.Visible : Visibility.Collapsed;
this.cmbSecuAccount.Visibility = Visibility.Visible;
if (this.pageQuoteDeal.Visibility == Visibility.Visible)
{
    // ...
}
```

---

## Color 类型转换


**规则内容**：

- **直接使用 Color**：`Color.Yellow` → `Brushes.Yellow`
- **方法返回的 Color**：需要调用 `.ToMediaBrush()` 转换为 `Brush`
- **所有场景统一使用 Brushes**：属性赋值、条件判断、返回值等所有场景都使用 `Brushes.XXX`

**示例**：
```csharp
// WinForms
e.Appearance.BackColor = Color.Yellow;
e.Appearance.ForeColor = XirHelper.GetColorTrdType(trade.TRDTYPE);
e.Appearance.BackColor = Color.BlueViolet;
e.Appearance.ForeColor = Color.Red;
if (color == Color.Red) { }
return Color.Blue;

// WPF
e.Background = Brushes.Yellow;
e.Foreground = XirHelper.GetColorTrdType(trade.TRDTYPE).ToMediaBrush();
e.Background = Brushes.BlueViolet;
e.Foreground = Brushes.Red;
if (color == Brushes.Red) { }
return Brushes.Blue;
```

**注意事项**：
- 直接使用的 Color 颜色值使用 `Brushes.XXX`
- 通过方法返回的 Color 值需要调用 `.ToMediaBrush()` 扩展方法转换为 `Brush`
- 不使用 `new SolidColorBrush(Colors.XXX)`

---

## 菜单项属性转换

**规则内容**：

- `Enabled` → `IsEnabled`

**示例**：
```csharp
// WinForms
this._tradeBackToCreated_Menu.Enabled = true;
this._showQuoteHistorymenuItem.Enabled = false;

// WPF
this._tradeBackToCreated_Menu.IsEnabled = true;
this._showQuoteHistorymenuItem.IsEnabled = false;
```

---

### 其他通用属性转换

| WinForms 属性 | WPF 属性 |
|--------------|----------|
| `ForeColor` | `Foreground` |
| `BackColor` | `Background` |
| `Enabled` | `IsEnabled` |
| `Dock` | 转换为对应的 WPF 布局属性（如 `DockPanel.Dock` 或 Grid 行列） |
| `Properties.ReadOnly` | `IsReadOnly` |
| `DialogResult` | 不做变化（已有全局别名） |