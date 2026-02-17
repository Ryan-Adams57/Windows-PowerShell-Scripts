<#
=============================================================================================
Name:           Convert Distribution Lists to Microsoft 365 Groups
Version:        2.0
Author:         Ryan Adams
Website:        https://www.governmentcontrol.net/
GitHub:         https://github.com/Ryan-Adams57
GitLab:         https://gitlab.com/Ryan-Adams57
PasteBin:       https://pastebin.com/u/Removed_Content
Description:    Converts eligible Exchange Online Distribution Groups to
                Microsoft 365 (Unified) Groups with validation and
                controlled property migration.
Requirements:   ExchangeOnlineManagement (v3+)
=============================================================================================
#>

[CmdletBinding()]
param ( 
    [string]$DistributionEmailAddress,
    [string]$UserName,
    [string]$Password,
    [string]$InputFile
)

#region Exchange Connection

function Connect-ExchangeOnlineSession {

    Write-Host "Validating Exchange Online module..." -ForegroundColor Cyan

    $module = Get-Module ExchangeOnlineManagement -ListAvailable |
              Where-Object { $_.Version.Major -ge 3 }

    if (-not $module) {
        Write-Host "ExchangeOnlineManagement v3+ is required." -ForegroundColor Yellow
        $confirm = Read-Host "Install module now? [Y/N]"
        if ($confirm -match '^[Yy]$') {
            Install-Module ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber
        }
        else {
            throw "Module installation declined."
        }
    }

    Import-Module ExchangeOnlineManagement
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue

    try {
        if ($UserName -and $Password) {
            $secure = ConvertTo-SecureString $Password -AsPlainText -Force
            $cred   = New-Object pscredential ($UserName, $secure)
            Connect-ExchangeOnline -Credential $cred -ShowBanner:$false
        }
        else {
            Connect-ExchangeOnline -ShowBanner:$false
        }

        Write-Host "Exchange Online connected successfully." -ForegroundColor Green
    }
    catch {
        throw "Exchange Online connection failed: $($_.Exception.Message)"
    }
}

function Disconnect-Session {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
}

#endregion Exchange Connection

#region Conversion Functions

function Convert-ToM365Group {

    param (
        [Parameter(Mandatory)]
        [string]$DLMail,

        [Parameter(Mandatory)]
        [ValidateSet('Private','Public')]
        [string]$AccessType
    )

    Write-Host "`nProcessing: $DLMail" -ForegroundColor Magenta

    $DLGroup = Get-DistributionGroup -Identity $DLMail -ErrorAction SilentlyContinue
    if (-not $DLGroup) {
        Write-Host "Distribution group not found." -ForegroundColor Red
        return
    }

    $eligible = (Get-EligibleDistributionGroupForMigration).PrimarySmtpAddress
    if ($eligible -notcontains $DLMail) {
        Write-Host "Group is not eligible for Microsoft 365 Group conversion." -ForegroundColor Red
        return
    }

    $members = (Get-DistributionGroupMember -Identity $DLMail -ErrorAction SilentlyContinue).PrimarySmtpAddress

    try {
        $params = @{
            DisplayName                        = $DLGroup.DisplayName
            AccessType                         = $AccessType
            ManagedBy                          = $DLGroup.ManagedBy
            RequireSenderAuthenticationEnabled = $DLGroup.RequireSenderAuthenticationEnabled
        }

        if ($members) {
            $params.Add("Members", $members)
        }

        if ($AccessType -eq 'Private') {
            $params.Add("HiddenGroupMembershipEnabled", $DLGroup.HiddenGroupMembershipEnabled)
        }

        $newGroup = New-UnifiedGroup @params

        if (-not $newGroup) {
            throw "Unified group creation failed."
        }

        Write-Host "Microsoft 365 group created successfully." -ForegroundColor Green

        # Remove old DL
        Remove-DistributionGroup -Identity $DLMail -Confirm:$false

        # Wait for directory replication
        Start-Sleep -Seconds 5

        # Reassign original SMTP + properties
        Set-UnifiedGroup -Identity $newGroup.PrimarySmtpAddress `
            -PrimarySmtpAddress $DLMail `
            -EmailAddresses @{Add = "X500:$($DLGroup.LegacyExchangeDN)"} `
            -HiddenFromAddressListsEnabled $DLGroup.HiddenFromAddressListsEnabled `
            -AcceptMessagesOnlyFromSendersOrMembers $DLGroup.AcceptMessagesOnlyFromSendersOrMembers `
            -GrantSendOnBehalfTo $DLGroup.GrantSendOnBehalfTo `
            -ModeratedBy $DLGroup.ModeratedBy `
            -MailTip $DLGroup.MailTip

        Write-Host "Distribution list successfully converted to Microsoft 365 group." -ForegroundColor Cyan
    }
    catch {
        Write-Host "Conversion failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

#endregion Conversion Functions

#region Input Handling

Connect-ExchangeOnlineSession

$DLList = @()

if ($DistributionEmailAddress) {
    $DLList = $DistributionEmailAddress.Split(",") | ForEach-Object { $_.Trim() }
}
elseif ($InputFile) {
    if (-not (Test-Path $InputFile)) {
        Write-Host "Input file not found." -ForegroundColor Red
        Disconnect-Session
        return
    }

    $fileData = Import-Csv -Path $InputFile -Header "DLMail","AccessType"
    $DLList = $fileData
}
else {
    $input = Read-Host "Enter distribution email address(es) (comma separated)"
    if ($input) {
        $DLList = $input.Split(",") | ForEach-Object { $_.Trim() }
    }
}

#endregion Input Handling

#region Execution

if ($InputFile) {
    foreach ($row in $DLList) {
        $access = if ($row.AccessType -in @('Private','Public')) { $row.AccessType } else { 'Private' }
        Convert-ToM365Group -DLMail $row.DLMail -AccessType $access
    }
}
else {
    foreach ($dl in $DLList) {
        $access = Read-Host "Access type for $dl (Private/Public)"
        if ($access -notin @('Private','Public')) { $access = 'Private' }
        Convert-ToM365Group -DLMail $dl -AccessType $access
    }
}

Disconnect-Session

#endregion Execution
