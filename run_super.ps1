# WinForms → WPF Super Conversion Script
# 支持 WinForms 到 WPF 的转换、审查和修复

# ==================== 配置 ====================
$CONFIG = @{
    InputDir        = [System.IO.Path]::Combine($PSScriptRoot, "winform")
    WpfDir          = [System.IO.Path]::Combine($PSScriptRoot, "wpf")
    WpfFixDir       = [System.IO.Path]::Combine($PSScriptRoot, "wpf_fix")
    TranscodeAgent  = [System.IO.Path]::Combine($PSScriptRoot, "prompt", "agents", "transcode", "transcode_single.agent.md")
    ReviewAgent     = [System.IO.Path]::Combine($PSScriptRoot, "prompt", "agents", "review", "review_single.agent.md")
    FixAgent        = [System.IO.Path]::Combine($PSScriptRoot, "prompt", "agents", "fix", "fix_single.agent.md")
    TimeoutSec      = 21600  # 6小时超时
    MaxConcurrency  = 1
}

# 设置编码
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# ==================== 工具函数 ====================

# 错误分类定义
$ErrorCategories = @{
    FileNotFound = "ERROR_FILE_NOT_FOUND"
    FileReadError = "ERROR_FILE_READ"
    IflowTimeout = "ERROR_IFLOW_TIMEOUT"
    IflowExecutionError = "ERROR_IFLOW_EXECUTION"
    OutputWriteError = "ERROR_OUTPUT_WRITE"
    InvalidParameter = "ERROR_INVALID_PARAMETER"
    UnknownError = "ERROR_UNKNOWN"
}

# 错误日志函数
function Write-ErrorLog {
    param(
        [string]$ErrorCode,
        [string]$ErrorMessage,
        [string]$StackTrace = "",
        [string]$FilePath = ""
    )
    
    $logDir = [System.IO.Path]::Combine($PSScriptRoot, "logs")
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    
    $logFile = [System.IO.Path]::Combine($logDir, "errors_$(Get-Date -Format 'yyyyMMdd').log")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    $logEntry = "[$timestamp] [$ErrorCode] $ErrorMessage"
    if ($StackTrace) {
        $logEntry += "`nStackTrace: $StackTrace"
    }
    if ($FilePath) {
        $logEntry += "`nFilePath: $FilePath"
    }
    $logEntry += "`n" + ("-" * 80) + "`n"
    
    Add-Content -Path $logFile -Value $logEntry -Encoding UTF8
}

# 清理非.cs/.xaml/.md文件
function Remove-NonTargetFiles {
    param([string]$Directory)

    if (-not (Test-Path $Directory)) { return }

    $deleted = 0
    $kept = 0

    Get-ChildItem -Path $Directory -Recurse -File | ForEach-Object {
        $ext = $_.Extension.ToLower()
        if ($ext -in @('.cs', '.xaml', '.md')) {
            $kept++
        } else {
            Remove-Item $_.FullName -Force
            $deleted++
        }
    }

    Write-Host "清理完成: 删除 $deleted 个文件，保留 $kept 个文件" -ForegroundColor Green
}

# 分组WinForms文件
function Get-WinformFileGroups {
    param([string]$InputDir)

    $groups = @{}
    $allFiles = Get-ChildItem -Path $InputDir -Filter "*.cs" -File -Recurse

    foreach ($file in $allFiles) {
        $isDesigner = $file.Name -imatch '\.designer\.cs$'
        $prefix = if ($isDesigner) { $file.Name -ireplace '\.designer\.cs$', '' } else { $file.BaseName }

        $relativePath = if ($file.Directory.FullName -eq $InputDir) {
            ""
        } else {
            $file.Directory.FullName.Substring($InputDir.Length + 1)
        }

        $groupKey = if ($relativePath) { [System.IO.Path]::Combine($relativePath, $prefix) } else { $prefix }

        if (-not $groups.ContainsKey($groupKey)) {
            $groups[$groupKey] = @{
                RelativePath     = $relativePath
                Prefix           = $prefix
                WinformDesigner  = $null
                WinformCs        = $null
            }
        }

        if ($isDesigner) {
            $groups[$groupKey].WinformDesigner = $file.FullName
        } else {
            $groups[$groupKey].WinformCs = $file.FullName
        }
    }

    return $groups
}

# ==================== 主程序 ====================

# 打印标题
Write-Host ("=" * 60)
Write-Host "x.AI.Coder 代码助手"
Write-Host ("=" * 60)

# 验证输入目录
if (-not (Test-Path $CONFIG.InputDir)) {
    Write-Host "错误: 输入目录不存在: $($CONFIG.InputDir)" -ForegroundColor Red
    exit 1
}

# 选择执行模式
Write-Host "`n请选择执行模式:"
Write-Host "  1 - 仅转换"
Write-Host "  2 - 仅审查"
Write-Host "  3 - 全部执行 (转换 -> 审查 -> 修复)"
$modeInput = Read-Host "请输入选项 (1/2/3)"

$mode = switch ($modeInput.Trim()) {
    "1" { 1 }
    "2" { 2 }
    "3" { 3 }
    default { 3 }
}

$modeNames = @{ 1 = "仅转换"; 2 = "仅审查"; 3 = "全部执行" }
Write-Host "`n已选择: $($modeNames[$mode])" -ForegroundColor Green

# 创建输出目录
New-Item -Path $CONFIG.WpfDir -ItemType Directory -Force | Out-Null
New-Item -Path $CONFIG.WpfFixDir -ItemType Directory -Force | Out-Null

# 清理输入目录
Write-Host "`n正在清理输入目录..."
Remove-NonTargetFiles -Directory $CONFIG.InputDir

# 分析WinForms文件
Write-Host "`n正在分析 WinForms 文件..."
$winformGroups = Get-WinformFileGroups -InputDir $CONFIG.InputDir

if ($winformGroups.Count -eq 0) {
    Write-Host "警告: 没有找到需要处理的 WinForms 文件" -ForegroundColor Yellow
    exit 0
}

Write-Host "找到 $($winformGroups.Count) 个文件组需要处理"
Write-Host "最大并发数: $($CONFIG.MaxConcurrency)`n"

# 并行处理文件组
$results = [HashTable]::Synchronized(@{})
$counter = 0
$groupList = $winformGroups.GetEnumerator() | Sort-Object Key

$parallelResults = $groupList | ForEach-Object -ThrottleLimit $CONFIG.MaxConcurrency -Parallel {
    $entry = $_
    $group = $entry.Value
    $key = $entry.Key

    $currentIndex = [System.Threading.Interlocked]::Increment([ref]$using:counter)
    $totalCount = $using:winformGroups.Count
    $mode = $using:mode
    $CONFIG = $using:CONFIG

    # ==================== 并行块内的函数定义 ====================

    # 执行iflow命令
    function Invoke-Iflow {
        param(
            [string]$Prompt,
            [string]$StepName = "Unknown",
            [string]$FilePath = ""
        )

        $startTime = Get-Date
        $env:PYTHONIOENCODING = "utf-8"

        try {
            $job = Start-Job -ScriptBlock {
                param($p, $dir)
                Push-Location $dir
                try { & iflow --thinking -p $p 2>&1 } finally { Pop-Location }
            } -ArgumentList $Prompt, $using:PSScriptRoot

            $completed = $job | Wait-Job -Timeout $CONFIG.TimeoutSec

            if ($completed) {
                $output = Receive-Job -Job $job
                $success = ($job.State -eq 'Completed')

                # 检查是否有错误
                if (-not $success) {
                    $errorMessage = "Iflow job failed with state: $($job.State)"
                    if ($job.Error) {
                        $errorMessage += "`nError: $($job.Error | Out-String)"
                    }
                    Write-ErrorLog -ErrorCode $ErrorCategories.IflowExecutionError -ErrorMessage $errorMessage -StackTrace ($job.Error | Out-String) -FilePath $FilePath
                }
            } else {
                $output = @("Timeout after $($CONFIG.TimeoutSec) seconds")
                $success = $false
                $errorMessage = "Iflow job timed out after $($CONFIG.TimeoutSec) seconds"
                Write-ErrorLog -ErrorCode $ErrorCategories.IflowTimeout -ErrorMessage $errorMessage -FilePath $FilePath
                Stop-Job -Job $job
            }

            Remove-Job -Job $job -Force

            $elapsedTime = "{0:N2}" -f ((Get-Date) - $startTime).TotalMinutes

            return @{
                Success     = $success
                Message     = $output -join "`n"
                ElapsedTime = $elapsedTime
                ErrorCode   = if (-not $success) { $ErrorCategories.IflowExecutionError } else { "" }
            }
        } catch {
            $errorMessage = "Exception in Invoke-Iflow: $($_.Exception.Message)"
            Write-ErrorLog -ErrorCode $ErrorCategories.UnknownError -ErrorMessage $errorMessage -StackTrace $_.ScriptStackTrace -FilePath $FilePath
            return @{
                Success     = $false
                Message     = $errorMessage
                ElapsedTime = "{0:N2}" -f ((Get-Date) - $startTime).TotalMinutes
                ErrorCode   = $ErrorCategories.UnknownError
            }
        }
    }

    # 执行转换步骤
    function Invoke-Transcode {
        param(
            [hashtable]$FileGroup,
            [string]$GroupKeyDisplay,
            [int]$Index,
            [int]$Total
        )

        $relativePath = $FileGroup.RelativePath
        $prefix = $FileGroup.Prefix
        $outputDir = if ($relativePath) { [System.IO.Path]::Combine($CONFIG.WpfDir, $relativePath) } else { $CONFIG.WpfDir }

        New-Item -Path $outputDir -ItemType Directory -Force | Out-Null

        $filesList = @()
        if ($FileGroup.WinformDesigner) { $filesList += $FileGroup.WinformDesigner }
        if ($FileGroup.WinformCs) { $filesList += $FileGroup.WinformCs }

        if ($filesList.Count -eq 0) {
            Write-Host "[$Index/$Total] [$GroupKeyDisplay] 没有文件需要转换" -ForegroundColor Yellow
            return @{ Success = $true }
        }

        $prompt = Get-Content -Path $CONFIG.TranscodeAgent -Encoding UTF8 -Raw
        $prompt = $prompt -replace '\{FILES\}', ($filesList -join ',')
        $prompt = $prompt -replace '\{OUTPUT_DIR\}', $outputDir
        $prompt = $prompt -replace '\{LOG_FILE\}', "$prefix.trans.log.md"

        Write-Host "[$Index/$Total] [$GroupKeyDisplay] 步骤 1/3: 正在转换..."
        $result = Invoke-Iflow -Prompt $prompt

        if ($result.Success) {
            Write-Host "[$Index/$Total] [$GroupKeyDisplay] 转换完成 (耗时: $($result.ElapsedTime) 分钟)" -ForegroundColor Green

            # 更新文件组中的WPF文件路径
            $wpfXaml = [System.IO.Path]::Combine($outputDir, "$prefix.xaml")
            $wpfCs = [System.IO.Path]::Combine($outputDir, "$prefix.xaml.cs")
            $transLog = [System.IO.Path]::Combine($outputDir, "$prefix.trans.log.md")

            if (Test-Path $wpfXaml) { $FileGroup.WpfXaml = $wpfXaml }
            if (Test-Path $wpfCs) { $FileGroup.WpfCs = $wpfCs }
            if (Test-Path $transLog) { $FileGroup.TransLog = $transLog }

            return @{ Success = $true; FileGroup = $FileGroup }
        } else {
            Write-Host "[$Index/$Total] [$GroupKeyDisplay] 转换失败 (耗时: $($result.ElapsedTime) 分钟)" -ForegroundColor Red
            return @{ Success = $false; Error = "转换失败: $($result.Message)" }
        }
    }

    # 执行审查步骤
    function Invoke-Review {
        param(
            [hashtable]$FileGroup,
            [string]$GroupKeyDisplay,
            [int]$Index,
            [int]$Total
        )

        $relativePath = $FileGroup.RelativePath
        $prefix = $FileGroup.Prefix
        $outputDir = if ($relativePath) { [System.IO.Path]::Combine($CONFIG.WpfDir, $relativePath) } else { $CONFIG.WpfDir }

        # 检查必需的文件：WinformCs 和 WpfCs 是必须的
        # WinformDesigner 和 WpfXaml 都是可选的（纯代码文件转换）
        $requiredFiles = @()
        if ($FileGroup.WinformCs) { $requiredFiles += $FileGroup.WinformCs }
        if ($FileGroup.WpfCs) { $requiredFiles += $FileGroup.WpfCs }

        if ($requiredFiles.Count -lt 2) {
            Write-Host "[$Index/$Total] [$GroupKeyDisplay] 缺少审查所需的文件" -ForegroundColor Yellow
            return @{ Success = $true }
        }

        $filesList = @(
            $FileGroup.WinformDesigner,
            $FileGroup.WpfXaml,
            $FileGroup.WinformCs,
            $FileGroup.WpfCs
        ) | Where-Object { $_ -ne $null }

        $prompt = Get-Content -Path $CONFIG.ReviewAgent -Encoding UTF8 -Raw
        $prompt = $prompt -replace '\{FILES\}', ($filesList -join ',')
        $prompt = $prompt -replace '\{OUTPUT_DIR\}', $outputDir
        $prompt = $prompt -replace '\{REPORT_FILE\}', "$prefix.review.log.md"

        Write-Host "[$Index/$Total] [$GroupKeyDisplay] 步骤 2/3: 正在审查..."
        $result = Invoke-Iflow -Prompt $prompt

        if ($result.Success) {
            Write-Host "[$Index/$Total] [$GroupKeyDisplay] 审查完成 (耗时: $($result.ElapsedTime) 分钟)" -ForegroundColor Green
            $reviewLog = [System.IO.Path]::Combine($outputDir, "$prefix.review.log.md")
            if (Test-Path $reviewLog) { $FileGroup.ReviewLog = $reviewLog }
            return @{ Success = $true; FileGroup = $FileGroup }
        } else {
            Write-Host "[$Index/$Total] [$GroupKeyDisplay] 审查失败 (耗时: $($result.ElapsedTime) 分钟)" -ForegroundColor Red
            return @{ Success = $false; Error = "审查失败: $($result.Message)" }
        }
    }

    # 执行修复步骤
    function Invoke-Fix {
        param(
            [hashtable]$FileGroup,
            [string]$GroupKeyDisplay,
            [int]$Index,
            [int]$Total
        )

        $relativePath = $FileGroup.RelativePath
        $prefix = $FileGroup.Prefix
        $outputDir = if ($relativePath) { [System.IO.Path]::Combine($CONFIG.WpfFixDir, $relativePath) } else { $CONFIG.WpfFixDir }

        New-Item -Path $outputDir -ItemType Directory -Force | Out-Null

        # 检查必需的文件：WinformCs、WpfCs、TransLog、ReviewLog 是必须的
        # WinformDesigner 和 WpfXaml 都是可选的（纯代码文件转换）
        $requiredFiles = @()
        if ($FileGroup.WinformCs) { $requiredFiles += $FileGroup.WinformCs }
        if ($FileGroup.WpfCs) { $requiredFiles += $FileGroup.WpfCs }
        if ($FileGroup.TransLog) { $requiredFiles += $FileGroup.TransLog }
        if ($FileGroup.ReviewLog) { $requiredFiles += $FileGroup.ReviewLog }

        if ($requiredFiles.Count -lt 4) {
            Write-Host "[$Index/$Total] [$GroupKeyDisplay] 缺少修复所需的文件" -ForegroundColor Yellow
            return @{ Success = $true }
        }

        $filesList = @(
            $FileGroup.WinformDesigner,
            $FileGroup.WpfXaml,
            $FileGroup.WinformCs,
            $FileGroup.WpfCs,
            $FileGroup.TransLog,
            $FileGroup.ReviewLog
        ) | Where-Object { $_ -ne $null }

        $prompt = Get-Content -Path $CONFIG.FixAgent -Encoding UTF8 -Raw
        $prompt = $prompt -replace '\{FILES\}', ($filesList -join ',')
        $prompt = $prompt -replace '\{OUTPUT_DIR\}', $outputDir
        $prompt = $prompt -replace '\{LOG_FILE\}', "$prefix.super.log.md"

        Write-Host "[$Index/$Total] [$GroupKeyDisplay] 步骤 3/3: 正在修复..."
        $result = Invoke-Iflow -Prompt $prompt

        if ($result.Success) {
            Write-Host "[$Index/$Total] [$GroupKeyDisplay] 修复完成 (耗时: $($result.ElapsedTime) 分钟)" -ForegroundColor Green
            return @{ Success = $true }
        } else {
            Write-Host "[$Index/$Total] [$GroupKeyDisplay] 修复失败 (耗时: $($result.ElapsedTime) 分钟)" -ForegroundColor Red
            return @{ Success = $false; Error = "修复失败: $($result.Message)" }
        }
    }

    # ==================== 处理逻辑 ====================

    $fileGroup = @{
        RelativePath     = $group.RelativePath
        Prefix           = $group.Prefix
        WinformDesigner  = $group.WinformDesigner
        WinformCs        = $group.WinformCs
        WpfXaml          = $null
        WpfCs            = $null
        TransLog         = $null
        ReviewLog        = $null
    }

    $relativePath = $group.RelativePath
    $prefix = $group.Prefix
    $groupKeyDisplay = if ($relativePath) { [System.IO.Path]::Combine($relativePath, $prefix) } else { $prefix }

    Write-Host ("-" * 60)
    Write-Host "处理文件组 [$currentIndex/$totalCount]: $groupKeyDisplay"
    Write-Host ("-" * 60)

    $result = @{
        GroupKey          = $key
        TranscodeSuccess  = $false
        ReviewSuccess     = $false
        FixSuccess        = $false
        Error             = $null
    }

    # 步骤1: 转换
    if ($mode -eq 1 -or $mode -eq 3) {
        $transResult = Invoke-Transcode -FileGroup $fileGroup -GroupKeyDisplay $groupKeyDisplay -Index $currentIndex -Total $totalCount
        if ($transResult.Success) {
            $result.TranscodeSuccess = $true
            if ($transResult.FileGroup) { $fileGroup = $transResult.FileGroup }
        } else {
            $result.Error = $transResult.Error
            return $result
        }
    } elseif ($mode -eq 2) {
        $result.TranscodeSuccess = $true
    }

    # 步骤2: 审查
    if ($mode -eq 2 -or $mode -eq 3) {
        $reviewResult = Invoke-Review -FileGroup $fileGroup -GroupKeyDisplay $groupKeyDisplay -Index $currentIndex -Total $totalCount
        if ($reviewResult.Success) {
            $result.ReviewSuccess = $true
            if ($reviewResult.FileGroup) { $fileGroup = $reviewResult.FileGroup }
        } else {
            $result.Error = $reviewResult.Error
            return $result
        }
    } elseif ($mode -eq 1) {
        $result.ReviewSuccess = $true
    }

    # 步骤3: 修复
    if ($mode -eq 3) {
        $fixResult = Invoke-Fix -FileGroup $fileGroup -GroupKeyDisplay $groupKeyDisplay -Index $currentIndex -Total $totalCount
        if ($fixResult.Success) {
            $result.FixSuccess = $true
        } else {
            $result.Error = $fixResult.Error
        }
    } else {
        $result.FixSuccess = $true
    }

    return $result
}

# 收集结果
foreach ($item in $parallelResults) {
    $results[$item.GroupKey] = $item
}

# 输出摘要
Write-Host "`n" + ("=" * 60)
Write-Host "转换摘要"
Write-Host ("=" * 60)

$fullSuccess = 0
$partialSuccess = 0
$failed = 0

foreach ($result in $results.Values) {
    if ($result.TranscodeSuccess -and $result.ReviewSuccess -and $result.FixSuccess) {
        $fullSuccess++
    } elseif ($result.TranscodeSuccess) {
        $partialSuccess++
    } else {
        $failed++
    }
}

Write-Host "文件组总数: $($results.Count)"
Write-Host "完全成功: $fullSuccess"
Write-Host "部分成功: $partialSuccess"
Write-Host "失败: $failed"

if ($failed -gt 0) {
    Write-Host "`n失败的文件组:"
    $results.Values | Where-Object { -not $_.TranscodeSuccess } | ForEach-Object {
        Write-Host "  - $($_.GroupKey): $($_.Error)" -ForegroundColor Red
    }
}

if ($partialSuccess -gt 0) {
    Write-Host "`n部分成功的文件组:"
    $results.Values | Where-Object { -not ($_.TranscodeSuccess -and $_.ReviewSuccess -and $_.FixSuccess) -and $_.TranscodeSuccess } | ForEach-Object {
        $status = @()
        if (-not $_.ReviewSuccess) { $status += "审查失败" }
        if (-not $_.FixSuccess) { $status += "修复失败" }
        Write-Host "  - $($_.GroupKey): $($status -join ', ')" -ForegroundColor Yellow
    }
}

Write-Host "`n输出位置:"
Write-Host "  WPF 文件: $($CONFIG.WpfDir)"
Write-Host "  修复后的文件: $($CONFIG.WpfFixDir)"

Write-Host ("=" * 60)

exit $(if ($failed -gt 0) { 1 } else { 0 })