# 表格（Grid）规则

**说明：**
- `grdc` 表示 `XIRGridControl`
- `grdv` 表示 `XIRTableView`
- 代码中**必须使用包装后的控件类型**，但变量名保持不变
- 表格命名一定以 `grdc` 或 `grdv` 作为开头

---

## 表格属性转换

**规则内容**：

| WinForms 属性 | WPF 属性 |
|--------------|----------|
| `DataSource` | `ItemsSource` |
| `RefreshDataSource()` | `RefreshData()` |
| `OptionsView.ShowFooter` | `ShowTotalSummary` |
| `OptionsView.ColumnAutoWidth` | `AutoWidth` |
| `OptionsView.ShowBands` | `ShowBandsPanel` |
| `OptionsSelection.MultiSelect` | `AllowBandMultiRow` |
| `RowCount` | `VisibleRowCount` |
| `grdv.Columns` | `grdc.Columns` |

**示例：**
```csharp
// WinForms
this.grdcSwapTradList.DataSource = this._tradeCache;
this.grdcSwapTradList.RefreshDataSource();
this.grdvSwapTradeList.OptionsView.ShowFooter = true;
this.grdvSwapTradeList.OptionsView.ColumnAutoWidth = false;
this.grdvSwapTradeList.OptionsView.ShowBands = false;
this.grdvTradeList.OptionsSelection.MultiSelect = true;
int count = this.grdvSwapQuoteList.RowCount;

// WPF
this.grdcSwapTradList.ItemsSource = this._tradeCache;
this.grdcSwapTradList.RefreshData();
this.grdvSwapTradeList.ShowTotalSummary = true;
this.grdvSwapTradeList.AutoWidth = false;
this.grdvSwapTradeList.ShowBandsPanel = false;
this.grdvTradeList.AllowBandMultiRow = true;
int count = this.grdcSwapQuoteList.VisibleRowCount;
```

### 列属性变化

| WinForms 属性 | WPF 属性 | 类型变化 |
|--------------|----------|---------|
| `OptionsColumn.AllowEdit` | `AllowEditing` | `bool` → `DefaultBoolean` |
| `OptionsColumn.ReadOnly` | `ReadOnly` | - |
| `OptionsColumn.AllowSort` | `AllowSorting` | - |

**注意：** 无对应属性时必须添加注释说明"WPF 中无对应属性，已移除"

---

## 表格数据访问转换

**规则内容**：

| WinForms 方法 | WPF 方法 |
|--------------|----------|
| `grdv.GetRow(rowHandle)` | `grdc.GetRow(rowHandle)` 或 `grdc.CurrentItem` |
| `grdv.GetFocusedRow()` | `grdc.CurrentItem` |
| `grdv.FocusedRowHandle < 0` | `grdc.CurrentItem == null` |

**示例：**
```csharp
// WinForms
XPOTCTrade trade = this.grdvSwapTradeList.GetRow(rowHandle) as XPOTCTrade;
XPOTCTrade focusedTrade = this.grdvSwapTradeList.GetFocusedRow() as XPOTCTrade;
if (this.grdvSwapTradeList.FocusedRowHandle < 0) { }

// WPF
XPOTCTrade trade = this.grdcSwapTradList.GetRow(rowHandle) as XPOTCTrade;
XPOTCTrade focusedTrade = this.grdcSwapTradList.CurrentItem as XPOTCTrade;
if (this.grdcSwapTradList.CurrentItem == null) { }
```

---

## 表格右键菜单转换

**规则内容**：

- `Shortcut.CtrlG` → `new KeyGesture(Key.G, ModifierKeys.Control)`
- **删除**全选/取消菜单项及其事件处理

**示例：**
```csharp
// WinForms
DXMenuItem openTradeGroup = new DXMenuItem("浏览组合", this.OpenTradeGroup_Click);
openTradeGroup.Shortcut = Shortcut.CtrlG;
assistGrid.AddMenuItem(this.grdvSwapTradeList, openTradeGroup);

DXMenuItem _selectOrCancelTradesMenu = new DXMenuItem("全选/取消", this.SelectOrCancelTradesMenu_Click);
assistGrid.AddMenuItem(this.grdvSwapTradeList, _selectOrCancelTradesMenu);

// WPF
DXMenuItem openTradeGroup = new DXMenuItem("浏览组合", this.OpenTradeGroup_Click);
openTradeGroup.Shortcut = new KeyGesture(Key.G, ModifierKeys.Control);
assistGrid.AddMenuItem(this.grdvSwapTradeList, openTradeGroup);

// 删除全选/取消菜单项
```

---

## 表格选择逻辑转换

**规则内容**：

1. **删除** `Tag` 字典初始化（`this.grdvSwapTradeList.Tag = new Dictionary<string, bool>();`）
2. 改为使用 WPF 的默认选择列
3. **对于 `grdvSwapTradeList_CustomUnboundColumnData` 方法**：
   - 如果该方法只包含选择列相关代码，则删除整个方法
   - 如果该方法包含非选择列内容，则保留方法，但删除选择列相关代码（`CFETSTradeGridInitial.CheckboxSelection_CustomUnboundColumnData` 调用）
4. **对于 `grdvSwapTradeList_CellValueChanging` 方法**：
   - 如果该方法只包含选择列相关代码，则删除整个方法
   - 如果该方法包含非选择列内容，则保留方法，但删除选择列相关代码（`CFETSTradeGridInitial.CheckboxSelection_CellValueChanging` 调用）
5. **注意**：`CFETSTradeGridInitial.CheckboxSelection_GetGridSelectItem` 方法调用需要根据实际情况替换为获取选中项的方法（如 `this.GetSelectedTradeList()`），具体方法名可能因页面而异
6. **重要提醒**：此改动较大，需提醒用户自行校验

**示例：**
```csharp
// WinForms
this.grdvSwapTradeList.Tag = new Dictionary<string, bool>();
this.grdvSwapTradeList.CustomUnboundColumnData += this.grdvSwapTradeList_CustomUnboundColumnData;
this.grdvSwapTradeList.CellValueChanging += this.grdvSwapTradeList_CellValueChanging;

List<XPOTCTrade> tradeLst = CFETSTradeGridInitial.CheckboxSelection_GetGridSelectItem<XPOTCTrade>(this.grdvSwapTradeList as GridView, dic);

// WPF
// 删除 Tag 初始化
// 如果 CustomUnboundColumnData 方法只包含选择列代码，则删除整个方法
// 如果包含非选择列代码，则保留方法但删除选择列相关部分
// 如果 CellValueChanging 方法只包含选择列代码，则删除整个方法
// 如果包含非选择列代码，则保留方法但删除选择列相关部分
// 改为使用默认选择列
// 注意：GetSelectedTradeList() 方法名可能因页面而异，需根据实际情况替换
// 重要：此改动较大，需提醒用户自行校验
var tradeLst = this.GetSelectedTradeList();
```

---

## 表格绘制事件转换

**规则内容**：

1. **对于 `CustomDrawCell` 事件处理方法**：
   - 如果该方法只包含状态灯绘制代码，则删除整个方法，并删除该事件订阅
   - 如果该方法包含其他逻辑（非状态灯绘制），则保留方法，但删除状态灯绘制相关代码
2. **对于 `RowCellStyle` 事件处理方法**：
   - 该事件用于设置单元格的样式（如背景色、前景色等），**保留该方法及事件订阅**
   - 进行以下转换：
     - `grdv.GetRow(e.RowHandle)` → `grdc.GetRow(e.RowHandle)`
     - `e.Appearance.BackColor` → 保持 `e.Appearance.BackColor`（WPF 已包装该属性）
     - `e.Appearance.ForeColor` → 保持 `e.Appearance.ForeColor`（WPF 已包装该属性）
   - **Color 处理**：原代码中使用的 `Color` 类型需要转换为 WPF 的 `Brush` 类型：
     - 直接使用的颜色值：`Color.Yellow` → `Brushes.Yellow`
     - 方法返回的颜色值：`XirHelper.GetColorTrdType(trade.TRDTYPE)` → `XirHelper.GetColorTrdType(trade.TRDTYPE).ToMediaBrush()`
3. **重要提醒**：状态灯绘制逻辑需要额外处理，提醒用户手动处理

**示例**：
```csharp
// WinForms - CustomDrawCell
this.grdvSwapTradeList.CustomDrawCell += this.grdvSwapTradeList_CustomDrawCell;

private void grdvSwapTradeList_CustomDrawCell(object sender, RowCellCustomDrawEventArgs e)
{
    // 绘制状态灯和文本
    if (!(this.grdvSwapTradeList.GetRow(e.RowHandle) is XPOTCTrade trade) ||
        trade.CFETSTradeQuote == null)
    {
        return;
    }

    if (e.Column.FieldName == "CFETS_UP_QuoteStatusDisplay")
    {
        e.Handled = true;
        this.CustomDrawCell_QuoteStatus(trade.CFETS_UP_QuoteStatusDisplay, e);
    }
}

// WinForms - RowCellStyle
this.grdvSwapTradeList.RowCellStyle += this.grdvSwapTradeList_RowCellStyle;

private void grdvSwapTradeList_RowCellStyle(object sender, RowCellStyleEventArgs e)
{
    if (e.Column.FieldName == "TRDTYPE")
    {
        e.Appearance.BackColor = Color.Yellow;
        e.Appearance.ForeColor = XirHelper.GetColorTrdType(trade.TRDTYPE);
    }
}

// WPF
// CustomDrawCell 处理：
// 如果 CustomDrawCell 方法只包含状态灯绘制代码，则删除整个方法
// 如果包含其他逻辑，则保留方法但删除状态灯绘制相关代码
// 删除 CustomDrawCell 事件订阅
// 重要提醒：状态灯绘制逻辑需要额外处理，提醒用户手动处理

// RowCellStyle 处理（保留方法，做以下转换）：
this.grdvSwapTradeList.RowCellStyle += this.grdvSwapTradeList_RowCellStyle;

private void grdvSwapTradeList_RowCellStyle(object sender, RowCellStyleEventArgs e)
{
    if (e.Column.FieldName == "TRDTYPE")
    {
        e.Appearance.BackColor = Brushes.Yellow;
        e.Appearance.ForeColor = XirHelper.GetColorTrdType(trade.TRDTYPE).ToMediaBrush();
    }
}
```

---

## 表格初始化转换

**规则内容**：

1. `CFETSTradeGridInitial.InitTradeGrid_CFETSQuoteIRSwapDlg` 的第一个参数从 `grdv` 改为 `grdc`
2. **删除** `Tag` 字典初始化（`this.grdvSwapTradeList.Tag = new Dictionary<string, bool>();`）
3. **删除**列属性设置的 `foreach` 循环（包含 `col.OptionsColumn.AllowEdit = false` 等设置）
4. **删除** `BeginUpdate()` 和 `EndUpdate()` 调用

**示例：**
```csharp
// WinForms
GridUtils.GridBeginUpdate(this.grdvSwapTradeList);
try
{
    CFETSTradeGridInitial.InitTradeGrid_CFETSQuoteIRSwapDlg(this.grdvSwapTradeList, true, false);
    this.grdvSwapTradeList.Tag = new Dictionary<string, bool>();
    foreach (GridColumn col in this.grdvSwapTradeList.Columns)
    {
        if (col.Name != "colSelect")
        {
            col.OptionsColumn.AllowEdit = false;
        }
    }
}
finally
{
    GridUtils.GridEndUpdate(this.grdvSwapTradeList);
}

// WPF
GridUtils.GridBeginUpdate(this.grdvSwapTradeList);
try
{
    CFETSTradeGridInitial.InitTradeGrid_CFETSQuoteIRSwapDlg(this.grdcSwapTradList, true, false);
    // 删除 Tag 初始化
    // 删除列属性设置的 foreach 循环
}
finally
{
    GridUtils.GridEndUpdate(this.grdvSwapTradeList);
}
```

---

## 表格过滤逻辑转换

**规则内容**：

1. **删除** `ActiveFilter.BeginUpdate()` 和 `EndUpdate()` 调用
2. **删除** `ActiveFilterEnabled = true` 设置
3. 改为直接设置 `FilterString` 属性
4. 原来通过 `(sender as ViewFilter).Expression` 获取筛选条件，现在直接通过 `grdc.FilterString` 获取
5. **事件转换**：`ActiveFilter.Changed` → `FilterChanged`

**示例：**
```csharp
// WinForms
this.grdvSwapTradeList.ActiveFilter.Changed += this.grdvSwapTradeList_ActiveFilter_Changed;

protected void grdvSwapTradeList_ActiveFilter_Changed(object sender, EventArgs e)
{
    if (string.IsNullOrEmpty((sender as ViewFilter).Expression))
    {
        // ...
    }
}

public void FilterQuoteByTrade()
{
    try
    {
        this.grdvSwapQuoteList.ActiveFilter.BeginUpdate();
        string filter = CFETSTradeUIHelper.FilterQuoteByTrade(tradeLst, "MYSIDE_DISPLAY", null, true);
        this.GridAssistSavers.GridAssistSaverList[1].Assist.SetGridFilterRememberManual(this.grdvSwapQuoteList, filter);
        this.grdvSwapQuoteList.ActiveFilterEnabled = true;
    }
    finally
    {
        this.grdvSwapQuoteList.ActiveFilter.EndUpdate();
    }
}

// WPF
this.grdcSwapTradList.FilterChanged += this.grdvSwapTradeList_ActiveFilter_Changed;

protected void grdvSwapTradeList_ActiveFilter_Changed(object sender, EventArgs e)
{
    if (string.IsNullOrEmpty(this.grdcSwapTradList.FilterString))
    {
        // ...
    }
}

public void FilterQuoteByTrade()
{
    string filter = CFETSTradeUIHelper.FilterQuoteByTrade(tradeLst, "MYSIDE_DISPLAY", null, true);
    this.GridAssistSavers.GridAssistSaverList[1].Assist.SetGridFilterRememberManual(this.grdvSwapQuoteList, filter);
    this.grdcSwapQuoteList.FilterString = filter;
}
```

---

## 网格双击事件变化

**规则内容**：

在 WinForms 中，网格双击事件是 `DoubleClick`；在 WPF 中，改为 `RowDoubleClick`，且事件参数类型变化。

**示例：**
```csharp
// WinForms
this.grdvTradeList.DoubleClick += this.grdvTradeList_DoubleClick;

private void grdvTradeList_DoubleClick(object sender, EventArgs e)
{
    if (this.grdvTradeList.GetFocusedRow() is XPOTCTrade trade)
    {
        // ...
    }
}

// WPF
this.grdvTradeList.RowDoubleClick += this.grdvTradeList_DoubleClick;

private void grdvTradeList_DoubleClick(object sender, RowDoubleClickEventArgs e)
{
    var trade = grdcTradeList.CurrentItem as XPOTCTrade;
    if (trade != null)
    {
        // ...
    }
}
```

---

## 网格当前项访问方式变化

**规则内容**：

在 WinForms 中，网格当前行通过 `FocusedRowObjectChanged` 事件和 `GetFocusedRow()` 方法访问；在 WPF 中，改为 `CurrentItemChanged` 事件和 `CurrentItem` 属性访问，事件参数类型调整为 `CurrentItemChangedEventArgs`。

**示例：**
```csharp
// WinForms
this.grdvTradeList.FocusedRowObjectChanged += this.grdvTradeList_FocusedRowChanged;

private void grdvTradeList_FocusedRowChanged(object sender, FocusedRowObjectChangedEventArgs e)
{
    XPOTCTrade trade = this.grdvTradeList.GetFocusedRow() as XPOTCTrade;
    // ...
}

// WPF
this.grdcTradeList.CurrentItemChanged += this.grdcTradeList_CurrentItemChanged;

private void grdcTradeList_CurrentItemChanged(object sender, CurrentItemChangedEventArgs e)
{
    XPOTCTrade trade = this.grdcTradeList.CurrentItem as XPOTCTrade;
    // ...
}
```

---

## 网格行数据获取方式变化

**规则内容**：

在 WinForms 中，通过 `grdv.GetRow(e.RowHandle)` 获取行数据；在 WPF 中，对于 `CustomUnboundColumnData` 事件，事件订阅从 `grdv` 移到 `grdc`，参数类型从 `CustomColumnDataEventArgs` 变为 `GridColumnDataEventArgs`，使用 `grdc.GetRowByListIndex(e.ListSourceRowIndex)` 获取行数据。

**示例：**
```csharp
// WinForms
this.grdvTradeList.CustomUnboundColumnData += this.grdvTradeList_CustomUnboundColumnData;

private void grdvTradeList_CustomUnboundColumnData(object sender, CustomColumnDataEventArgs e)
{
    int rowIndex = this.grdvTradeList.GetRowHandle(e.ListSourceRowIndex);
    XPOTCTrade trade = this.grdvTradeList.GetRow(rowIndex) as XPOTCTrade;
    // ...
}

// WPF
this.grdcTradeList.CustomUnboundColumnData += this.grdvTradeList_CustomUnboundColumnData;

private void grdvTradeList_CustomUnboundColumnData(object sender, GridColumnDataEventArgs e)
{
    XPOTCTrade trade = this.grdcTradeList.GetRowByListIndex(e.ListSourceRowIndex) as XPOTCTrade;
    // ...
}
```

---

## 网格选择事件参数类型变化

**规则内容**：

在 WinForms 中，网格选择变化事件是 `CellValueChanging`，使用 `CellValueChangedEventArgs` 参数；在 WPF 中，改为 `SelectionChanged` 事件，事件订阅从 `grdv` 移到 `grdc`，使用 `GridSelectionChangedEventArgs` 参数。

**示例：**
```csharp
// WinForms
this.grdvTradeList.CellValueChanging += this.grdvTradeList_CellValueChanging;

private void grdvTradeList_CellValueChanging(object sender, CellValueChangedEventArgs e)
{
    if (e.Column.FieldName == "colSelect")
    {
        if ((bool)e.Value)
        {
            // ...
        }
    }
}

// WPF
this.grdcTradeList.SelectionChanged += this.grdvTradeList_CellValueChanging;

private void grdvTradeList_CellValueChanging(object sender, GridSelectionChangedEventArgs e)
{
    if (e.Action == CollectionChangeAction.Add)
    {
        // ...
    }
}
```

---

## 网格行数变化事件转换

**规则内容**：

在 WinForms 中，网格行数变化事件是 `RowCountChanged`，挂载在 `grdv` 上；在 WPF 中，事件名称保持不变，但挂载位置从 `grdv` 移动到 `grdc`。

**示例：**
```csharp
// WinForms
this.grdvTradeList.RowCountChanged += this.grdvTradeList_RowCountChanged;

private void grdvTradeList_RowCountChanged(object sender, EventArgs e)
{
    // ...
}

// WPF
this.grdcTradeList.RowCountChanged += this.grdvTradeList_RowCountChanged;

private void grdvTradeList_RowCountChanged(object sender, EventArgs e)
{
    // ...
}
```

---

## 网格列显示文本事件转换

**规则内容**：

在 WinForms 中，网格列显示文本事件是 `CustomColumnDisplayText`，挂载在 `grdv` 上；在 WPF 中，事件名称保持不变，但挂载位置从 `grdv` 移到 `grdc`。

**示例：**
```csharp
// WinForms
this.grdvTradeList.CustomColumnDisplayText += this.grdvTradeList_CustomColumnDisplayText;

private void grdvTradeList_CustomColumnDisplayText(object sender, CustomColumnDisplayTextEventArgs e)
{
    // ...
}

// WPF
this.grdcTradeList.CustomColumnDisplayText += this.grdvTradeList_CustomColumnDisplayText;

private void grdvTradeList_CustomColumnDisplayText(object sender, CustomColumnDisplayTextEventArgs e)
{
    // ...
}
```