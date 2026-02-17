<#
=========================================================================================
Name:           Reset Phone Authentication for Microsoft 365 Users
Version:        1.0
Author:         Ryan Adams
Website:        https://www.governmentcontrol.net/

Script Highlights:
~~~~~~~~~~~~~~~~~~
1. Uses Microsoft Graph PowerShell and installs it if missing.
2. Covers multiple use-cases for deleting Phone MFA:
   - Single user
   - Bulk users (CSV)
   - All users
   - Admin accounts
   - Guest accounts
   - Licensed users
   - Disabled users
3. Supports deletion of all phone types (primary mobile, alternate mobile, office phone).
4. Exports a log file.
5. Works with MFA-enabled accounts and certificate-based authentication.
6. Scheduler-friendly.

GitHub:  https://github.com/Ryan-Adams57
Gitlab:  https://gitlab.com/Ryan-Adams57
PasteBin: https://pastebin.com/u/Removed_Content
=========================================================================================
#>

Param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Primary mobile','Alternate mobile','Office')]
    [string]$ResetPhoneMFA,

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
        "$Timestamp : $UserId's $AuthMethodType MFA method reset successfully."
    } else {
        "$Timestamp : ERROR - $UserId's $AuthMethodType MFA reset failed. Check authentication settings."
    }
    Add-Content -Path $LogFilePath -Value $LogEntry
}

#========================================================================================
# Function: Remove a phone MFA method for a single user
#========================================================================================
function Reset-MFA {
    param(
        [string]$UserId,
        [object]$UserAuthenticationDetail
    )

    $Script:ResetStatus = Remove-MgUserAuthenticationPhoneMethod -UserId $UserId -PhoneAuthenticationMethodId $UserAuthenticationDetail.Id -PassThru
    $MethodType = $UserAuthenticationDetail.PhoneType
    Log-MFAReset -UserId $UserId -AuthMethodType $MethodType -Status $Script:ResetStatus
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
        "Primary mobile"   = "mobile"
        "Alternate mobile" = "alternateMobile"
        "Office"           = "office"
    }

    foreach ($User in $Users) {
        if ($SpecificAuthMethod) {
            $UserAuthenticationDetails = Get-MgUserAuthenticationPhoneMethod -UserId $User |
                                         Where-Object { $_.PhoneType -eq $AuthMethods[$SpecificAuthMethod] }
        } else {
            $UserAuthenticationDetails = Get-MgUserAuthenticationPhoneMethod -UserId $User
        }

        foreach ($Detail in $UserAuthenticationDetails) {
            Reset-MFA -UserId $User -UserAuthenticationDetail $Detail
        }
    }
}

#========================================================================================
# MAIN SCRIPT EXECUTION
#========================================================================================
Connect-ToMgGraph

$LogFilePath = "$(Get-Location)\Phone_MFA_Reset_Log_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm-ss` tt)).txt"

# Fetch all users excluding the currently connected account
$Users = Get-MgUser -All -Property AccountEnabled, AssignedLicenses, UserType, UserPrincipalName |
         Where-Object { $_.UserPrincipalName -ne ((Get-MgContext).Account) }

# Determine user scope and trigger MFA reset
if ($CsvFilePath) {
    $CsvUsers = Import-Csv -Path $CsvFilePath
    $CsvUsers.Name | ForEach-Object { Reset-MfaForUsers -Users $_ -SpecificAuthMethod $ResetPhoneMFA }
}
elseif ($UserId) {
    Reset-MfaForUsers -Users $UserId -SpecificAuthMethod $ResetPhoneMFA
}
elseif ($AllUsers) {
    $Users | ForEach-Object { Reset-MfaForUsers -Users $_.UserPrincipalName -SpecificAuthMethod $ResetPhoneMFA }
}
elseif ($DisabledUsersOnly) {
    $Users | Where-Object { $_.AccountEnabled -eq $false } | ForEach-Object { Reset-MfaForUsers -Users $_.UserPrincipalName -SpecificAuthMethod $ResetPhoneMFA }
}
elseif ($LicensedUsersOnly) {
    $Users | Where-Object { $_.AssignedLicenses.Count -gt 0 } | ForEach-Object { Reset-MfaForUsers -Users $_.UserPrincipalName -SpecificAuthMethod $ResetPhoneMFA }
}
elseif ($GuestUsersOnly) {
    $Users | Where-Object { $_.UserType -eq "Guest" } | ForEach-Object { Reset-MfaForUsers -Users $_.UserPrincipalName -SpecificAuthMethod $ResetPhoneMFA }
}
elseif ($AdminsOnly) {
    $Users | Where-Object { Get-MgUserTransitiveMemberOfAsDirectoryRole -UserId $_.UserPrincipalName } | ForEach-Object { Reset-MfaForUsers -Users $_.UserPrincipalName -SpecificAuthMethod $ResetPhoneMFA }
}
else {
    $UserId = Read-Host "Enter the User ID or UPN of a user to reset MFA"
    Reset-MfaForUsers -Users $UserId -SpecificAuthMethod $ResetPhoneMFA
}

Write-Host "`n~~ Script prepared by Ryan Adams ~~`n" -ForegroundColor Green
Write-Host "GitHub: https://github.com/Ryan-Adams57" -ForegroundColor Cyan
Write-Host "Gitlab: https://gitlab.com/Ryan-Adams57" -ForegroundColor Cyan
Write-Host "Website: https://www.governmentcontrol.net/" -ForegroundColor Cyan
Write-Host "PasteBin: https://pastebin.com/u/Removed_Content" -ForegroundColor Cyan

# Disconnect Graph session
Disconnect-MgGraph | Out-Null

# Open log file if it exists
if (Test-Path $LogFilePath) {
    Write-Host "`nThe MFA reset log file is available at: $LogFilePath" -ForegroundColor Yellow
    $Prompt = New-Object -ComObject wscript.shell
    $UserInput = $Prompt.popup("Do you want to open the log file?", 0, "Open Log File", 4)
    if ($UserInput -eq 6) { Invoke-Item $LogFilePath }
} else {
    Write-Host "`nNo users found for the selected criteria." -ForegroundColor Yellow
}
