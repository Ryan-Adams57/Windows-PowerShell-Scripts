<#
=============================================================================================
Name:           Bulk Convert User Mailboxes to Shared Mailboxes
Version:        2.0
Author:         Ryan Adams
Website:        https://www.governmentcontrol.net/
GitHub:         https://github.com/Ryan-Adams57
GitLab:         https://gitlab.com/Ryan-Adams57
PasteBin:       https://pastebin.com/u/Removed_Content
Description:    Converts user mailboxes to shared mailboxes in bulk using
                a CSV file containing UPN values.
Requirements:   ExchangeOnlineManagement (v3+)
=============================================================================================
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CSVPath
)

#region Module Validation

$Module = Get-Module ExchangeOnlineManagement -ListAvailable |
          Where-Object { $_.Version.Major -ge 3 }

if (-not $Module)
{
    Write-Host "ExchangeOnlineManagement v3+ module not detected." -ForegroundColor Yellow
    $Confirm = Read-Host "Install ExchangeOnlineManagement module now? [Y/N]"

    if ($Confirm -match '^[Yy]$')
    {
        Write-Host "Installing ExchangeOnlineManagement module..."
        Install-Module ExchangeOnlineManagement -Repository PSGallery -Scope CurrentUser -AllowClobber -Force
    }
    else
    {
        Write-Host "ExchangeOnlineManagement module is required. Aborting." -ForegroundColor Red
        return
    }
}

Import-Module ExchangeOnlineManagement

#endregion Module Validation

#region CSV Validation

if (-not (Test-Path $CSVPath))
{
    Write-Host "CSV file not found at path: $CSVPath" -ForegroundColor Red
    return
}

try
{
    $MailboxList = Import-Csv -Path $CSVPath
}
catch
{
    Write-Host "Failed to import CSV file: $($_.Exception.Message)" -ForegroundColor Red
    return
}

if (-not $MailboxList)
{
    Write-Host "CSV file is empty or invalid." -ForegroundColor Red
    return
}

#endregion CSV Validation

#region Connect Exchange Online

Write-Host "Connecting to Exchange Online..." -ForegroundColor Green
Connect-ExchangeOnline -ShowBanner:$false

#endregion Connect Exchange Online

#region Conversion Process

foreach ($Entry in $MailboxList)
{
    $UPN = $Entry.UPN

    if (-not $UPN)
    {
        Write-Host "Skipping entry with missing UPN value." -ForegroundColor Yellow
        continue
    }

    Write-Progress -Activity "Converting $UPN to shared mailbox..."

    try
    {
        Set-Mailbox -Identity $UPN -Type Shared -ErrorAction Stop
        Write-Host "$UPN successfully converted to shared mailbox." -ForegroundColor Cyan
    }
    catch
    {
        Write-Host "$UPN - Conversion failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

#endregion Conversion Process

#region Disconnect Session

Disconnect-ExchangeOnline -Confirm:$false | Out-Null
Write-Host "Exchange Online session disconnected." -ForegroundColor Yellow

#endregion Disconnect Session
