<#
=============================================================================================
Name:           Export Microsoft 365 users' last logon time report using PowerShell
Version: 5.0
Last updated on: July, 2023
Website:        https://www.governmentcontrol.net/

Script Highlights:
~~~~~~~~~~~~~~~~~
#. Single script allows you to generate 10+ different last login reports.
#. Supports MFA-enabled accounts.
#. Supports Certificate-based authentication (CBA).
#. Allows retrieving last login time for a list of users via CSV import.
#. Generates reports based on inactive days.
#. Filters by user/all mailbox type.
#. Filters never logged in mailboxes.
#. Generates reports for sign-in enabled users only.
#. Supports filtering licensed users only.
#. Retrieves login time report for admins only.
#. Exports results to CSV.
#. Assigned licenses are shown with user-friendly names.
#. Automatically installs Exchange Online and Microsoft Graph PowerShell modules if needed.

Author: Ryan Adams
GitHub - https://github.com/Ryan-Adams57
Gitlab https://gitlab.com/Ryan-Adams57
PasteBin https://pastebin.com/u/Removed_Content
============================================================================================
#>

Param (
    [string]$MBNamesFile,
    [int]$InactiveDays,
    [switch]$UserMailboxOnly,
    [switch]$ReturnNeverLoggedInMB,
    [switch]$SigninAllowedUsersOnly,
    [switch]$LicensedUsersOnly,
    [switch]$AdminsOnly,
    [string]$TenantId,
    [string]$ClientId,
    [string]$CertificateThumbprint
)

Function ConnectModules {
    $MsGraphBetaModule = Get-Module Microsoft.Graph.Beta -ListAvailable
    if(-not $MsGraphBetaModule) {
        Write-Host "Microsoft Graph Beta module is unavailable. Installing..."
        $confirm = Read-Host "Install Microsoft Graph Beta module? [Y/N]"
        if($confirm -match "[yY]") {
            Install-Module Microsoft.Graph.Beta -Scope CurrentUser -AllowClobber
            Write-Host "Microsoft Graph Beta module installed." -ForegroundColor Magenta
        } else { Exit }
    }

    $ExchangeOnlineModule = Get-Module ExchangeOnlineManagement -ListAvailable
    if(-not $ExchangeOnlineModule) {
        Write-Host "Exchange Online module is unavailable. Installing..."
        $confirm = Read-Host "Install Exchange Online module? [Y/N]"
        if($confirm -match "[yY]") {
            Install-Module ExchangeOnlineManagement -Scope CurrentUser
            Write-Host "Exchange Online module installed." -ForegroundColor Magenta
        } else { Exit }
    }

    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    Disconnect-ExchangeOnline -Confirm:$false

    Write-Progress -Activity "Connecting modules (Microsoft Graph and Exchange Online)..."
    try {
        if($TenantId -and $ClientId -and $CertificateThumbprint) {
            Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -ErrorAction SilentlyContinue -ErrorVariable ConnectionError | Out-Null
            if($ConnectionError) { Write-Host $ConnectionError -ForegroundColor Red; Exit }

            $Scopes = (Get-MgContext).Scopes
            if($Scopes -notcontains "Directory.Read.All" -and $Scopes -notcontains "Directory.ReadWrite.All") {
                Write-Host "Required Graph permission: Directory.Read.All" -ForegroundColor Yellow
                Exit
            }

            Connect-ExchangeOnline -AppId $ClientId -CertificateThumbprint $CertificateThumbprint -Organization (Get-MgDomain | Where-Object {$_.isInitial}).Id -ShowBanner:$false
        } else {
            Connect-MgGraph -Scopes "Directory.Read.All" -ErrorAction SilentlyContinue -ErrorVariable ConnectionError | Out-Null
            if($ConnectionError) { Write-Host $ConnectionError -ForegroundColor Red; Exit }
            Connect-ExchangeOnline -UserPrincipalName (Get-MgContext).Account -ShowBanner:$false
        }
    } catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        Exit
    }

    Write-Host "Microsoft Graph Beta module connected successfully" -ForegroundColor Green
    Write-Host "Exchange Online module connected successfully" -ForegroundColor Green
}

Function CloseConnection {
    Disconnect-MgGraph | Out-Null
    Disconnect-ExchangeOnline -Confirm:$false
}

Function ProcessMailBox {
    Write-Progress -Activity "`nProcessing mailbox: $Script:MailBoxUserCount - $DisplayName"
    $Script:MailBoxUserCount++

    $SigninStatus = if($AccountEnabled) { "Allowed" } else { "Blocked" }

    if(-not $LastLogonTime) {
        $LastLogonTime = "Never Logged In"
        $InactiveDaysOfUser = "-"
    } else {
        $InactiveDaysOfUser = (New-TimeSpan -Start $LastLogonTime).Days
    }

    $Licenses = (Get-MgBetaUserLicenseDetail -UserId $UPN).SkuPartNumber
    $AssignedLicense = @()
    if($Licenses.Count -eq 0) {
        $AssignedLicense = "No License Assigned"
    } else {
        foreach($License in $Licenses) {
            $NamePrint = $FriendlyNameHash[$License] ? $FriendlyNameHash[$License] : $License
            $AssignedLicense += $NamePrint
        }
    }

    if($InactiveDaysOfUser -ne "-" -and $InactiveDays -and $InactiveDays -gt $InactiveDaysOfUser) { return }
    if($UserMailboxOnly.IsPresent -and $MailBoxType -ne "UserMailbox") { return }
    if($ReturnNeverLoggedInMB.IsPresent -and $LastLogonTime -ne "Never Logged In") { return }
    if($SigninAllowedUsersOnly.IsPresent -and -not $AccountEnabled) { return }
    if($LicensedUsersOnly -and $Licenses.Count -eq 0) { return }

    $Roles = @(Get-MgBetaUserTransitiveMemberOf -UserId $UPN | Select-Object -ExpandProperty AdditionalProperties) | ?{ $_.'@odata.type' -eq '#microsoft.graph.directoryRole' }
    $RolesAssigned = if($Roles.Count -eq 0) { "No roles" } else { ($Roles.displayName) -join ',' }
    if($AdminsOnly.IsPresent -and $RolesAssigned -eq "No roles") { return }

    $Script:OutputCount++
    [PSCustomObject]@{
        'UserPrincipalName' = $UPN
        'DisplayName'       = $DisplayName
        'SigninStatus'      = $SigninStatus
        'LastLogonTime'     = $LastLogonTime
        'CreationTime'      = $_.WhenCreated
        'InactiveDays'      = $InactiveDaysOfUser
        'MailboxType'       = $MailBoxType
        'AssignedLicenses'  = ($AssignedLicense -join ',')
        'Roles'             = $RolesAssigned
    } | Export-Csv -Path $ExportCSV -NoTypeInformation -Append
}

# Load license friendly names
try {
    $FriendlyNameHash = Get-Content -Raw -Path .\LicenseFriendlyName.txt -ErrorAction SilentlyContinue | ConvertFrom-StringData
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    Exit
}

# Connect modules
ConnectModules
Write-Host "`nNote: Run in a fresh PowerShell window if module conflicts occur." -ForegroundColor Yellow

$ExportCSV = ".\LastLogonTimeReport_$(Get-Date -Format 'yyyy-MMM-dd-ddd_hh-mm-ss_tt').csv"
$MailBoxUserCount = 1
$OutputCount = 0

if($MBNamesFile) {
    try { $InputFile = Import-Csv -Path $MBNamesFile -Header "MBIdentity" } catch { Write-Host $_.Exception.Message -ForegroundColor Red; CloseConnection; Exit }

    foreach($item in $InputFile.MBIdentity) {
        $Mailbox = Get-ExoMailbox -Identity $item -PropertySets All -ErrorAction SilentlyContinue
        if($Mailbox) {
            $DisplayName = $Mailbox.DisplayName
            $UPN = $Mailbox.UserPrincipalName
            $LastLogonTime = (Get-ExoMailboxStatistics -Identity $UPN -Properties LastLogonTime).LastLogonTime
            $MailBoxType = $Mailbox.RecipientTypeDetails
            $CreatedDateTime = $Mailbox.WhenCreated
            $AccountEnabled = (Get-MgBetaUser -UserId $UPN).AccountEnabled
            ProcessMailBox
        } else {
            Write-Host "$item not found" -ForegroundColor Red
        }
    }
} else {
    Get-ExoMailbox -ResultSize Unlimited -PropertySets All | Where { $_.DisplayName -notlike "Discovery Search Mailbox" } | ForEach-Object {
        $DisplayName = $_.DisplayName
        $UPN = $_.UserPrincipalName
        $LastLogonTime = (Get-ExoMailboxStatistics -Identity $UPN -Properties LastLogonTime).LastLogonTime
        $MailBoxType = $_.RecipientTypeDetails
        $CreatedDateTime = $_.WhenCreated
        $AccountEnabled = (Get-MgBetaUser -UserId $UPN).AccountEnabled
        ProcessMailBox
    }
}

Write-Host "`nScript executed successfully"
if(Test-Path $ExportCSV) {
    Write-Host "Exported report contains $OutputCount mailbox(es)" -ForegroundColor Green
    $Prompt = New-Object -ComObject wscript.shell
    $UserInput = $Prompt.popup("Do you want to open output file?", 0, "Open Output File", 4)
    if ($UserInput -eq 6) { Invoke-Item $ExportCSV }
    Write-Host "`nOutput file available at: $ExportCSV" -ForegroundColor Yellow
} else {
    Write-Host "No mailbox found" -ForegroundColor Red
}

Write-Host "`n~~ Script prepared by Ryan Adams ~~" -ForegroundColor Green
Write-Host "~~ Check out " -NoNewline -ForegroundColor Green; Write-Host "https://www.governmentcontrol.net/" -ForegroundColor Yellow -NoNewline; Write-Host " for more tools and resources. ~~" -ForegroundColor Green

CloseConnection
