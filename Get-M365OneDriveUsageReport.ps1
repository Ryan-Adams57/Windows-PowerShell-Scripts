<#
=============================================================================================
Name:           Get Microsoft 365 OneDrive Usage Report
Description:    Export OneDrive usage report for all personal OneDrive sites
Version:        1.0
Author:         Ryan Adams
Website:        https://www.governmentcontrol.net/
GitHub:         https://github.com/Ryan-Adams57
GitLab:         https://gitlab.com/Ryan-Adams57
PasteBin:       https://pastebin.com/u/Removed_Content

Script Highlights:
~~~~~~~~~~~~~~~~~
1. Exports OneDrive usage report for all OneDrive personal sites.
2. Automatically installs SharePoint Online Management Shell module (with confirmation).
3. Exports report results to CSV.
4. Supports credential-based authentication for scheduler scenarios.
=============================================================================================
#>

param (
    [string] $UserName,
    [string] $Password,
    [string] $HostName
)

Function Connect-SPOServiceModule {

    $SPOService = (Get-Module Microsoft.Online.SharePoint.PowerShell -ListAvailable).Name
    if ($SPOService -eq $null) {
        Write-Host "SharePoint Online Management Shell module not found." -ForegroundColor Yellow
        $confirm = Read-Host "Install module now? [Y] Yes [N] No"
        if ($confirm -match "[Yy]") {
            Write-Host "Installing SharePoint Online Management Shell module..."
            Install-Module -Name Microsoft.Online.SharePoint.PowerShell -AllowClobber -Repository PSGallery -Force -Scope CurrentUser
            Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking
        }
        else {
            Write-Host "Module required. Exiting."
            Exit
        }
    }

    if ($HostName -eq "") {
        Write-Host "Enter SharePoint organization name (e.g., Contoso for admin@Contoso.onmicrosoft.com)" -ForegroundColor Yellow
        $HostName = Read-Host "Organization Name"
    }

    $ConnectionUrl = "https://$HostName-admin.sharepoint.com/"
    Write-Host "`nConnecting to SharePoint Online..."

    if (($UserName -ne "") -and ($Password -ne "")) {
        $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
        $Credential = New-Object System.Management.Automation.PSCredential $UserName, $SecuredPassword
        Connect-SPOService -Credential $Credential -Url $ConnectionUrl | Out-Null
    }
    else {
        Connect-SPOService -Url $ConnectionUrl | Out-Null
    }
}

Connect-SPOServiceModule

$Location = Get-Location
$ExportCSV = "$Location\OneDriveStorageReport_$((Get-Date -format yyyy-MMM-dd_hh-mm_tt)).csv"
$Count = 0

Get-SPOSite -IncludePersonalSite $true -Limit All -Filter "Url -like '-my.sharepoint.com/personal/'" | ForEach-Object {

    $Count++
    $UPN = $_.Owner
    $Url = $_.Url
    $StorageSize = $_.StorageUsageCurrent
    $StorageQuota = $_.StorageQuota

    Write-Progress -Activity "Processed OneDrive site count: $Count" -Status "Currently processing: $Url"

    $StorageQuotaGB = [math]::Round($StorageQuota / 1024, 2)
    $StorageSizeGB = [math]::Round($StorageSize / 1024, 2)

    $Result = @{
        'Owner UPN' = $UPN
        'OneDrive Url' = $Url
        'Storage Used (GB)' = $StorageSizeGB
        'Storage Quota (GB)' = $StorageQuotaGB
        'Storage Used (MB)' = $StorageSize
        'Storage Quota (MB)' = $StorageQuota
        'Status' = $_.Status
        'Archive Status' = $_.ArchiveStatus
        'Last Content Modified Date' = $_.LastContentModifiedDate
    }

    New-Object PSObject -Property $Result |
    Select-Object 'Owner UPN','OneDrive Url','Storage Used (GB)','Storage Quota (GB)',
                  'Storage Used (MB)','Storage Quota (MB)','Status','Archive Status',
                  'Last Content Modified Date' |
    Export-Csv -Path $ExportCSV -NoTypeInformation -Append
}

if (Test-Path $ExportCSV) {
    Write-Host "`nExported report contains $Count OneDrive sites."
    Write-Host "Report available at:" -ForegroundColor Yellow
    Write-Host $ExportCSV

    $Prompt = New-Object -ComObject wscript.shell
    $UserInput = $Prompt.popup("Do you want to open the output file?",0,"Open Output File",4)
    if ($UserInput -eq 6) {
        Invoke-Item "$ExportCSV"
    }
}
else {
    Write-Host "No OneDrive accounts found."
}

Disconnect-SPOService
