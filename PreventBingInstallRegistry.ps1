<#
=============================================================================================
Name:     Prevent Bing Installation via Registry for Office 365
Version:  1.0
Author:   Ryan Adams
Website:  https://www.governmentcontrol.net/
GitHub:   https://github.com/Ryan-Adams57
GitLab:   https://gitlab.com/Ryan-Adams57
PasteBin: https://pastebin.com/u/Removed_Content

~~~~~~~~~~~~~~~~~~
Script Highlights:
~~~~~~~~~~~~~~~~~~
1. Adds a registry key to prevent Bing installation in Chrome for Office 365 Pro Plus.
2. Checks if Office 365 Pro Plus is installed before applying the setting.
============================================================================================
#>

$RegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Common\Officeupdate"
$Name = "preventbinginstall"
$Value = "00000001"

if (-not (Test-Path $RegistryPath)) {
    Write-Host "Office 365 Pro Plus is not available on this system." -ForegroundColor Yellow
}
else {
    New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType DWORD -Force | Out-Null
    Write-Host "Successfully added registry key to prevent Bing installation in Chrome." -ForegroundColor Green
}
