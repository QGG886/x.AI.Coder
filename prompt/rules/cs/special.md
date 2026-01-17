# 特殊场景规则

---

## 窗体关闭事件转换


**规则内容**：

1. `FrmBase_Closing` 方法参数从 `FormClosingEventArgs` 改为 `EventArgs`
2. **删除**定时器 `Dispose()` 调用（WPF 中不需要释放）

**示例**：
```csharp
// WinForms
protected override void FrmBase_Closing(object sender, FormClosingEventArgs e)
{
    // 释放定时器
    if (this._timer != null)
    {
        this._timer.Stop();
        this._timer.Dispose();
        this._timer = null;
    }
}

// WPF
protected override void FrmBase_Closing(object sender, EventArgs e)
{
    // 释放定时器
    if (this._timer != null)
    {
        this._timer.Stop();
        this._timer = null;
    }
}
```

---

## 方法参数转换


**规则内容**：

- `CFETSTradeUIHelper.ShowCertificateMaturingInfo` 去掉第三个参数（`this.lcServiceStatus_Paint`）

**示例**：
```csharp
// WinForms
this._daydifference = CFETSTradeUIHelper.ShowCertificateMaturingInfo(this.labCerLight, this.labCerTip, this.lcServiceStatus_Paint);

// WPF
this._daydifference = CFETSTradeUIHelper.ShowCertificateMaturingInfo(this.labCerLight, this.labCerTip);
```

---

## 状态灯修改方案（页面底部的状态灯，非表格中的）

**规则内容**：

**WinForms 实现：**
- 使用 Label 控件挂载 Paint 事件
- 在 Paint 事件中使用 GDI+ 的 FillEllipse 和 DrawEllipse 绘制圆形指示灯
- 根据市场状态从 GetColorByMktStatus 获取 Brush 进行填充
- 状态变更时更新私有字段并调用 Refresh() 触发重绘

**WPF 实现：**
- 使用 Ellipse 控件
- 通过 CreateSolidIndicator 方法创建实心圆形指示灯
- Fill 属性直接赋值为根据市场状态从 GetColorByMktStatus 获取的 SolidColorBrush
- 状态变更时更新私有字段，在 OnMktStatusChangeed 中创建或更新 Ellipse 实例并替换到布局中
- 无需通过 refresh 触发 paint 事件重绘

**示例代码**：
```csharp
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

---

## 分隔条用法变化（`splitContainerControl1`）

**规则内容**：

- 原来是一个分隔条控件，命名基本是类似 `splitContainerControl` 的
- 现在改成 `LayoutGroup` 默认的了
- 原来取 `SplitterPosition` 的地方改成取 `ActualHeight` 即可

**示例**：
```csharp
// WinForms
int position = this.splitContainerControl1.SplitterPosition;

// WPF
double position = this.splitContainerControl1.ActualHeight;
```