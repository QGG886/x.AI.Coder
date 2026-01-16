# WinForms → WPF Super Conversion Script
# Runs transcode, review, and fix for each file group sequentially

# Set console encoding to UTF-8
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# Configuration
$INPUT_DIR       = Join-Path $PSScriptRoot "winform"
$WPF_DIR         = Join-Path $PSScriptRoot "wpf"
$SUPER_DIR       = Join-Path $PSScriptRoot "wpf_fix"
$TRANSCODE_AGENT = Join-Path $PSScriptRoot "prompt/agents/transcode/transcode_single.agent.md"
$REVIEW_AGENT    = Join-Path $PSScriptRoot "prompt/agents/review/review_single.agent.md"
$FIX_AGENT       = Join-Path $PSScriptRoot "prompt/agents/fix/fix_single.agent.md"
$TIMEOUT_SEC     = 21600  # 6 hours timeout
$TEST_MODE       = $false  # Set to $true to skip actual iflow execution

# Function to group WinForms files by prefix
function Group-WinformFiles {
    param (
        [string]$InputDir
    )

    $groups = @{}

    $allCsFiles = Get-ChildItem -Path $InputDir -Filter "*.cs" -File -Recurse

    $csFiles       = @()
    $designerFiles = @()

    foreach ($file in $allCsFiles) {
        if ($file.Name -imatch '\.designer\.cs$') {
            $designerFiles += $file
        } else {
            $csFiles += $file
        }
    }

    foreach ($file in $designerFiles) {
        $prefix = $file.Name -ireplace '\.designer\.cs$', ''

        if ($file.Directory.FullName -eq $InputDir) {
            $relativePath = ""
        } else {
            $relativePath = $file.Directory.FullName.Substring($InputDir.Length + 1)
        }

        if (-not $groups.ContainsKey("$relativePath\$prefix")) {
            $groups["$relativePath\$prefix"] = @{
                RelativePath = $relativePath
                Prefix = $prefix
                WinformDesigner = $file.FullName
                WinformCs = $null
            }
        }
        $groups["$relativePath\$prefix"].WinformDesigner = $file.FullName
    }

    foreach ($file in $csFiles) {
        $prefix = $file.BaseName

        if ($file.Directory.FullName -eq $InputDir) {
            $relativePath = ""
        } else {
            $relativePath = $file.Directory.FullName.Substring($InputDir.Length + 1)
        }

        if (-not $groups.ContainsKey("$relativePath\$prefix")) {
            $groups["$relativePath\$prefix"] = @{
                RelativePath = $relativePath
                Prefix = $prefix
                WinformDesigner = $null
                WinformCs = $null
            }
        }
        $groups["$relativePath\$prefix"].WinformCs = $file.FullName
    }

    return $groups
}

# Function to run transcode for a single file group
function Run-TranscodeForGroup {
    param (
        [hashtable]$FileGroup,
        [int]$CurrentIndex,
        [int]$TotalCount
    )

    $relativePath = $FileGroup.RelativePath
    $prefix = $FileGroup.Prefix
    $groupKey = "$relativePath\$prefix"

    $groupOutputDir = Join-Path $WPF_DIR $relativePath
    $logFile = "$prefix.trans.log.md"

    try {
        # Create output directory if it doesn't exist
        if (-not (Test-Path $groupOutputDir)) {
            New-Item -Path $groupOutputDir -ItemType Directory -Force | Out-Null
        }

        # Prepare file list
        $filesList = @()
        if ($FileGroup.WinformDesigner) { $filesList += $FileGroup.WinformDesigner }
        if ($FileGroup.WinformCs) { $filesList += $FileGroup.WinformCs }

        if ($filesList.Count -eq 0) {
            Write-Host "[$CurrentIndex/$TotalCount] [$groupKey] No files to transcode" -ForegroundColor Yellow
            return @{ Success = $true; Message = "No files to transcode" }
        }

        # Prepare prompt
        $prompt = Get-Content -Path $TRANSCODE_AGENT -Encoding UTF8 -Raw
        $filesString = $filesList -join ","
        $prompt = $prompt -replace [regex]::Escape("{FILES}"),     $filesString
        $prompt = $prompt -replace [regex]::Escape("{OUTPUT_DIR}"), $groupOutputDir
        $prompt = $prompt -replace [regex]::Escape("{LOG_FILE}"),   $logFile

        Write-Host "`n[$CurrentIndex/$TotalCount] [$groupKey] Step 1/3: Transcoding..."
        Write-Host "[$CurrentIndex/$TotalCount] [$groupKey] Files: $(($filesList | ForEach-Object { (Get-Item $_).Name }) -join ', ')"

        if ($TEST_MODE) {
            Write-Host "[$CurrentIndex/$TotalCount] [$groupKey] TEST MODE: Skipping transcode"
            return @{ Success = $true; Message = "Test mode - transcode skipped" }
        }

        # Run transcode
        $env:PYTHONIOENCODING = "utf-8"
        $job = Start-Job -ScriptBlock {
            param($prompt, $projectDir)
            Push-Location $projectDir
            try {
                & iflow --thinking -p $prompt 2>&1
            } finally {
                Pop-Location
            }
        } -ArgumentList $prompt, $PSScriptRoot

        $completed = $job | Wait-Job -Timeout $TIMEOUT_SEC

        if ($completed) {
            $output = Receive-Job -Job $job
            $success = ($job.State -eq 'Completed')
        } else {
            $output = @("Timeout after $TIMEOUT_SEC seconds")
            $success = $false
            Stop-Job -Job $job
        }

        Remove-Job -Job $job -Force

        if ($success) {
            Write-Host "[$CurrentIndex/$TotalCount] [$groupKey] Transcode completed" -ForegroundColor Green
        } else {
            Write-Host "[$CurrentIndex/$TotalCount] [$groupKey] Transcode failed" -ForegroundColor Red
        }

        return @{ Success = $success; Message = ($output -join "`n") }

    } catch {
        $errMsg = $_.Exception.Message
        Write-Host "[$CurrentIndex/$TotalCount] [$groupKey] Transcode exception: $errMsg" -ForegroundColor Red
        return @{ Success = $false; Message = $errMsg }
    }
}

# Function to run review for a single file group
function Run-ReviewForGroup {
    param (
        [hashtable]$FileGroup,
        [int]$CurrentIndex,
        [int]$TotalCount
    )

    $relativePath = $FileGroup.RelativePath
    $prefix = $FileGroup.Prefix
    $groupKey = "$relativePath\$prefix"

    $groupOutputDir = Join-Path $WPF_DIR $relativePath
    $reportFile = "$prefix.review.log.md"

    try {
        # Prepare file list
        $filesList = @()
        if ($FileGroup.WinformDesigner) { $filesList += $FileGroup.WinformDesigner }
        if ($FileGroup.WpfXaml) { $filesList += $FileGroup.WpfXaml }
        if ($FileGroup.WinformCs) { $filesList += $FileGroup.WinformCs }
        if ($FileGroup.WpfCs) { $filesList += $FileGroup.WpfCs }

        if ($filesList.Count -lt 4) {
            Write-Host "[$CurrentIndex/$TotalCount] [$groupKey] Missing files for review" -ForegroundColor Yellow
            return @{ Success = $false; Message = "Missing files for review" }
        }

        # Prepare prompt
        $prompt = Get-Content -Path $REVIEW_AGENT -Encoding UTF8 -Raw
        $filesString = $filesList -join ","
        $prompt = $prompt -replace [regex]::Escape("{FILES}"),      $filesString
        $prompt = $prompt -replace [regex]::Escape("{OUTPUT_DIR}"), $groupOutputDir
        $prompt = $prompt -replace [regex]::Escape("{REPORT_FILE}"), $reportFile

        Write-Host "[$CurrentIndex/$TotalCount] [$groupKey] Step 2/3: Reviewing..."

        if ($TEST_MODE) {
            Write-Host "[$CurrentIndex/$TotalCount] [$groupKey] TEST MODE: Skipping review"
            return @{ Success = $true; Message = "Test mode - review skipped" }
        }

        # Run review
        $env:PYTHONIOENCODING = "utf-8"
        $job = Start-Job -ScriptBlock {
            param($prompt, $projectDir)
            Push-Location $projectDir
            try {
                & iflow --thinking -p $prompt 2>&1
            } finally {
                Pop-Location
            }
        } -ArgumentList $prompt, $PSScriptRoot

        $completed = $job | Wait-Job -Timeout $TIMEOUT_SEC

        if ($completed) {
            $output = Receive-Job -Job $job
            $success = ($job.State -eq 'Completed')
        } else {
            $output = @("Timeout after $TIMEOUT_SEC seconds")
            $success = $false
            Stop-Job -Job $job
        }

        Remove-Job -Job $job -Force

        if ($success) {
            Write-Host "[$CurrentIndex/$TotalCount] [$groupKey] Review completed" -ForegroundColor Green
        } else {
            Write-Host "[$CurrentIndex/$TotalCount] [$groupKey] Review failed" -ForegroundColor Red
        }

        return @{ Success = $success; Message = ($output -join "`n") }

    } catch {
        $errMsg = $_.Exception.Message
        Write-Host "[$CurrentIndex/$TotalCount] [$groupKey] Review exception: $errMsg" -ForegroundColor Red
        return @{ Success = $false; Message = $errMsg }
    }
}

# Function to run fix for a single file group
function Run-FixForGroup {
    param (
        [hashtable]$FileGroup,
        [int]$CurrentIndex,
        [int]$TotalCount
    )

    $relativePath = $FileGroup.RelativePath
    $prefix = $FileGroup.Prefix
    $groupKey = "$relativePath\$prefix"

    $groupOutputDir = Join-Path $SUPER_DIR $relativePath
    $logFile = "$prefix.super.log.md"

    try {
        # Create output directory if it doesn't exist
        if (-not (Test-Path $groupOutputDir)) {
            New-Item -Path $groupOutputDir -ItemType Directory -Force | Out-Null
        }

        # Prepare file list
        $filesList = @()
        if ($FileGroup.WinformDesigner) { $filesList += $FileGroup.WinformDesigner }
        if ($FileGroup.WpfXaml) { $filesList += $FileGroup.WpfXaml }
        if ($FileGroup.WinformCs) { $filesList += $FileGroup.WinformCs }
        if ($FileGroup.WpfCs) { $filesList += $FileGroup.WpfCs }
        if ($FileGroup.TransLog) { $filesList += $FileGroup.TransLog }
        if ($FileGroup.ReviewLog) { $filesList += $FileGroup.ReviewLog }

        if ($filesList.Count -lt 6) {
            Write-Host "[$CurrentIndex/$TotalCount] [$groupKey] Missing files for fix" -ForegroundColor Yellow
            return @{ Success = $false; Message = "Missing files for fix" }
        }

        # Prepare prompt
        $prompt = Get-Content -Path $FIX_AGENT -Encoding UTF8 -Raw
        $filesString = $filesList -join ","
        $prompt = $prompt -replace [regex]::Escape("{FILES}"),     $filesString
        $prompt = $prompt -replace [regex]::Escape("{OUTPUT_DIR}"), $groupOutputDir
        $prompt = $prompt -replace [regex]::Escape("{LOG_FILE}"),   $logFile

        Write-Host "[$CurrentIndex/$TotalCount] [$groupKey] Step 3/3: Fixing..."

        if ($TEST_MODE) {
            Write-Host "[$CurrentIndex/$TotalCount] [$groupKey] TEST MODE: Skipping fix"
            return @{ Success = $true; Message = "Test mode - fix skipped" }
        }

        # Run fix
        $env:PYTHONIOENCODING = "utf-8"
        $job = Start-Job -ScriptBlock {
            param($prompt, $projectDir)
            Push-Location $projectDir
            try {
                & iflow --thinking -p $prompt 2>&1
            } finally {
                Pop-Location
            }
        } -ArgumentList $prompt, $PSScriptRoot

        $completed = $job | Wait-Job -Timeout $TIMEOUT_SEC

        if ($completed) {
            $output = Receive-Job -Job $job
            $success = ($job.State -eq 'Completed')
        } else {
            $output = @("Timeout after $TIMEOUT_SEC seconds")
            $success = $false
            Stop-Job -Job $job
        }

        Remove-Job -Job $job -Force

        if ($success) {
            Write-Host "[$CurrentIndex/$TotalCount] [$groupKey] Fix completed" -ForegroundColor Green
        } else {
            Write-Host "[$CurrentIndex/$TotalCount] [$groupKey] Fix failed" -ForegroundColor Red
        }

        return @{ Success = $success; Message = ($output -join "`n") }

    } catch {
        $errMsg = $_.Exception.Message
        Write-Host "[$CurrentIndex/$TotalCount] [$groupKey] Fix exception: $errMsg" -ForegroundColor Red
        return @{ Success = $false; Message = $errMsg }
    }
}

# Main logic
Write-Host ("=" * 60)
Write-Host "WinForms to WPF Super Conversion Script"
Write-Host "Execution mode: Per-file-group (transcode -> review -> fix)"
Write-Host ("=" * 60)

if ($TEST_MODE) {
    Write-Host "TEST MODE: Running in test mode, skipping actual conversion"
}

# Validate input directory
if (-not (Test-Path $INPUT_DIR)) {
    Write-Host "Error: Input directory $INPUT_DIR does not exist" -ForegroundColor Red
    exit 1
}

# Create output directories
New-Item -Path $WPF_DIR -ItemType Directory -Force | Out-Null
New-Item -Path $SUPER_DIR -ItemType Directory -Force | Out-Null

# Group WinForms files
Write-Host "`nAnalyzing WinForms files..."
$winformGroups = Group-WinformFiles -InputDir $INPUT_DIR

if ($winformGroups.Count -eq 0) {
    Write-Host "Warning: No WinForms files found to process" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($winformGroups.Count) file groups to process"
Write-Host ""

# Process each file group
$results = @()
$currentIndex = 0

foreach ($groupKey in $winformGroups.Keys | Sort-Object) {
    $fileGroup = $winformGroups[$groupKey]
    $currentIndex++

    Write-Host ("-" * 60)
    Write-Host "Processing file group [$currentIndex/$($winformGroups.Count)]: $groupKey"
    Write-Host ("-" * 60)

    # Step 1: Transcode
    $transcodeResult = Run-TranscodeForGroup -FileGroup $fileGroup -CurrentIndex $currentIndex -TotalCount $winformGroups.Count

    if (-not $transcodeResult.Success) {
        Write-Host "[$currentIndex/$($winformGroups.Count)] [$groupKey] Transcode failed, skipping review and fix" -ForegroundColor Red
        $results += @{
            GroupKey = $groupKey
            TranscodeSuccess = $false
            ReviewSuccess = $false
            FixSuccess = $false
            Error = "Transcode failed: $($transcodeResult.Message)"
        }
        continue
    }

    # Update file group with WPF files
    $relativePath = $fileGroup.RelativePath
    $prefix = $fileGroup.Prefix
    $wpfXaml = Join-Path $WPF_DIR "$relativePath\$prefix.xaml"
    $wpfCs = Join-Path $WPF_DIR "$relativePath\$prefix.xaml.cs"
    $transLog = Join-Path $WPF_DIR "$relativePath\$prefix.trans.log.md"

    if (Test-Path $wpfXaml) { $fileGroup.WpfXaml = $wpfXaml }
    if (Test-Path $wpfCs) { $fileGroup.WpfCs = $wpfCs }
    if (Test-Path $transLog) { $fileGroup.TransLog = $transLog }

    # Step 2: Review
    $reviewResult = Run-ReviewForGroup -FileGroup $fileGroup -CurrentIndex $currentIndex -TotalCount $winformGroups.Count

    if (-not $reviewResult.Success) {
        Write-Host "[$currentIndex/$($winformGroups.Count)] [$groupKey] Review failed, skipping fix" -ForegroundColor Red
        $results += @{
            GroupKey = $groupKey
            TranscodeSuccess = $true
            ReviewSuccess = $false
            FixSuccess = $false
            Error = "Review failed: $($reviewResult.Message)"
        }
        continue
    }

    # Update file group with review log
    $reviewLog = Join-Path $WPF_DIR "$relativePath\$prefix.review.log.md"
    if (Test-Path $reviewLog) { $fileGroup.ReviewLog = $reviewLog }

    # Step 3: Fix
    $fixResult = Run-FixForGroup -FileGroup $fileGroup -CurrentIndex $currentIndex -TotalCount $winformGroups.Count

    if ($fixResult.Success) {
        Write-Host "[$currentIndex/$($winformGroups.Count)] [$groupKey] All steps completed successfully" -ForegroundColor Green
    } else {
        Write-Host "[$currentIndex/$($winformGroups.Count)] [$groupKey] Fix failed" -ForegroundColor Red
    }

    $results += @{
        GroupKey = $groupKey
        TranscodeSuccess = $transcodeResult.Success
        ReviewSuccess = $reviewResult.Success
        FixSuccess = $fixResult.Success
        Error = if (-not $fixResult.Success) { $fixResult.Message } else { $null }
    }
}

# Summary
Write-Host "`n" + ("=" * 60)
Write-Host "Super Conversion Summary"
Write-Host ("=" * 60)

$fullSuccess = ($results | Where-Object { $_.TranscodeSuccess -and $_.ReviewSuccess -and $_.FixSuccess }).Count
$partialSuccess = ($results | Where-Object { -not ($_.TranscodeSuccess -and $_.ReviewSuccess -and $_.FixSuccess) -and $_.TranscodeSuccess }).Count
$failed = ($results | Where-Object { -not $_.TranscodeSuccess }).Count

Write-Host "Total file groups: $($results.Count)"
Write-Host "Fully successful: $fullSuccess"
Write-Host "Partially successful: $partialSuccess"
Write-Host "Failed: $failed"

if ($failed -gt 0) {
    Write-Host "`nFailed file groups:"
    $results | Where-Object { -not $_.TranscodeSuccess } | ForEach-Object {
        Write-Host "  - $($_.GroupKey): $($_.Error)" -ForegroundColor Red
    }
}

if ($partialSuccess -gt 0) {
    Write-Host "`nPartially successful file groups:"
    $results | Where-Object { -not ($_.TranscodeSuccess -and $_.ReviewSuccess -and $_.FixSuccess) -and $_.TranscodeSuccess } | ForEach-Object {
        $status = @()
        if (-not $_.ReviewSuccess) { $status += "Review failed" }
        if (-not $_.FixSuccess) { $status += "Fix failed" }
        Write-Host "  - $($_.GroupKey): $($status -join ', ')" -ForegroundColor Yellow
    }
}

Write-Host "`nOutput locations:"
Write-Host "  WPF files: $WPF_DIR"
Write-Host "  Fixed files: $SUPER_DIR"

Write-Host ("=" * 60)

exit $(if ($failed -gt 0) {1} else {0})