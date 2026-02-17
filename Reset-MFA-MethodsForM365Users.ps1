<#
=========================================================================================
Name:           Reset MFA Methods for Microsoft 365 Users
Version:        1.0
Author:         Ryan Adams
Website:        https://www.governmentcontrol.net/

Script Highlights:
~~~~~~~~~~~~~~~~~~
1. Supports 25+ granular MFA reset use-cases for Microsoft 365 users.
2. User scope options:
   - Single user
   - Bulk users (CSV)
   - All users
   - Admin accounts
   - Guest accounts
   - Licensed users
   - Disabled users
3. Supported authentication methods:
   - Email 
   - FIDO2 
   - Microsoft Authenticator 
   - Phone 
   - Software OATH 
   - Temporary Access Pass 
   - Windows Hello for Business
4. Exports a log file.
5. Supports certificate-based authentication.

GitHub:  https://github.com/Ryan-Adams57
Gitlab:  https://gitlab.com/Ryan-Adams57
PasteBin: https://pastebin.com/u/Removed_Content
=========================================================================================
#>

Param(
    [Parameter(Mandatory = $false)]
    [ValidateSet(
        'Email',
        'FIDO2',
        'Microsoft Authenticator',
        'Phone',
        'Software OATH',
        'Temporary Access Pass',
        'Windows Hello for Business'
    )]
    [string]$ResetMFAMethod,

    [string]$UserId,
    [string]$CsvFilePath,

    [switch]$AllUsers,
    [switch]$AdminsOnly,
    [switch]$GuestUsersOnly,
    [switch]$LicensedUsersOnly,
    [switch]$DisabledUsersOnly,

    [string]$TenantId,
    [string]$ClientId,
    [string]$CertificateThumbprint
)

#========================================================================================
# Function: Connect to Microsoft Graph
#========================================================================================
function Connect-ToMgGraph {
    $MsGraphModule = Get-Module Microsoft.Graph -ListAvailable
    if (-not $MsGraphModule) {
        Write-Host "Microsoft Graph module is missing." -ForegroundColor Yellow
        $confirm = Read-Host "Do you want to install Microsoft Graph module? [Y] Yes [N] No"
        if ($confirm -match "[yY]") {
            Install-Module Microsoft.Graph -Scope CurrentUser -AllowClobber
            Write-Host "Microsoft Graph installed successfully." -ForegroundColor Magenta
        } else {
            Write-Host "Cannot continue without Microsoft Graph module." -ForegroundColor Red
            Exit
        }
    }

    Write-Host "Connecting to Microsoft Graph..."
    if ($TenantId -and $ClientId -and $CertificateThumbprint) {
        Connect-MgGraph -TenantId $TenantId -AppId $ClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome
    } else {
        Connect-MgGraph -Scopes "User.Read.All","UserAuthenticationMethod.ReadWrite.All" -NoWelcome
    }

    if (Get-MgContext) {
        Write-Host "Connected to Microsoft Graph as $((Get-MgContext).Account)" -ForegroundColor Yellow
    } else {
        Write-Host "Failed to connect to Microsoft Graph." -ForegroundColor Red
        Exit
    }
}

#========================================================================================
# Function: Log MFA reset operations
#========================================================================================
function Log-MFAReset {
    param (
        [string]$UserId,
        [string]$AuthMethodType,
        [bool]$Status
    )
    $Timestamp = Get-Date
    $LogEntry = if ($Status) {
        "$Timestamp - MFA reset for $UserId on $AuthMethodType was successful."
    } else {
        "$Timestamp - MFA reset for $UserId on $AuthMethodType failed."
    }
    Add-Content -Path $LogFilePath -Value $LogEntry
}

#========================================================================================
# Function: Remove a specific MFA method for a single user
#========================================================================================
function Reset-MFA {
    param(
        [string]$UserId,
        [object]$UserAuthenticationDetail
    )

    $MethodType = $UserAuthenticationDetail.AdditionalProperties['@odata.type']
    $FriendlyAuthName = $AuthMethods.Keys | Where-Object { $AuthMethods[$_] -eq $MethodType }

    if ($MethodType -eq '#microsoft.graph.passwordAuthenticationMethod') { return }

    switch ($MethodType) {
        '#microsoft.graph.emailAuthenticationMethod' {
            $Script:ResetStatus = Remove-MgUserAuthenticationEmailMethod -UserId $UserId -EmailAuthenticationMethodId $UserAuthenticationDetail.Id -PassThru
        }
        '#microsoft.graph.fido2AuthenticationMethod' {
            $Script:ResetStatus = Remove-MgUserAuthenticationFido2Method -UserId $UserId -Fido2AuthenticationMethodId $UserAuthenticationDetail.Id -PassThru
        }
        '#microsoft.graph.microsoftAuthenticatorAuthenticationMethod' {
            $Script:ResetStatus = Remove-MgUserAuthenticationMicrosoftAuthenticatorMethod -UserId $UserId -MicrosoftAuthenticatorAuthenticationMethodId $UserAuthenticationDetail.Id -PassThru
        }
        '#microsoft.graph.phoneAuthenticationMethod' {
            $Script:ResetStatus = Remove-MgUserAuthenticationPhoneMethod -UserId $UserId -PhoneAuthenticationMethodId $UserAuthenticationDetail.Id -PassThru
        }
        '#microsoft.graph.softwareOathAuthenticationMethod' {
            $Script:ResetStatus = Remove-MgUserAuthenticationSoftwareOathMethod -UserId $UserId -SoftwareOathAuthenticationMethodId $UserAuthenticationDetail.Id -PassThru
        }
        '#microsoft.graph.temporaryAccessPassAuthenticationMethod' {
            $Script:ResetStatus = Remove-MgUserAuthenticationTemporaryAccessPassMethod -UserId $UserId -TemporaryAccessPassAuthenticationMethodId $UserAuthenticationDetail.Id -PassThru
        }
        '#microsoft.graph.windowsHelloForBusinessAuthenticationMethod' {
            $Script:ResetStatus = Remove-MgUserAuthenticationWindowsHelloForBusinessMethod -UserId $UserId -WindowsHelloForBusinessAuthenticationMethodId $UserAuthenticationDetail.Id -PassThru
        }
    }

    Log-MFAReset -UserId $UserId -AuthMethodType $FriendlyAuthName -Status $Script:ResetStatus
}

#========================================================================================
# Function: Reset MFA for multiple users
#========================================================================================
function Reset-MfaForUsers {
    param(
        [string[]]$Users,
        [string]$SpecificAuthMethod
    )

    $AuthMethods = @{
        "Email" = "#microsoft.graph.emailAuthenticationMethod"
        "FIDO2" = "#microsoft.graph.fido2AuthenticationMethod"
        "Microsoft Authenticator" = "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod"
        "Phone" = "#microsoft.graph.phoneAuthenticationMethod"
        "Password" = "#microsoft.graph.passwordAuthenticationMethod"
        "Software OATH" = "#microsoft.graph.softwareOathAuthenticationMethod"
        "Temporary Access Pass" = "#microsoft.graph.temporaryAccessPassAuthenticationMethod"
        "Windows Hello for Business" = "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod"
    }

    foreach ($User in $Users) {
        if ($SpecificAuthMethod) {
            $UserAuthenticationDetails = Get-MgUserAuthenticationMethod -UserId $User |
                                         Select-Object Id, AdditionalProperties |
                                         Where-Object { $_.AdditionalProperties['@odata.type'] -eq $AuthMethods[$SpecificAuthMethod] }
        } else {
            $UserAuthenticationDetails = Get-MgUserAuthenticationMethod -UserId $User | Select-Object Id, AdditionalProperties
        }

        foreach ($Detail in $UserAuthenticationDetails) {
            $Script:ResetStatus = $false
            Reset-MFA -UserId $User -UserAuthenticationDetail $Detail
            if (-not $Script:ResetStatus) {
                Reset-MFA -UserId $User -UserAuthenticationDetail $Detail
            }
        }
    }
}

#========================================================================================
# MAIN SCRIPT EXECUTION
#========================================================================================
Connect-ToMgGraph

$LogFilePath = "$(Get-Location)\MFA_Reset_Log_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm-ss` tt)).txt"

$Users = Get-MgUser -All -Property AccountEnabled, AssignedLicenses, UserType, UserPrincipalName |
         Select-Object AccountEnabled, AssignedLicenses, UserType, UserPrincipalName

if ($CsvFilePath) {
    $CsvUsers = Import-Csv -Path $CsvFilePath
    $CsvUsers.Name | ForEach-Object { Reset-MfaForUsers -Users $_ -SpecificAuthMethod $ResetMFAMethod }
}
elseif ($UserId) {
    Reset-MfaForUsers -Users $UserId -SpecificAuthMethod $ResetMFAMethod
}
elseif ($AllUsers) {
    $Users | ForEach-Object { Reset-MfaForUsers -Users $_.UserPrincipalName -SpecificAuthMethod $ResetMFAMethod }
}
elseif ($DisabledUsersOnly) {
    $Users | Where-Object { $_.AccountEnabled -eq $false } | ForEach-Object { Reset-MfaForUsers -Users $_.UserPrincipalName -SpecificAuthMethod $ResetMFAMethod }
}
elseif ($LicensedUsersOnly) {
    $Users | Where-Object { $_.AssignedLicenses.Count -gt 0 } | ForEach-Object { Reset-MfaForUsers -Users $_.UserPrincipalName -SpecificAuthMethod $ResetMFAMethod }
}
elseif ($GuestUsersOnly) {
    $Users | Where-Object { $_.UserType -eq "Guest" } | ForEach-Object { Reset-MfaForUsers -Users $_.UserPrincipalName -SpecificAuthMethod $ResetMFAMethod }
}
elseif ($AdminsOnly) {
    $Users | Where-Object { Get-MgUserTransitiveMemberOfAsDirectoryRole -UserId $_.UserPrincipalName } | ForEach-Object { Reset-MfaForUsers -Users $_.UserPrincipalName -SpecificAuthMethod $ResetMFAMethod }
}
else {
    $UserId = Read-Host "Enter the User ID or UPN of a user to reset MFA"
    Reset-MfaForUsers -Users $UserId -SpecificAuthMethod $ResetMFAMethod
}

Write-Host "`n~~ Script prepared by Ryan Adams ~~`n" -ForegroundColor Green
Write-Host "GitHub: https://github.com/Ryan-Adams57" -ForegroundColor Cyan
Write-Host "Gitlab: https://gitlab.com/Ryan-Adams57" -ForegroundColor Cyan
Write-Host "Website: https://www.governmentcontrol.net/" -ForegroundColor Cyan
Write-Host "PasteBin: https://pastebin.com/u/Removed_Content" -ForegroundColor Cyan

Disconnect-MgGraph | Out-Null

if (Test-Path $LogFilePath) {
    Write-Host "`nThe MFA reset log file is available at: $LogFilePath" -ForegroundColor Yellow
    $Prompt = New-Object -ComObject wscript.shell
    $UserInput = $Prompt.popup("Do you want to open the log file?", 0, "Open Log File", 4)
    if ($UserInput -eq 6) { Invoke-Item $LogFilePath }
} else {
    Write-Host "`nNo users found or selected MFA method(s) not configured." -ForegroundColor Yellow
}
