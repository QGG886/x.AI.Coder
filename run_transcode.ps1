# WinForms to WPF Code Conversion Script
# Supports complex folder structure, grouping files within each folder

# Set console encoding to UTF-8
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# Configuration
$INPUT_DIR   = Join-Path $PSScriptRoot "winform"
$OUTPUT_DIR  = Join-Path $PSScriptRoot "wpf"
$AGENT_FILE  = Join-Path $PSScriptRoot "prompt/agents/transcode/transcode_single.agent.md"
$MAX_WORKERS = 1
$TIMEOUT_SEC = 21600  # 6 hours timeout
$TEST_MODE   = $false  # Set to $true to skip actual iflow execution

function Group-FilesByPrefix {
    param (
        [string]$InputDir
    )

    $groups = @{}

    $allCsFiles = Get-ChildItem -Path $InputDir -Filter "*.cs" -File

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
        if (-not $groups.ContainsKey($prefix)) {
            $groups[$prefix] = @()
        }
        $groups[$prefix] += $file.FullName
    }

    foreach ($file in $csFiles) {
        $prefix = $file.BaseName
        if (-not $groups.ContainsKey($prefix)) {
            $groups[$prefix] = @()
        }
        $groups[$prefix] += $file.FullName
    }

    return $groups
}

function Prepare-Prompt {
    param (
        [string]$AgentFile,
        [string[]]$Files,
        [string]$OutputDir,
        [string]$LogFile
    )

    $prompt = Get-Content -Path $AgentFile -Encoding UTF8 -Raw

    $filesList = @()
    foreach ($file in $Files) {
        $fullPath = (Get-Item $file).FullName
        $filesList += $fullPath
    }
    $filesString = $filesList -join ","

    $prompt = $prompt -replace [regex]::Escape("{FILES}"),     $filesString
    $prompt = $prompt -replace [regex]::Escape("{OUTPUT_DIR}"), $OutputDir
    $prompt = $prompt -replace [regex]::Escape("{LOG_FILE}"),   $LogFile

    return $prompt
}

function Process-FileGroup {
    param (
        [string]$Prefix,
        [string[]]$Files,
        [string]$AgentFile,
        [string]$OutputDirBase,
        [string]$RelativePath,
        [int]$CurrentIndex,
        [int]$TotalCount
    )

    $groupOutputDir = Join-Path $OutputDirBase $RelativePath
    $logFile        = "$Prefix.trans.log.md"

    try {
        # Create output directory if it doesn't exist
        if (-not (Test-Path $groupOutputDir)) {
            New-Item -Path $groupOutputDir -ItemType Directory -Force | Out-Null
        }

        $prompt = Prepare-Prompt -AgentFile $AGENT_FILE -Files $Files -OutputDir $groupOutputDir -LogFile $logFile

        Write-Host "[$CurrentIndex/$TotalCount] [$RelativePath/$Prefix] Processing $($Files.Count) files..."
        Write-Host "[$CurrentIndex/$TotalCount] [$RelativePath/$Prefix] Files: $(($Files | ForEach-Object { (Get-Item $_).Name }) -join ', ')"

        if ($TEST_MODE) {
            Write-Host "[$CurrentIndex/$TotalCount] [$RelativePath/$Prefix] TEST MODE: Skipping iflow execution"
            $success = $true
            $stdout = "Test mode - files would be processed here"
        } else {
            $env:PYTHONIOENCODING = "utf-8"

            # Run iflow with timeout in project directory
            $job = Start-Job -ScriptBlock {
                param($prompt, $projectDir)
                Push-Location $projectDir
                try {
                    & iflow --thinking -p $prompt 2>&1
                } finally {
                    Pop-Location
                }
            } -ArgumentList $prompt, $PSScriptRoot

            # Wait for job to complete or timeout
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
                Write-Host "[$CurrentIndex/$TotalCount] [$RelativePath/$Prefix] Done"
            } else {
                Write-Host "[$CurrentIndex/$TotalCount] [$RelativePath/$Prefix] Failed (exit code: $exitCode)"
            }
        }

        return @{ GroupName = "$RelativePath/$Prefix"; Success = $success; Output = $stdout; RelativePath = $RelativePath; Prefix = $Prefix }

    } catch {
        $errMsg = $_.Exception.Message
        Write-Host "[$CurrentIndex/$TotalCount] [$RelativePath/$Prefix] Exception: $errMsg"

        return @{ GroupName = "$RelativePath/$Prefix"; Success = $false; Output = $errMsg; RelativePath = $RelativePath; Prefix = $Prefix }
    }
}

# Main logic
Write-Host ("=" * 60)
Write-Host "WinForms to WPF Code Conversion Script (Supports Folder Structure)"
Write-Host ("=" * 60)

if ($TEST_MODE) {
    Write-Host "TEST MODE: Running in test mode, skipping actual conversion"
}

if (-not (Test-Path $INPUT_DIR)) {
    Write-Host "Error: Input directory $INPUT_DIR does not exist"
    exit 1
}

if (-not (Test-Path $AGENT_FILE)) {
    Write-Host "Error: Agent file $AGENT_FILE does not exist"
    exit 1
}

New-Item -Path $OUTPUT_DIR -ItemType Directory -Force | Out-Null

$allCsFiles = Get-ChildItem -Path $INPUT_DIR -Filter "*.cs" -File -Recurse
$directoriesWithCs = @($allCsFiles | ForEach-Object { $_.DirectoryName } | Select-Object -Unique)

if ($directoriesWithCs.Count -eq 0) {
    Write-Host "Warning: No files to process"
    exit 0
}

$results = @()
$global:currentIndex = 0

# Calculate total file groups count
$totalFileGroups = 0
foreach ($dir in $directoriesWithCs) {
    $groups = Group-FilesByPrefix -InputDir $dir
    $totalFileGroups += $groups.Count
}

Write-Host "Found $totalFileGroups file groups to process"

foreach ($dir in $directoriesWithCs) {
    if ($dir -eq $INPUT_DIR) {
        $relativePath = ""
    } else {
        $relativePath = $dir.Substring($INPUT_DIR.Length + 1)
    }
    Write-Host "`nProcessing directory: $relativePath"

    $groups = Group-FilesByPrefix -InputDir $dir

    if ($groups.Count -eq 0) {
        Write-Host "  Warning: No files to process in this directory"
        continue
    }

    Write-Host "  Found $($groups.Count) file groups:"
    foreach ($prefix in $groups.Keys | Sort-Object) {
        $fileNames = ($groups[$prefix] | ForEach-Object { (Get-Item $_).Name }) -join ', '
        Write-Host "    - ${prefix}: $fileNames"
    }

    foreach ($prefix in $groups.Keys | Sort-Object) {
        $files = $groups[$prefix]
        $global:currentIndex++
        try {
            $result = Process-FileGroup -Prefix $prefix `
                                       -Files $files `
                                       -AgentFile $AGENT_FILE `
                                       -OutputDirBase $OUTPUT_DIR `
                                       -RelativePath $relativePath `
                                       -CurrentIndex $global:currentIndex `
                                       -TotalCount $totalFileGroups
            if ($result) {
                $results += ,@($result)
            }
        } catch {
            Write-Host "[$global:currentIndex/$totalFileGroups] [$relativePath/$prefix] Exception: $_"
        }
    }
}

# Summary
Write-Host "`n" + ("-" * 60)
Write-Host "`nProcessing Summary:"
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

Write-Host "`nLog file locations:"
$results | ForEach-Object {
    $log = Join-Path -Path $OUTPUT_DIR -ChildPath "$($_.RelativePath)\$($_.Prefix).trans.log.md"
    Write-Host "  - $log"
}

Write-Host "`nOutput file locations:"
$uniqueDirs = @($results | ForEach-Object { $_.RelativePath } | Select-Object -Unique)
foreach ($dir in $uniqueDirs) {
    $fullDir = Join-Path $OUTPUT_DIR $dir
    Write-Host "  - $fullDir"
}

Write-Host ("=" * 60)

exit $(if ($failCount -eq 0) {0} else {1})