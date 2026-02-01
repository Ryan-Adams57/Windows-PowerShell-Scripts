<#
=============================================================================================
Name:           Exchange Online Archive Mailbox Size Report
Description:    Exports Exchange Online archive mailbox sizes to a CSV file
Version:        1.0

Script Highlights:
~~~~~~~~~~~~~~~~~
1. Validates and installs the Exchange Online PowerShell module if required.
2. Supports CSV input and CSV output.
3. Exports key archive mailbox attributes.
4. Supports MFA and non-MFA accounts.
5. Scheduler-friendly (supports passing credentials).
============================================================================================
#>

param
(
    [string] $UserName = $null,
    [string] $Password = $null,
    [Switch] $UserMBOnly,
    [Switch] $SharedMBOnly,
    [Switch] $AutoExpandingArchiveEnabled,
    [String] $MBIdentityFile
)

function CSVImport {
    $IdentityList = Import-Csv -Header "IdentityValue" $MBIdentityFile
    foreach ($MailboxDetails in $IdentityList) {
        $currIdentity = $MailboxDetails.IdentityValue
        if ($null -eq $WhereObjectCheck) {
            $UserData = Get-Mailbox -Identity $currIdentity -Archive -ErrorAction SilentlyContinue
        }
        else {
            $UserData = Get-Mailbox -Identity $currIdentity -Archive -ErrorAction SilentlyContinue | Where-Object $WhereObjectCheck
        }
        if ($null -eq $UserData) {
            Write-Host "$currIdentity mailbox is not archive-enabled or is invalid."
        }
        else {
            ExportOutput
        }
    }
}

function ExportOutput {
    $ArchiveMailboxSize = (Get-MailboxStatistics -Identity $UserData.UserPrincipalName -Archive -WarningAction SilentlyContinue).TotalItemSize
    if ($null -ne $ArchiveMailboxSize) {
        $ArchiveMailboxSize = $ArchiveMailboxSize.ToString().Split("()")
        $ArchiveMailboxSizeRounded = $ArchiveMailboxSize[0]
        $ArchiveMailboxSizeBytes = ($ArchiveMailboxSize[1].Split(" "))[0]
    }
    else {
        $ArchiveMailboxSizeRounded = "0"
        $ArchiveMailboxSizeBytes = "0"
    }

    $AutoExpandArchive = if ($UserData.AutoExpandingArchiveEnabled) { "Enabled" } else { "Disabled" }

    $ArchiveQuotaSize = ($UserData.ArchiveQuota).ToString().Split("()")[0]
    $ArchiveWarningQuotaSize = ($UserData.ArchiveWarningQuota).ToString().Split("()")[0]

    $global:ReportSize++
    Write-Progress -Activity "Exporting $($UserData.DisplayName)" `
        -Status "Processed mailbox count: $global:ReportSize"

    [PSCustomObject]@{
        'DisplayName'                  = $UserData.DisplayName
        'Email Address'                = $UserData.UserPrincipalName
        'Recipient Type'               = $UserData.RecipientTypeDetails
        'Archive Name'                 = $UserData.ArchiveName
        'Archive Mailbox Size'         = $ArchiveMailboxSizeRounded
        'Archive Mailbox Size (Bytes)' = $ArchiveMailboxSizeBytes
        'Archive Quota'                = $ArchiveQuotaSize
        'Archive Warning Quota'        = $ArchiveWarningQuotaSize
        'Archive Status'               = $UserData.ArchiveStatus
        'Archive State'                = $UserData.ArchiveState
        'Auto Expanding Archive'       = $AutoExpandArchive
    } | Export-Csv -Path $ExportCSVFileName -NoTypeInformation -Append
}

# Check Exchange Online PowerShell module
if (-not (Get-Module ExchangeOnlineManagement -ListAvailable)) {
    Write-Host "Exchange Online PowerShell module is required." 
    $confirm = Read-Host "Install module now? [Y] Yes [N] No"
    if ($confirm -match "[yY]") {
        Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force
    }
    else {
        Exit
    }
}

# Connect to Exchange Online
if (($UserName) -and ($Password)) {
    $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
    $Credential = New-Object System.Management.Automation.PSCredential $UserName, $SecuredPassword
    Connect-ExchangeOnline -Credential $Credential -ShowProgress:$false | Out-Null
}
else {
    Connect-ExchangeOnline
}

$ExportCSVFileName = ".\ArchiveMailboxSizeReport_$((Get-Date -Format 'MMM-dd hh-mm tt')).csv"
Write-Host "Generating report..."

$WhereObjectCheck = $null
if ($UserMBOnly -or $SharedMBOnly) {
    $RecipientType = if ($SharedMBOnly) { 'SharedMailbox' } else { 'UserMailbox' }
    if ($AutoExpandingArchiveEnabled) {
        $WhereObjectCheck = { $_.RecipientTypeDetails -eq $RecipientType -and $_.AutoExpandingArchiveEnabled }
    }
    else {
        $WhereObjectCheck = { $_.RecipientTypeDetails -eq $RecipientType }
    }
}
elseif ($AutoExpandingArchiveEnabled) {
    $WhereObjectCheck = { $_.AutoExpandingArchiveEnabled }
}

$global:ReportSize = 0

if ($MBIdentityFile) {
    CSVImport
}
else {
    $Mailboxes = Get-Mailbox -ResultSize Unlimited -Archive
    if ($WhereObjectCheck) {
        $Mailboxes = $Mailboxes | Where-Object $WhereObjectCheck
    }
    foreach ($UserData in $Mailboxes) {
        ExportOutput
    }
}

if (Test-Path $ExportCSVFileName) {
    Write-Host "`nThe output file contains $global:ReportSize mailboxes."
    Write-Host "Output file location:" -ForegroundColor Yellow
    Write-Host $ExportCSVFileName

    $prompt = New-Object -ComObject wscript.shell
    if ($prompt.Popup("Do you want to open the output file?", 0, "Open Output File", 4) -eq 6) {
        Invoke-Item $ExportCSVFileName
    }
}
else {
    Write-Host "There is no archive mailbox data to return."
}

Disconnect-ExchangeOnline -Confirm:$false | Out-Null
