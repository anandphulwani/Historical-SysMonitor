# PowerShell script to generate resource information files within date and time organized folders

param (
    [string]$baseDir,
    [int]$usageThreshold
)

# Launch typeperf command as a background job
$typeperfJob = Start-Job -ScriptBlock {
    typeperf "\Processor(_total)\% Processor Time" "\Memory\Available Bytes" "\LogicalDisk(C:)\% Disk Time" -sc 5
}

# Create directories based on current date and time
$dateDir = Get-Date -Format "yyyy-MM-dd"
$timeDir = Get-Date -Format "HHmmss"
$targetDir = Join-Path -Path $baseDir -ChildPath $dateDir
$targetDir = Join-Path -Path $targetDir -ChildPath $timeDir

# Fetch all disk activity data at once
$allDiskActivity = Get-WmiObject Win32_PerfRawData_PerfProc_Process -Property IDProcess, IOReadBytesPersec, IOWriteBytesPersec

# Get process information
$processInfo = Get-Process | Where-Object { $_.CPU -ne $null } | ForEach-Object {
    $currentProcessId = $_.Id  # Capture the process ID to avoid $_ confusion
    $diskActivity = $allDiskActivity | Where-Object { $_.IDProcess -eq $currentProcessId }

    [PSCustomObject]@{
        Name = $_.ProcessName
        ID = $currentProcessId
        "Memory (MB)" = [math]::Round($_.WS / 1MB, 2)
        "CPU (s)" = [math]::Round($_.CPU, 2)
        "Disk Read Bytes" = $diskActivity.IOReadBytesPersec
        "Disk Write Bytes" = $diskActivity.IOWriteBytesPersec
    }
}

# System Resource Summary
# (The summary generation code goes here, similar to the previous example)
# Ensure to use Out-File with Join-Path to save the SystemResourceSummary.txt in the target directory

# Adjusted System Resource Summary
$cpuUsageSamples = Get-Counter '\Processor(_Total)\% Processor Time' -MaxSamples 2
$cpuUsage = ($cpuUsageSamples.CounterSamples.CookedValue | Measure-Object -Average).Average
$cpuUsageRounded = [math]::Round($cpuUsage, 2)

$memUsage = Get-Counter '\Memory\Available MBytes' | Select-Object -ExpandProperty CounterSamples | Select-Object -ExpandProperty CookedValue
$totalMem = Get-WmiObject Win32_ComputerSystem | Select-Object -ExpandProperty TotalPhysicalMemory
$usedMem = $totalMem - ($memUsage * 1MB)

$diskTransfersPerSec = Get-Counter '\PhysicalDisk(_Total)\Disk Transfers/sec' -MaxSamples 2
$diskTransfers = ($diskTransfersPerSec.CounterSamples.CookedValue | Measure-Object -Average).Average
$diskTransfersRounded = [math]::Round($diskTransfers, 2)

Wait-Job $typeperfJob
$typeperfResults = Receive-Job $typeperfJob
Remove-Job $typeperfJob

$lines = $typeperfResults -split "`n"
$lines = $lines[2..($lines.Length - 3)]

$columnValues = @(@(),@(),@())
foreach ($line in $lines) {
    $elements = $line -split "," | Select-Object -Skip 1 | ForEach-Object { $_.Trim('"') }
    for ($i = 0; $i -lt $columnValues.Length; $i++) {
        if ($i -eq 1) {
            $value = [math]::Round([double]$elements[$i] / (1024 * 1024 * 1024), 2)
            $columnValues[$i] += $value
        } else {
            $columnValues[$i] += [math]::Round([double]$elements[$i], 2)
        }
    }
}

# Calculate lowest, average, and highest for each column and round them
$results = 0..($columnValues.Length - 1) | ForEach-Object {
    $index = $_
    $column = $columnValues[$_]

    # Determine rounding precision based on column index
    $roundingPrecision = 2

    $lowest = [Math]::Round(($column | Measure-Object -Minimum).Minimum, $roundingPrecision)
    $average = [Math]::Round(($column | Measure-Object -Average).Average, $roundingPrecision)
    $highest = [Math]::Round(($column | Measure-Object -Maximum).Maximum, $roundingPrecision)
    
    # Ensure values for 1st and 3rd elements do not exceed 100
    if ($index -eq 0 -or $index -eq 2) {
        $lowest = [Math]::Min($lowest, 100)
        $average = [Math]::Min($average, 100)
        $highest = [Math]::Min($highest, 100)
    }

    # Return a custom object with the results for readability
    [PSCustomObject]@{
        Column = $index + 1
        Lowest = $lowest
        Average = $average
        Highest = $highest
    }
}

$totalMemoryFormatted = $([math]::Round($totalMem / 1GB, 2))
$summaryLines = @()
$labels = @("CPU Usage", "Free Memory Available", "Disk Usage")

# Iterate through each result and format the output
for ($i = 0; $i -lt $results.Count; $i++) {
    $result = $results[$i]
    $label = $labels[$i]
    if ($result.Lowest -eq $result.Average -and $result.Average -eq $result.Highest) {
        # Special formatting for identical values
        $line = if ($i -eq 1) { "${label}: $($result.Lowest) GB/ $totalMemoryFormatted GB" } else { "${label}: $($result.Lowest)%" }
    } else {
        # Default formatting
        $suffix = if ($i -eq 1) { " GB/ $totalMemoryFormatted GB" } else { "%" }
        $line = "${label}: Lowest: $($result.Lowest)$suffix, Average: $($result.Average)$suffix, Highest: $($result.Highest)$suffix"
    }
    $summaryLines += $line
}

# Assuming $results is already populated and structured as expected
$cpuUsageAverage = $results[0].Average
$diskUsageAverage = $results[2].Average

# Calculate Memory Used Percentage from Free Memory Available
# Assuming total memory is in GB and free memory is reported in the results in GB
$freeMemoryGB = $results[1].Average
$memoryUsedPercentage = [math]::Round((($totalMemoryFormatted - $freeMemoryGB) / $totalMemoryFormatted) * 100, 2)
Write-Output "Metrics: CPU: $cpuUsageAverage, DISK: $diskUsageAverage, MEMORY: $memoryUsedPercentage"

# Check if any metric's average exceeds the usageThreshold
$exceedsThreshold = $cpuUsageAverage -ge $usageThreshold -or
                    $diskUsageAverage -ge $usageThreshold -or
                    $memoryUsedPercentage -ge $usageThreshold


if ($exceedsThreshold) {
    New-Item -ItemType Directory -Force -Path $targetDir

    # Sort and export process information to files within the target directory
    $processInfo | Sort-Object "Memory (MB)" -Descending | Format-Table -AutoSize | Out-String -Width 4096 | Out-File -FilePath (Join-Path $targetDir "MemoryUsage.txt")
    $processInfo | Sort-Object "CPU (s)" -Descending | Format-Table -AutoSize | Out-String -Width 4096 | Out-File -FilePath (Join-Path $targetDir "CPUUsage.txt")
    $processInfo | Sort-Object "Disk Read Bytes" -Descending | Format-Table -AutoSize | Out-String -Width 4096 | Out-File -FilePath (Join-Path $targetDir "DiskReadUsage.txt")
    $processInfo | Sort-Object "Disk Write Bytes" -Descending | Format-Table -AutoSize | Out-String -Width 4096 | Out-File -FilePath (Join-Path $targetDir "DiskWriteUsage.txt")

    $summaryContent = "System Resource Summary:`n" +
    "CPU Usage: $($cpuUsageRounded)%`n" +
    "Memory Usage: $([math]::Round($usedMem / 1GB, 2)) GB / $([math]::Round($totalMem / 1GB, 2)) GB  ($memoryUsedPercentage%)`n" +
    "Disk Transfers/sec: $($diskTransfersRounded)`n"

    $summaryContent += "`n`n`nTypeperf Results:`n" + ($summaryLines -join "`n")
    $summaryContent | Out-File -FilePath (Join-Path $targetDir "SystemResourceSummary.txt")
} else {
    Write-Output "No metrics exceed the usage threshold of $usageThreshold%."
}
