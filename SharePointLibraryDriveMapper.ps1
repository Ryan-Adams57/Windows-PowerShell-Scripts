<#
.SYNOPSIS
Maps a SharePoint Online document library to a local network drive.

.DESCRIPTION
This script opens Internet Explorer in the background to establish authentication,
waits for the session to initialize, then maps the specified SharePoint Online
document library to a local drive letter.

Author: Ryan Adams
Website: https://www.governmentcontrol.net/
GitHub: https://github.com/Ryan-Adams57
GitLab: https://gitlab.com/Ryan-Adams57
PasteBin: https://pastebin.com/u/Removed_Content
#>

$URL = "https://your_domain.sharepoint.com/sites/test_site/Shared%20Documents" # Replace with your document library URL copied in the first procedure

$IESession = Start-Process -FilePath "iexplore.exe" -ArgumentList $URL -PassThru -WindowStyle Hidden

Start-Sleep -Seconds 20

$IESession.Kill()

$Network = New-Object -ComObject WScript.Network

$Network.MapNetworkDrive('Z:', $URL) # Use the required drive name in place of 'Z:'