# PowerShell script to generate resource information files within date and time organized folders

# Define base directory path (you can adjust this path as needed)
$baseDir = "C:\ResourceReports"

# Create directories based on current date and time
$dateDir = Get-Date -Format "yyyy-MM-dd"
$timeDir = Get-Date -Format "HHmmss"
$targetDir = Join-Path -Path $baseDir -ChildPath $dateDir
$targetDir = Join-Path -Path $targetDir -ChildPath $timeDir
New-Item -ItemType Directory -Force -Path $targetDir

# Function to get disk activity
function Get-DiskActivity {
    param (
        [Parameter(Mandatory=$true)]
        [int]$processId
    )

    $diskActivity = Get-WmiObject Win32_PerfRawData_PerfProc_Process | Where-Object { $_.IDProcess -eq $processId }
    return @{
        ReadBytes = $diskActivity.IOReadBytesPersec;
        WriteBytes = $diskActivity.IOWriteBytesPersec
    }
}

# Get process information
$processInfo = Get-Process | Where-Object { $_.CPU -ne $null } | ForEach-Object {
    $diskActivity = Get-DiskActivity -processId $_.Id
    [PSCustomObject]@{
        Name = $_.ProcessName  # Use ProcessName or Name
        ID = $_.Id
        "Memory (MB)" = [math]::Round($_.WS / 1MB, 2)
        "CPU (s)" = [math]::Round($_.CPU, 2)
        "Disk Read Bytes" = $diskActivity.ReadBytes
        "Disk Write Bytes" = $diskActivity.WriteBytes
    }
}

# Sort and export process information to files within the target directory
$processInfo | Sort-Object "Memory (MB)" -Descending | Format-Table -AutoSize | Out-String -Width 4096 | Out-File -FilePath (Join-Path $targetDir "MemoryUsage.txt")
$processInfo | Sort-Object "CPU (s)" -Descending | Format-Table -AutoSize | Out-String -Width 4096 | Out-File -FilePath (Join-Path $targetDir "CPUUsage.txt")
$processInfo | Sort-Object "Disk Read Bytes" -Descending | Format-Table -AutoSize | Out-String -Width 4096 | Out-File -FilePath (Join-Path $targetDir "DiskReadUsage.txt")
$processInfo | Sort-Object "Disk Write Bytes" -Descending | Format-Table -AutoSize | Out-String -Width 4096 | Out-File -FilePath (Join-Path $targetDir "DiskWriteUsage.txt")


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


$summaryContent = @"
System Resource Summary:
CPU Usage: $($cpuUsageRounded)%
Memory Usage: $([math]::Round($usedMem / 1GB, 2)) GB / $([math]::Round($totalMem / 1GB, 2)) GB
Disk Transfers/sec: $($diskTransfersRounded)
"@

$summaryContent | Out-File -FilePath (Join-Path $targetDir "SystemResourceSummary.txt")

# Note: Automatic opening of files in Notepad is omitted due to the files being potentially located in a deeply nested directory structure
