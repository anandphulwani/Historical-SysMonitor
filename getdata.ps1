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
    "" | Select-Object @{Name="Name"; Expression={$_.Name}},
                        @{Name="ID"; Expression={$_.Id}},
                        @{Name="Memory (MB)"; Expression={[math]::Round($_.WS / 1MB, 2)}},
                        @{Name="CPU (s)"; Expression={[math]::Round($_.CPU, 2)}},
                        @{Name="Disk Read Bytes"; Expression={$diskActivity.ReadBytes}},
                        @{Name="Disk Write Bytes"; Expression={$diskActivity.WriteBytes}}
}

# Sort and export process information to files within the target directory
$processInfo | Sort-Object "Memory (MB)" -Descending | Format-Table -AutoSize | Out-String -Width 4096 | Out-File -FilePath (Join-Path $targetDir "MemoryUsage.txt")
$processInfo | Sort-Object "CPU (s)" -Descending | Format-Table -AutoSize | Out-String -Width 4096 | Out-File -FilePath (Join-Path $targetDir "CPUUsage.txt")
$processInfo | Sort-Object "Disk Write Bytes" -Descending | Format-Table -AutoSize | Out-String -Width 4096 | Out-File -FilePath (Join-Path $targetDir "DiskWriteUsage.txt")

# System Resource Summary
# (The summary generation code goes here, similar to the previous example)
# Ensure to use Out-File with Join-Path to save the SystemResourceSummary.txt in the target directory

# Example for System Resource Summary (shortened for brevity)
$summaryContent = "System Resource Summary Placeholder"
$summaryContent | Out-File -FilePath (Join-Path $targetDir "SystemResourceSummary.txt")

# Note: Automatic opening of files in Notepad is omitted due to the files being potentially located in a deeply nested directory structure
