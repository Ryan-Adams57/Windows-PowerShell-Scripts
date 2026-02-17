<#
=============================================================================================
Name:           Remove Email Forwarding in Office 365
Version:        1.0
Website:        https://www.governmentcontrol.net/

Script Highlights: 
~~~~~~~~~~~~~~~~~
1. Connects to Exchange Online using modern authentication (supports MFA).
2. Exports report to CSV.
3. Removes mailbox forwarding and disables inbox rules that forward emails.
4. Supports processing a single user or multiple users from CSV.
5. Automatically installs EXO V2 module if not already installed.
6. Scheduler-friendly: credentials can be passed as parameters.

Author: Ryan Adams
GitHub - https://github.com/Ryan-Adams57
Gitlab https://gitlab.com/Ryan-Adams57
PasteBin https://pastebin.com/u/Removed_Content
============================================================================================
#>

Param (
    [Parameter(Mandatory = $false)]
    [string]$UserName = $NULL,
    [string]$Password = $NULL,
    [string]$Name = $NULL,
    [string]$CSV = $NULL
)

#--------------------------------------------------------------------------------------------
# Logging helper
#--------------------------------------------------------------------------------------------
function WriteToLogFile($message) {
    $message >> $logfile
}

#--------------------------------------------------------------------------------------------
# Connect to Exchange Online
#--------------------------------------------------------------------------------------------
Function Connect_Exo {
    $Module = Get-Module ExchangeOnlineManagement -ListAvailable
    if ($Module.Count -eq 0) {
        Write-Host "Exchange Online PowerShell V2 module is not available" -ForegroundColor Yellow
        $Confirm = Read-Host "Install module now? [Y] Yes [N] No"
        if ($Confirm -match "[yY]") {
            Write-Host "Installing Exchange Online PowerShell module..."
            Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force
        } else {
            Write-Host "EXO V2 module is required. Exiting." -ForegroundColor Red
            Exit
        }
    }

    Write-Host "Connecting to Exchange Online..."
    if ($UserName -and $Password) {
        $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
        $Credential = New-Object System.Management.Automation.PSCredential $UserName, $SecuredPassword
        Connect-ExchangeOnline -Credential $Credential
    } else {
        Connect-ExchangeOnline
    }
}

#--------------------------------------------------------------------------------------------
# Remove mailbox forwarding
#--------------------------------------------------------------------------------------------
Function GetMailboxForwardingInfoAndRemoveForwarding {
    $MailboxInfo = Get-Mailbox $Name | Where-Object { $_.ForwardingSMTPAddress -ne $null -or $_.ForwardingAddress -ne $null }
    if ($MailboxInfo) {
        $MailboxOwner = $MailboxInfo.Name
        Write-Progress -Activity "Processing mailbox forwarding for $MailboxOwner" -Status " "

        $global:ReportSize1++
        $ForwardingSMTPAddress = $MailboxInfo.ForwardingSMTPAddress -replace ".*:", ""
        $ForwardingSMTPAddress = if ($ForwardingSMTPAddress) { $ForwardingSMTPAddress } else { "-" }
        $ForwardTo = if ($MailboxInfo.ForwardingAddress) { $MailboxInfo.ForwardingAddress } else { "-" }
        $DeliverToMailbox = $MailboxInfo.DeliverToMailboxAndForward

        # Export to CSV
        $ExportResult = [PSCustomObject]@{
            'Mailbox Name'                = $MailboxOwner
            'Forwarding SMTP Address'     = $ForwardingSMTPAddress
            'Forward To'                  = $ForwardTo
            'Deliver To Mailbox and Forward' = $DeliverToMailbox
        }
        $ExportResult | Export-Csv -Path $global:ExportCSVFileName1 -NoTypeInformation -Append -Force

        # Remove forwarding
        Try {
            Set-Mailbox $Name -ForwardingAddress $null -ForwardingSmtpAddress $null -ErrorAction Stop
            WriteToLogFile "Email forwarding removed for $MailboxOwner. ForwardTo: $ForwardTo, ForwardingSMTPAddress: $ForwardingSMTPAddress"
        } Catch {
            WriteToLogFile "Error removing forwarding from $MailboxOwner."
        }
    }
}

#--------------------------------------------------------------------------------------------
# Disable inbox rules with forwarding
#--------------------------------------------------------------------------------------------
Function GetInboxRulesInfoAndDisableForwarding {
    Get-InboxRule -Mailbox $Name | Where-Object {
        $_.ForwardAsAttachmentTo -or $_.ForwardTo -or $_.RedirectTo
    } | ForEach-Object {
        $Rule = $_
        $MailboxOwner = $Rule.MailboxOwnerId
        $RuleName = $Rule.Name
        $Enable = $Rule.Enabled

        $ForwardTo = ($Rule.ForwardTo | ForEach-Object { ($_ -split "\[")[0].Trim('"') }) -join ","
        $ForwardAsAttachment = ($Rule.ForwardAsAttachmentTo | ForEach-Object { ($_ -split "\[")[0].Trim('"') }) -join ","
        $RedirectTo = ($Rule.RedirectTo | ForEach-Object { ($_ -split "\[")[0].Trim('"') }) -join ","

        $global:ReportSize2++
        $ExportResult = [PSCustomObject]@{
            'Mailbox Name'             = $MailboxOwner
            'Inbox Rule'               = $RuleName
            'Forward To'               = $ForwardTo
            'Forward As Attachment To' = $ForwardAsAttachment
            'Redirect To'              = $RedirectTo
        }
        $ExportResult | Export-Csv -Path $global:ExportCSVFileName2 -NoTypeInformation -Append -Force

        # Disable rule
        if ($Enable) {
            Try {
                Disable-InboxRule -Identity $RuleName
                WriteToLogFile "Inbox rule ($RuleName) in $MailboxOwner mailbox disabled."
            } Catch {
                WriteToLogFile "Error disabling inbox rule ($RuleName) in $MailboxOwner."
            }
        }
    }
}

#--------------------------------------------------------------------------------------------
# Main Execution
#--------------------------------------------------------------------------------------------
Connect_Exo

$global:logfile = "RemoveForwardingLogFile_$(Get-Date -Format 'MMM-dd_hh-mm-ss_tt').txt"
$global:ExportCSVFileName1 = "EmailForwardingConfigurationReport_$(Get-Date -Format 'MMM-dd_hh-mm-ss_tt').csv"
$global:ExportCSVFileName2 = "InboxRulesWithForwarding_$(Get-Date -Format 'MMM-dd_hh-mm-ss_tt').csv"
$global:ReportSize1 = 0
$global:ReportSize2 = 0

# Process single user or CSV
if ($Name) {
    GetMailboxForwardingInfoAndRemoveForwarding
    GetInboxRulesInfoAndDisableForwarding
}
elseif ($CSV) {
    Import-Csv $CSV | ForEach-Object {
        $Name = $_.Name
        GetMailboxForwardingInfoAndRemoveForwarding
        GetInboxRulesInfoAndDisableForwarding
    }
}
else {
    $Name = Read-Host "Enter the user name"
    GetMailboxForwardingInfoAndRemoveForwarding
    GetInboxRulesInfoAndDisableForwarding
}

#--------------------------------------------------------------------------------------------
# Output summary and prompt to open files
#--------------------------------------------------------------------------------------------
if (-not ((Test-Path $global:ExportCSVFileName1) -or (Test-Path $global:ExportCSVFileName2))) {
    Write-Host "No email forwarding found for the given user(s)." -ForegroundColor Green
} else {
    Write-Host "`nOutput files generated:" -ForegroundColor Yellow
    Write-Host "$global:ExportCSVFileName1" -ForegroundColor Cyan
    Write-Host "$global:ExportCSVFileName2" -ForegroundColor Cyan
    Write-Host "Log file: $global:logfile" -ForegroundColor Green

    $prompt = New-Object -ComObject wscript.shell
    $userInput = $prompt.popup("Do you want to open output files?", 0, "Open Output File", 4)
    if ($userInput -eq 6) {
        Invoke-Item $global:ExportCSVFileName1
        Invoke-Item $global:ExportCSVFileName2
        Invoke-Item $global:logfile
    }
}

Write-Host "`n~~ Script prepared by Ryan Adams ~~" -ForegroundColor Green
Write-Host "~~ Check out " -NoNewline -ForegroundColor Green; Write-Host "https://www.governmentcontrol.net/" -ForegroundColor Yellow -NoNewline; Write-Host " for more tools and resources. ~~" -ForegroundColor Green
