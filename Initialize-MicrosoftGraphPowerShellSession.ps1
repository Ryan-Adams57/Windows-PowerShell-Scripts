<#
=============================================================================================
Name:           Initialize Microsoft Graph PowerShell SDK Session
Version:        2.0
Author:         Ryan Adams
Website:        https://www.governmentcontrol.net/
GitHub:         https://github.com/Ryan-Adams57
GitLab:         https://gitlab.com/Ryan-Adams57
PasteBin:       https://pastebin.com/u/Removed_Content
Description:    Establishes a connection to Microsoft Graph PowerShell SDK with required scopes.
=============================================================================================
#>

Param
(
    [Parameter(Mandatory = $false)]
    [switch]$CreateSession
)

# Check for Microsoft Graph module installation
$Module = Get-Module -Name Microsoft.Graph -ListAvailable
if ($Module.Count -eq 0)
{ 
    Write-Host "Microsoft Graph PowerShell SDK is not available." -ForegroundColor Yellow  
    $Confirm = Read-Host "Are you sure you want to install the module? [Y] Yes [N] No"
    
    if ($Confirm -match "[yY]") 
    { 
        Write-Host "Installing Microsoft Graph PowerShell module..."
        Install-Module Microsoft.Graph -Repository PSGallery -Scope CurrentUser -AllowClobber -Force
    }
    else
    {
        Write-Host "Microsoft Graph PowerShell module is required to run this script. Please install the module using the Install-Module Microsoft.Graph cmdlet."
        Exit
    }
}

# Disconnect existing Microsoft Graph session if requested
if ($CreateSession.IsPresent)
{
    Disconnect-MgGraph -ErrorAction SilentlyContinue
}

Write-Host "Connecting to Microsoft Graph..."
Connect-MgGraph -Scopes "User.Read.All","UserAuthenticationMethod.Read.All"

# Validate connection
$MgContext = Get-MgContext
if ($null -ne $MgContext -and $MgContext.Account)
{
    Write-Host "Connected to Microsoft Graph PowerShell using $($MgContext.Account) account." -ForegroundColor Yellow
}
else
{
    Write-Host "Microsoft Graph connection failed or no active context detected." -ForegroundColor Red
}
