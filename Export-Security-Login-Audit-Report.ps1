
# Parameters
$Path = "C:\SysAudit\Logs"
$Prefix = 'Users_'

# Create folder if not exists
if (-not (Test-Path -Path $Path)) {
    New-Item -Path $Path -ItemType Directory | Out-Null
}

# Cleanup old logs (older than 30 days)
$Days = 30
$CutoffDate = (Get-Date).AddDays(-$Days)
Get-ChildItem -Path "$Path\$Prefix*" -Recurse -File |
    Where-Object { $_.LastWriteTime -lt $CutoffDate } |
    Remove-Item -Force -Verbose

# Setup date range (yesterday to today)
$StartDate = (Get-Date).AddDays(-1)
$EndDate = Get-Date

# Setup log file name
$fileName = "$Prefix$($EndDate.ToString('yyyyMMdd_HHmmss')).csv"
$LogFile = Join-Path -Path $Path -ChildPath $fileName

# Event IDs
# 4624 - Successful login
# 4625 - Failed login
# 4648 - Logon with explicit credentials
# 4634 - Logoff
# 4647 - User-initiated logoff

Get-WinEvent -FilterHashtable @{
        LogName = 'Security';
        ID = 4624,4625,4648,4634,4647;
        StartTime = $StartDate;
        EndTime = $EndDate
    } |
    Where-Object {
        $_.Properties[5].Value -notlike "NT AUTHORITY\*" -and
        $_.Properties[5].Value -ne "ANONYMOUS LOGON" -and
        $_.Properties[5].Value -ne "SYSTEM"
    } |
    Select-Object `
        TimeCreated, 
        @{Name="EventType";Expression={
            switch ($_.Id) {
                4624 { "Logon" }
                4634 { "Logoff" }
                4647 { "Logoff" }
                4625 { "LogonFailed" }
                4648 { "LogonAttempted" }
                default { "Unknown" }
            }
        }},
        @{Name="UserName";Expression={$_.Properties[5].Value}},
        @{Name="IPAddress";Expression={$_.Properties[18].Value}} |
    Export-Csv -Path $LogFile -NoTypeInformation
