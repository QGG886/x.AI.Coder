# WinForms → WPF Code Review Script
# Reviews converted WPF code against original WinForms code based on rules

# Set console encoding to UTF-8
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# Configuration
$WINFORM_DIR = Join-Path $PSScriptRoot "winform"
$WPF_DIR     = Join-Path $PSScriptRoot "wpf"
$AGENT_FILE  = Join-Path $PSScriptRoot "prompt/agents/review/review_single.agent.md"
$MAX_WORKERS = 1
$TIMEOUT_SEC = 21600  # 6 hours timeout
$TEST_MODE   = $false  # Set to $true to skip actual iflow execution

function Group-FilesByPrefix {
    param (
        [string]$WinformDir,
        [string]$WpfDir
    )

    $groups = @{}

    $allWinformFiles = Get-ChildItem -Path $WinformDir -Filter "*.cs" -File -Recurse

    $csFiles       = @()
    $designerFiles = @()

    foreach ($file in $allWinformFiles) {
        if ($file.Name -imatch '\.designer\.cs$') {
            $designerFiles += $file
        } else {
            $csFiles += $file
        }
    }

    foreach ($file in $designerFiles) {
        $prefix = $file.Name -ireplace '\.designer\.cs$', ''
        
        # Calculate relative path
        if ($file.Directory.FullName -eq $WinformDir) {
            $relativePath = ""
        } else {
            $relativePath = $file.Directory.FullName.Substring($WinformDir.Length + 1)
        }

        # Check if corresponding WPF files exist
        $xamlFile = Join-Path $WpfDir "$relativePath\$prefix.xaml"

        if (Test-Path $xamlFile) {
            if (-not $groups.ContainsKey("$relativePath\$prefix")) {
                $groups["$relativePath\$prefix"] = @{
                    WinformDesigner = $file.FullName
                    WpfXaml = $xamlFile
                    WinformCs = $null
                    WpfCs = $null
                }
            }
            $groups["$relativePath\$prefix"].WinformDesigner = $file.FullName
            $groups["$relativePath\$prefix"].WpfXaml = $xamlFile
        }
    }

    foreach ($file in $csFiles) {
        $prefix = $file.BaseName
        
        # Calculate relative path
        if ($file.Directory.FullName -eq $WinformDir) {
            $relativePath = ""
        } else {
            $relativePath = $file.Directory.FullName.Substring($WinformDir.Length + 1)
        }

        # Check if corresponding WPF files exist
        $wpfCsFile = Join-Path $WpfDir "$relativePath\$prefix.xaml.cs"

        if (Test-Path $wpfCsFile) {
            if (-not $groups.ContainsKey("$relativePath\$prefix")) {
                $groups["$relativePath\$prefix"] = @{
                    WinformDesigner = $null
                    WpfXaml = $null
                    WinformCs = $null
                    WpfCs = $null
                }
            }
            $groups["$relativePath\$prefix"].WinformCs = $file.FullName
            $groups["$relativePath\$prefix"].WpfCs = $wpfCsFile
        }
    }

    return $groups
}

function Prepare-Prompt {
    param (
        [string]$AgentFile,
        [hashtable]$FileGroup,
        [string]$WpfDir
    )

    $prompt = Get-Content -Path $AgentFile -Encoding UTF8 -Raw

    $filesList = @()
    if ($FileGroup.WinformDesigner) { $filesList += $FileGroup.WinformDesigner }
    if ($FileGroup.WpfXaml) { $filesList += $FileGroup.WpfXaml }
    if ($FileGroup.WinformCs) { $filesList += $FileGroup.WinformCs }
    if ($FileGroup.WpfCs) { $filesList += $FileGroup.WpfCs }

    $filesString = $filesList -join ","

    $relativePath = Split-Path $FileGroup.WpfXaml -Parent
    if (-not $relativePath) { $relativePath = "" }
    $outputDir = Join-Path $WpfDir $relativePath

    $prefix = [System.IO.Path]::GetFileNameWithoutExtension($FileGroup.WpfXaml)
    $reportFile = "$prefix.review.log.md"

    $prompt = $prompt -replace [regex]::Escape("{FILES}"),      $filesString
    $prompt = $prompt -replace [regex]::Escape("{OUTPUT_DIR}"), $outputDir
    $prompt = $prompt -replace [regex]::Escape("{REPORT_FILE}"), $reportFile

    return $prompt
}

function Process-FileGroup {
    param (
        [string]$GroupKey,
        [hashtable]$FileGroup,
        [string]$AgentFile,
        [string]$WpfDir,
        [int]$CurrentIndex,
        [int]$TotalCount
    )

    try {
        $prompt = Prepare-Prompt -AgentFile $AGENT_FILE -FileGroup $FileGroup -WpfDir $WpfDir

        $fileNames = @()
        if ($FileGroup.WinformDesigner) { $fileNames += (Get-Item $FileGroup.WinformDesigner).Name }
        if ($FileGroup.WpfXaml) { $fileNames += (Get-Item $FileGroup.WpfXaml).Name }
        if ($FileGroup.WinformCs) { $fileNames += (Get-Item $FileGroup.WinformCs).Name }
        if ($FileGroup.WpfCs) { $fileNames += (Get-Item $FileGroup.WpfCs).Name }

        Write-Host "[$CurrentIndex/$TotalCount] [$GroupKey] Reviewing $($fileNames.Count) files..."
        Write-Host "[$CurrentIndex/$TotalCount] [$GroupKey] Files: $($fileNames -join ', ')"

        if ($TEST_MODE) {
            Write-Host "[$CurrentIndex/$TotalCount] [$GroupKey] TEST MODE: Skipping iflow execution"
            $success = $true
            $stdout = "Test mode - files would be reviewed here"
        } else {
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
                if ($job.State -eq 'Completed') {
                    $exitCode = 0
                } else {
                    $exitCode = 1
                }
            } else {
                $output = @("Timeout after $TIMEOUT_SEC seconds")
                $exitCode = 1
                Stop-Job -Job $job
            }

            Remove-Job -Job $job -Force

            $stdout = $output -join "`n"

            $success = $exitCode -eq 0

            if ($success) {
                Write-Host "[$CurrentIndex/$TotalCount] [$GroupKey] Done"
            } else {
                Write-Host "[$CurrentIndex/$TotalCount] [$GroupKey] Failed (exit code: $exitCode)"
            }
        }

        return @{ GroupName = $GroupKey; Success = $success; Output = $stdout }

    } catch {
        $errMsg = $_.Exception.Message
        Write-Host "[$CurrentIndex/$TotalCount] [$GroupKey] Exception: $errMsg"

        return @{ GroupName = $GroupKey; Success = $false; Output = $errMsg }
    }
}

# Main logic
Write-Host ("=" * 60)
Write-Host "WinForms to WPF Code Review Script"
Write-Host ("=" * 60)

if ($TEST_MODE) {
    Write-Host "TEST MODE: Running in test mode, skipping actual review"
}

if (-not (Test-Path $WINFORM_DIR)) {
    Write-Host "Error: Winform directory $WINFORM_DIR does not exist"
    exit 1
}

if (-not (Test-Path $WPF_DIR)) {
    Write-Host "Error: WPF directory $WPF_DIR does not exist"
    exit 1
}

if (-not (Test-Path $AGENT_FILE)) {
    Write-Host "Error: Agent file $AGENT_FILE does not exist"
    exit 1
}

$groups = Group-FilesByPrefix -WinformDir $WINFORM_DIR -WpfDir $WPF_DIR

if ($groups.Count -eq 0) {
    Write-Host "Warning: No file groups to review"
    exit 0
}

Write-Host "Found $($groups.Count) file groups to review"
Write-Host ""

$results = @()
$currentIndex = 0

foreach ($groupKey in $groups.Keys | Sort-Object) {
    $fileGroup = $groups[$groupKey]
    $currentIndex++
    try {
        $result = Process-FileGroup -GroupKey $groupKey `
                                   -FileGroup $fileGroup `
                                   -AgentFile $AGENT_FILE `
                                   -WpfDir $WPF_DIR `
                                   -CurrentIndex $currentIndex `
                                   -TotalCount $groups.Count
        if ($result) {
            $results += ,@($result)
        }
    } catch {
        Write-Host "[$currentIndex/$($groups.Count)] [$groupKey] Exception: $_"
    }
}

# Summary
Write-Host "`n" + ("-" * 60)
Write-Host "`nReview Summary:"
Write-Host ("=" * 60)

$successCount = ($results | Where-Object { $_.Success }).Count
$failCount    = $results.Count - $successCount

Write-Host "Total: $($results.Count) file groups"
Write-Host "Success: $successCount"
Write-Host "Failed: $failCount"

if ($failCount -gt 0) {
    Write-Host "`nFailed file groups:"
    $results | Where-Object { -not $_.Success } | ForEach-Object {
        Write-Host "  - $($_.GroupName)"
    }
}

Write-Host "`nReview report locations:"
$results | ForEach-Object {
    $groupKey = $_.GroupName
    $prefix = Split-Path $groupKey -Leaf
    $relativePath = Split-Path $groupKey
    if ($relativePath) {
        $report = Join-Path -Path $WPF_DIR -ChildPath "$relativePath\$prefix.review.log.md"
    } else {
        $report = Join-Path -Path $WPF_DIR -ChildPath "$prefix.review.log.md"
    }
    Write-Host "  - $report"
}

Write-Host ("=" * 60)

exit $(if ($failCount -eq 0) {0} else {1})