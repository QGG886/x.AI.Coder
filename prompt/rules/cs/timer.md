# 定时器规则

## 定时器转换

**规则内容**：

1. 保持 `Timer` 类型不变（有全局别名）
2. `Interval = xxx` → `Interval = TimeSpan.FromSeconds(xxx)`（或 `TimeSpan.FromMilliseconds(xxx)` 等）
3. **删除** `Dispose()` 调用（WPF 中不需要释放定时器）
4. `Interval == 0` → `Interval == TimeSpan.Zero`
5. **特别注意**：如果原来定时器任务里有关于颜色刷新和倒计时刷新的话，需要提醒用户手动删除相关内容

**示例：**
```csharp
// WinForms
this._timer = new Timer();
this._timer.Interval = 1000;
this._timer.Tick += this.AutoRefresh;
this._timer.Start();

// 释放定时器
if (this._timer != null)
{
    this._timer.Stop();
    this._timer.Dispose();
    this._timer = null;
}

// WPF
this._timer = new Timer();
this._timer.Interval = TimeSpan.FromSeconds(1);
this._timer.Tick += this.AutoRefresh;
this._timer.Start();

// 释放定时器
if (this._timer != null)
{
    this._timer.Stop();
    this._timer = null;
}
```

**详细说明：**

- **Interval 类型转换**：在 WinForms 中，定时器的 `Interval` 属性是 `int` 类型（毫秒）；在 WPF 中，是 `TimeSpan` 类型
- **Dispose 调用删除**：在 WinForms 中，定时器需要调用 `Dispose()` 方法释放资源；在 WPF 中，删除 `Dispose()` 调用，只需设置 `null`