# WinForms → WPF 迁移规则说明

## 总体规则

1. 必须基于源代码生成兼容 WPF 的后台代码，**严格不允许改变代码顺序**（包括控件初始化、属性设置、事件订阅顺序），以便与原 WinForms 代码逐行对比。
2. 非必要不得改动任何代码逻辑、变量名、方法名或事件名（即使命名不合理也必须保持一致）。
3. 事件替换后，**必须保持原有事件处理方法名称不变**，仅替换事件类型或参数类型。
4. 对于 WPF 中**无法直接对应**的属性、方法或事件，必须在该行添加**中文行内注释**说明原因及处理方式。
5. 命名空间中将原 `xIR.UI` 统一替换为 `XUI`，其余路径保持完全一致。
6. WinForms 的 `OnShow` 事件内代码，直接迁移到对应窗体 `FrmLoad` 方法的**最底部**，保持原有顺序。

## 通用属性规则（适用于大部分控件）
* `LayoutVisibility` → `Visibility`
  * `Always` → `Visible`
  * `Never` → `Collapsed`
* `Visible` → `Visibility`
  * 赋值时直接使用 `.ToVisibility()`
  * 判断时与 `Visibility.Visible` 比较
* `ForeColor` → `Foreground`
* `BackColor` → `Background`
* `Enabled` → `IsEnabled`
* `Text`
  * `TextBlock` / `TextBox` 保持 `Text`
  * `Button` / `Label` 使用 `Content`
* `Dock` → 转换为对应的 WPF 布局属性（如 `DockPanel.Dock` 或 Grid 行列）
* `Checked` → `IsChecked`
  * 读取值时由 `bool` 改为 `bool?`，需要使用 `.Value` 或等价处理
* `Properties.ReadOnly` → `IsReadOnly`
* `DialogResult` 不做变化（已有全局别名）
* `PageVisible` 仍为 `PageVisible`
  * 原为 `bool`，在判断中需改为与 `Visibility.Visible` 比较
* `SelectedTabPage` → `SelectedContainer
* `Color` 变成 `Brushes`(例如: Color.Yellow -> Brushes.Yellow)

## 表格（Grid）通用规则
* `grdc` 表示 `XIRGridControl`, `grdv` 表示 `XIRTableView`. 我用到的表格命名一定会按照这个作为开头的，所以下面说事件切换什么的，就可以通过这种形式改动，但是不能直接用grdv或者grdc 这是代称，需要根据这个开头找到原name
* 代码中**必须使用包装后的控件类型**，但变量名保持不变

### 1. 表格属性变化@
* `DataSource` → `ItemsSource`
* 原从 `grdv.Columns` 取列 → 改为从 `grdc.Columns` 取
* `OptionsView.ShowFooter` → `ShowTotalSummary`
* `OptionsView.ColumnAutoWidth` → `AutoWidth`
* `BestFitColumns()
  * 转为 `TableView.BestFitColumns()` 或 `GridControl.BestFitColumns()`，按实际控件调整
* `grdv.RowCount` -> `grdc.VisibleRowCount`

### 2. 列属性（`OptionsColumn`）变化
* `OptionsColumn.AllowEdit` → `AllowEditing`（`bool` → `DefaultBoolean`）
* `OptionsColumn.ReadOnly` → `ReadOnly`
* `OptionsColumn.AllowSort` → `AllowSorting`
* 无对应属性时必须添加注释说明“WPF 中无对应属性，已移除”

### 3. 表格事件变化
* 原来的一些`GetRow`方法(例如 `this.grdvSwapQuoteList.GetRow(grdvSwapQuoteList.GetRowHandle(e.ListSourceRowIndex))`) 可以直接改成`grdc.CurrentItem`即可
* 
* `grdv.DoubleClick` → `grdv.RowDoubleClick`
* `grdv.RefreshData` -> `grdc.RefreshData`
* `RefreshDataSource()` → `RefreshData()`
* `CustomColumnDisplayText` 事件从 `grdv` 移到 `grdc`
* `CustomUnboundColumnData` 事件从 `grdv` 移到 `grdc`, 参数从`CustomColumnDataEventArgs`改成`GridColumnDataEventArgs`
* `grdv`的`FocusedRowObjectChanged` 事件 换成`grdc.CurrentItemChanged`,参数类型调整为`CurrentItemChangedEventArgs`
* `grdv.RowCountChanged` 移到 `grdc`
* `grdv.RowCellStyle` 不需要移动
* `grdv.CustomDrawCell` 不需要移动
* `grdv.CellValueChanging` 不需要移动
* `grdv.ActiveFilter.Changed` -> `grdc.FilterChanged`
	* 原来读取`(sender as ViewFilter).Expression` 获取筛选条件，现在直接可以访问 `grdc.FilterString`
	* 原来内部大概是过滤条件清空时，取消部分行的选择，可以的话参考下文这个代码片段实现
	  ``` C#
	  protected void grdvTradeList_ActiveFilter_Changed(object sender, EventArgs e)
      {
          if (string.IsNullOrEmpty(this.grdcTradeList.FilterString))
          {
              var quoteGrid = this.grdcQuoteList;
              var view = quoteGrid.View as TableView;

              if (view == null) return;

              var selectedHandles = this.grdcQuoteList.GetSelectedRowHandles().ToList();

              for (int i = selectedHandles.Count - 1; i >= 0; i--)
              {
                  int rowHandle = selectedHandles[i];

                  var quote = quoteGrid.GetRow(rowHandle) as XPCFETSTradeBase;

                  if (quote != null && (quote.SEND_RECV_FLAG == SendRecvType.RECV || quote.WaitSendQuote))
                  {
                      this.grdcQuoteList.UnselectItem(rowHandle);
                  }
              }
          }
      }
	  ```
* 事件处理方法名保持不变，仅修改事件类型或参数类型

### 4. 表格右键变化
* `DXMenuItem`的快捷键 从 `Shortcut.CtrlG` 变成 `new KeyGesture`（例如  `Shortcut.CtrlG-> new KeyGesture(Key.G, ModifierKeys.Control)`）
* 删除 全选/取消 事件 与其代码
* 在调用 AddMenuItem时，无需从grdv改动到grdc 还是需要grdv的

## Tab 相关变化规则
* 事件从 `SelectedPageChanged` → `SelectionChanged`
* 事件处理方法名不变
* 事件参数从 `TabPageChangedEventArgs` → `TabControlSelectionChangedEventArgs`
* 原访问 `SelectedTabPage` 的地方改为 `SelectedContainer`
* 删除 `BeginUpdate()` / `EndUpdate()`（例如  this.layoutControlMain.BeginUpdate(); 这些代码删除即可）
* `PageVisible` 变成 `Visibility`, 注意赋值需要在原来的bool后加上`.ToVisibility()`

## 定时器规则
* 不再需要释放，删除 `Dispose()` 调用
* `Interval = xxx` → `Interval = new TimeSpan(xxx)`
* `Interval == 0` → `Interval == TimeSpan.Zero`

## 按钮与 Label 规则
* Button：`Text` → `Content`
* Label：`Text` → `Content`
* `Visible`、`Enabled` 等属性按通用规则处理

## 状态灯修改方案（不是表格里的状态灯，是页面底部的）
* winform中使用 Label 控件挂载 Paint 事件，在 Paint 事件中使用 GDI+ 的 FillEllipse 和 DrawEllipse 绘制圆形指示灯，根据市场状态从 GetColorByMktStatus 获取 Brush 进行填充。状态变更时更新私有字段并调用 Refresh() 触发重绘。在wpf里，使用 Ellipse 控件，通过 CreateSolidIndicator 方法创建实心圆形指示灯，Fill 属性直接赋值为根据市场状态从 GetColorByMktStatus 获取的 SolidColorBrush。状态变更时更新私有字段，在 OnMktStatusChangeed 中创建或更新 Ellipse 实例并替换到布局中，无需通过refresh触发paint事件重绘
``` c#
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
* ShowCertificateMaturingInfo 去掉第三个参数

## 分隔条用法变化（`splitContainerControl1`）
* 原来是一个分隔条控件，命名基本是类似`splitContainerControl`的，现在改成`LayoutGroup`默认的了，所以原来取`SplitterPosition`的地方改成取`ActualHeight`即可

## 选择列用法变化
* 原来是自定义列，所以很多事件在操作表格的Tag 是一个字典存储选择状态，自定义一列显示选择，现在采用WPF的默认选择列，所以遇到访问`colSelectQuo` 这种类似的选择列时，需要调整成从表格默认选择列支持的方法获取。

## 命名空间自动引入说明
* `InvokeHelper` -> `xQuant.XUI.Utils.Helper`
* `CFETSTradeGridInitial` -> `xQuant.XUI.CFETSTrade.Helper`
* `GridColumn` -> `DevExpress.Xpf.Grid`
* `DefaultBoolean` -> `DevExpress.Utils`
* `CFETSTradeUIHelper` -> `xQuant.XUI.CFETSTrade`
* `DXMenuItem` -> `xQuant.XUI.Controls`
* `EditControlOfIntSecuAcct` -> `xQuant.XUI.Common`
* `TabControlSelectionChangedEventArgs` -> `DevExpress.Xpf.Core`
* `CFETSTradeGridInitial` -> `xQuant.XUI.CFETSTrade.Helper`
* `GridColumnDataEventArgs` -> `DevExpress.Xpf.Grid`
* `GridAssist` -> `xQuant.XUI.Base`
* `EditControlOfCounterParty` -> `xQuant.XUI.Common`
* `XirCalcEdit` -> `xQuant.XUI.Controls`
* `XirHelper` -> `xQuant.XUI.Common`
* `UCBase` -> `xQuant.XUI.Base`

## 命名空间替换规则
* `DevExpress.XtraGrid.Views.Grid`
* `DevExpress.XtraLayout.Utils`
* `xQuant.UI.Logon` -> `xQuant.XUI.Utils.Helper`

## 注释强制要求
* 所有注释 不允许跟在代码行后，必须在修改代码的上一行！
* 所有无法 1:1 对应的迁移点，**必须在原代码行位置添加中文行内注释**
* 注释内容需说明：
  * 原 WinForms 用法
  * WPF 中为何无法直接对应
  * 当前处理方式或删除原因
  * 
**一句话约束**：
> 保持顺序、保持命名、保持逻辑；能等价替换则替换，不能等价替换必须注释说明。