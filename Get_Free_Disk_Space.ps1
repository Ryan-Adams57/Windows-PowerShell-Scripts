$Drives = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType = 3"

foreach ($Drive in $Drives) {
    $DriveSize = [math]::Round($Drive.Size / 1GB)
    $FreeSpace = [math]::Round($Drive.FreeSpace / 1GB)
    $UsedSpace = $DriveSize - $FreeSpace
    "$UsedSpace GB used, $FreeSpace GB free on drive $($Drive.DeviceID) on $($env:COMPUTERNAME)"
}
