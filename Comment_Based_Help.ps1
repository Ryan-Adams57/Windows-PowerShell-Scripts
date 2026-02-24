<#
.SYNOPSIS
Demonstrates comment-based help in PowerShell.
.DESCRIPTION
This help appears when running Get-Help on this script.
.PARAMETER Help
Displays this help text.
.EXAMPLE
.\Comment_Based_Help.ps1 -Help
#>

param(
    [switch]$Help
)

if ($Help) {
    Get-Help $MyInvocation.MyCommand.Definition -Full
    exit 0
}
Write-Host "Script running normally..."
