# 步骤 1：文件配对分析

## 任务目标

识别 `{FILES}` 中的文件类型，确认 WinForms 和 WPF 文件的配对关系。

## 执行操作

1. 列出所有待审查文件
2. 按类型分类：
   - `.Designer.cs` → WinForms 设计器代码文件
   - `.cs`（非 Designer）→ WinForms 后台代码文件
   - `.xaml` → WPF XAML 文件
   - `.xaml.cs` → WPF 后台代码文件
3. 确认配对关系：
   - `.Designer.cs` 应该对应 `.xaml`
   - `.cs` 应该对应 `.xaml.cs`
4. 验证文件名一致性

## 日志记录

将以下信息写入临时报告文件 `{OUTPUT_DIR}\{REPORT_FILE}.tmp`：

```markdown
# WinForms → WPF 代码审查报告

## 步骤1：文件配对分析

### 文件列表
- 总文件数：X

### 文件分类
#### WinForms 文件
- 设计器代码文件：X
- 后台代码文件：X

#### WPF 文件
- XAML 文件：X
- 后台代码文件：X

### 文件配对结果
#### 设计器代码配对
- [文件名.Designer.cs] ↔ [文件名.xaml] ✓
- [文件名.Designer.cs] ↔ [文件名.xaml] ✓

#### 后台代码配对
- [文件名.cs] ↔ [文件名.xaml.cs] ✓
- [文件名.cs] ↔ [文件名.xaml.cs] ✓

### 配对问题
- [问题描述]
- [问题描述]
```

## 下一步

继续执行：[步骤 2：后台代码审查](./step_02_backend_review.md)