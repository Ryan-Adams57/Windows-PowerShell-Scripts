<#
=============================================================================================
Name:           Connect Microsoft 365 Services (Unified PowerShell Connector)
Version:        6.0
Author:         Ryan Adams
Website:        https://www.governmentcontrol.net/
GitHub:         https://github.com/Ryan-Adams57
GitLab:         https://gitlab.com/Ryan-Adams57
PasteBin:       https://pastebin.com/u/Removed_Content
Description:    Installs required modules (if missing) and connects to supported
                Microsoft 365 services using interactive login, credential,
                or certificate-based authentication (CBA).
=============================================================================================
#>

[CmdletBinding()]
Param
(
    [Parameter(Mandatory = $false)]
    [switch]$Disconnect,

    [ValidateSet(
        'MSGraph',
        'MSGraphBeta',
        'ExchangeOnline',
        'SharePointOnline',
        'SharePointPnP',
        'SecAndCompCenter',
        'MSTeams',
        'MSEntra'
    )]
    [string[]]$Services = @(
        'ExchangeOnline',
        'MSTeams',
        'SharePointOnline',
        'SharePointPnP',
        'SecAndCompCenter',
        'MSGraph',
        'MSGraphBeta',
        'MSEntra'
    ),

    [string]$SharePointHostName,
    [switch]$MFA,
    [switch]$CBA,
    [string]$TenantName,
    [string]$TenantId,
    [string]$AppId,
    [string]$CertificateThumbprint,
    [string]$UserName,
    [string]$Password
)

#region Helper Functions

function Install-RequiredModule {
    param (
        [Parameter(Mandatory)]
        [string]$ModuleName
    )

    $module = Get-InstalledModule -Name $ModuleName -ErrorAction SilentlyContinue
    if (-not $module) {
        Write-Host "$ModuleName module not found." -ForegroundColor Yellow
        $confirm = Read-Host "Install $ModuleName module? [Y] Yes [N] No"
        if ($confirm -match '^[Yy]$') {
            Install-Module $ModuleName -Scope CurrentUser -AllowClobber -Force
        }
        else {
            throw "$ModuleName module is required. Aborting."
        }
    }
}

function Add-ConnectedService {
    param(
        [string]$ServiceName
    )
    if ($script:ConnectedServices) {
        $script:ConnectedServices += ", $ServiceName"
    }
    else {
        $script:ConnectedServices = $ServiceName
    }
}

#endregion Helper Functions

#region Disconnect Logic

if ($Disconnect.IsPresent) {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    Disconnect-MicrosoftTeams -ErrorAction SilentlyContinue
    Disconnect-SPOService -ErrorAction SilentlyContinue
    Disconnect-PnPOnline -ErrorAction SilentlyContinue
    Disconnect-MgGraph -ErrorAction SilentlyContinue
    Disconnect-Entra -ErrorAction SilentlyContinue

    Write-Host "All active Microsoft 365 service sessions have been disconnected." -ForegroundColor Yellow
    return
}

#endregion Disconnect Logic

#region Credential Handling

$CredentialPassed = $false

if ($UserName -and $Password) {
    $SecurePassword = ConvertTo-SecureString -AsPlainText $Password -Force
    $Credential = New-Object System.Management.Automation.PSCredential ($UserName, $SecurePassword)
    $CredentialPassed = $true
}
elseif ($AppId -and $CertificateThumbprint -and ($TenantId -or $TenantName)) {
    $CBA = $true
}

#endregion Credential Handling

$ConnectedServices = ""

foreach ($Service in $Services) {

    Write-Host "Connecting to $Service..." -ForegroundColor Green

    switch ($Service) {

        #region Exchange Online
        'ExchangeOnline' {
            Install-RequiredModule -ModuleName "ExchangeOnlineManagement"
            Import-Module ExchangeOnlineManagement

            if ($CredentialPassed) {
                Connect-ExchangeOnline -Credential $Credential -ShowBanner:$false
            }
            elseif ($CBA) {
                Connect-ExchangeOnline -AppId $AppId `
                    -CertificateThumbprint $CertificateThumbprint `
                    -Organization $TenantName `
                    -ShowBanner:$false
            }
            else {
                Connect-ExchangeOnline -ShowBanner:$false
            }

            if (Get-EXOMailbox -ResultSize 1 -ErrorAction SilentlyContinue) {
                Add-ConnectedService "Exchange Online"
            }
        }
        #endregion

        #region SharePoint Online
        'SharePointOnline' {
            Install-RequiredModule -ModuleName "Microsoft.Online.SharePoint.PowerShell"
            Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking

            if (-not $SharePointHostName) {
                $SharePointHostName = Read-Host "Enter SharePoint organization name (e.g. contoso)"
            }

            $spoUrl = "https://$SharePointHostName-admin.sharepoint.com"

            if ($CredentialPassed) {
                Connect-SPOService -Url $spoUrl -Credential $Credential
            }
            elseif ($CBA) {
                $Cert = Get-ChildItem "Cert:\CurrentUser\My\$CertificateThumbprint"
                Connect-SPOService -Url $spoUrl -ClientId $AppId -Tenant $TenantName -Certificate $Cert
            }
            else {
                Connect-SPOService -Url $spoUrl
            }

            if (Get-SPOTenant -ErrorAction SilentlyContinue) {
                Add-ConnectedService "SharePoint Online"
            }
        }
        #endregion

        #region SharePoint PnP
        'SharePointPnP' {
            Install-RequiredModule -ModuleName "PnP.PowerShell"
            Import-Module PnP.PowerShell

            if (-not $SharePointHostName) {
                $SharePointHostName = Read-Host "Enter SharePoint organization name"
            }

            if (-not $AppId) {
                $AppId = Read-Host "Enter Azure App (Client) ID for PnP"
            }

            $pnpUrl = "https://$SharePointHostName-admin.sharepoint.com"

            if ($CredentialPassed) {
                Connect-PnPOnline -Url $pnpUrl -Credential $Credential -ClientId $AppId
            }
            elseif ($CBA) {
                Connect-PnPOnline -Url $pnpUrl -ClientId $AppId `
                    -Thumbprint $CertificateThumbprint `
                    -Tenant $TenantName
            }
            else {
                Connect-PnPOnline -Url $pnpUrl -ClientId $AppId -Interactive
            }

            if ($?) { Add-ConnectedService "SharePoint PnP" }
        }
        #endregion

        #region Security & Compliance Center
        'SecAndCompCenter' {
            Install-RequiredModule -ModuleName "ExchangeOnlineManagement"
            Import-Module ExchangeOnlineManagement

            if ($CredentialPassed) {
                Connect-IPPSSession -Credential $Credential -ShowBanner:$false
            }
            elseif ($CBA) {
                Connect-IPPSSession -AppId $AppId `
                    -CertificateThumbprint $CertificateThumbprint `
                    -Organization $TenantName `
                    -ShowBanner:$false
            }
            else {
                Connect-IPPSSession -ShowBanner:$false
            }

            if ($?) { Add-ConnectedService "Security & Compliance Center" }
        }
        #endregion

        #region Microsoft Teams
        'MSTeams' {
            Install-RequiredModule -ModuleName "MicrosoftTeams"
            Import-Module MicrosoftTeams

            if ($CredentialPassed) {
                Connect-MicrosoftTeams -Credential $Credential
            }
            elseif ($CBA) {
                Connect-MicrosoftTeams -ApplicationId $AppId `
                    -TenantId $TenantId `
                    -CertificateThumbPrint $CertificateThumbprint
            }
            else {
                Connect-MicrosoftTeams
            }

            if ($?) { Add-ConnectedService "Microsoft Teams" }
        }
        #endregion

        #region Microsoft Graph
        'MSGraph' {
            Install-RequiredModule -ModuleName "Microsoft.Graph"
            Import-Module Microsoft.Graph.Users

            if ($CBA) {
                Connect-MgGraph -ApplicationId $AppId `
                    -TenantId $TenantId `
                    -CertificateThumbPrint $CertificateThumbprint `
                    -NoWelcome
            }
            else {
                Connect-MgGraph -NoWelcome
            }

            if (Get-MgUser -Top 1 -ErrorAction SilentlyContinue) {
                Add-ConnectedService "Microsoft Graph"
            }
        }
        #endregion

        #region Microsoft Graph Beta
        'MSGraphBeta' {
            Install-RequiredModule -ModuleName "Microsoft.Graph.Beta"
            Import-Module Microsoft.Graph.Beta.Users

            if ($CBA) {
                Connect-MgGraph -ApplicationId $AppId `
                    -TenantId $TenantId `
                    -CertificateThumbPrint $CertificateThumbprint `
                    -NoWelcome
            }
            else {
                Connect-MgGraph -NoWelcome
            }

            if (Get-MgBetaUser -Top 1 -ErrorAction SilentlyContinue) {
                Add-ConnectedService "Microsoft Graph Beta"
            }
        }
        #endregion

        #region Microsoft Entra
        'MSEntra' {
            Install-RequiredModule -ModuleName "Microsoft.Entra"
            Import-Module Microsoft.Entra.Users

            if ($CBA) {
                Connect-Entra -ApplicationId $AppId `
                    -TenantId $TenantId `
                    -CertificateThumbPrint $CertificateThumbprint `
                    -NoWelcome
            }
            else {
                Connect-Entra -NoWelcome
            }

            if (Get-EntraUser -Top 1 -ErrorAction SilentlyContinue) {
                Add-ConnectedService "Microsoft Entra"
            }
        }
        #endregion
    }
}

if (-not $ConnectedServices) {
    $ConnectedServices = "-"
}

Write-Host "`nConnected Services: $ConnectedServices" -ForegroundColor Cyan
