<#
=============================================================================================
Name:           Export Office 365 Email Forwarding Report using PowerShell 
Description:    This script exports Office 365 email forwarding report to CSV format
Version:        1.0
Website:        https://www.governmentcontrol.net/

Author:
~~~~~~~~~~~
Ryan Adams
GitHub - https://github.com/Ryan-Adams57
Gitlab https://gitlab.com/Ryan-Adams57
PasteBin https://pastebin.com/u/Removed_Content

Highlights:
~~~~~~~~~~~
1. Generates 3 different email forwarding rules reports.
2. Automatically installs the Exchange Online module if not present.
3. Shows mailboxes with forwarding configured via 'Forwarding SMTP Address' or 'Forward To'.
4. Lists all inbox rules that forward email to other mailboxes.
5. Identifies transport rules redirecting emails.
6. Supports both MFA and Non-MFA accounts.
7. Exports reports to CSV.
8. Scheduler-friendly; supports passing credentials as parameters.
============================================================================================
#>

param(
    [string] $UserName = $null,
    [string] $Password = $null,
    [Switch] $InboxRules,
    [Switch] $MailFlowRules
)

Function GetPrintableValue($RawData) {
    if (($null -eq $RawData) -or ($RawData.Equals(""))) { return "-" }
    else { return $RawData | Out-String }
}

Function GetAllMailForwardingRules {
    Write-Host "`nPreparing the Email Forwarding Report..."
    if ($InboxRules.IsPresent) {
        $global:ExportCSVFileName = "InboxRulesWithEmailForwarding_" + ((Get-Date -format "MMM-dd hh-mm-ss tt")) + ".csv"
        Get-Mailbox -ResultSize Unlimited | ForEach-Object {
            Write-Progress "Processing the Inbox Rule for the User: $($_.Id)" " "
            Get-InboxRule -Mailbox $_.PrimarySmtpAddress |
                Where-Object { $_.ForwardAsAttachmentTo -ne $Empty -or $_.ForwardTo -ne $Empty -or $_.RedirectTo -ne $Empty } |
                ForEach-Object { $CurrUserRule = $_; GetInboxRulesInfo }
        }
    }
    elseif ($MailFlowRules.IsPresent) {
        $global:ExportCSVFileName = "TransportRulesWithEmailForwarding_" + ((Get-Date -format "MMM-dd hh-mm-ss tt")) + ".csv"
        Get-TransportRule -ResultSize Unlimited |
            Where-Object { $_.RedirectMessageTo -ne $Empty } |
            ForEach-Object { $CurrEmailFlowRule = $_; Write-Progress -Activity "Processing the Transport Rule: $($_.Name)" " "; GetMailFlowRulesInfo }
    }
    else {
        $global:ExportCSVFileName = "EmailForwardingReport_" + ((Get-Date -format "MMM-dd hh-mm-ss tt")) + ".csv"
        Get-Mailbox -ResultSize Unlimited |
            Where-Object { $_.ForwardingSMTPAddress -ne $Empty -or $_.ForwardingAddress -ne $Empty } |
            ForEach-Object { $CurrEmailSetUp = $_; Write-Progress -Activity "Processing Mailbox Forwarding Rules for the User: $($_.Id)" " "; GetMailboxForwardingInfo }
    }
}

Function GetMailboxForwardingInfo {
    $global:ReportSize++
    $MailboxOwner = $CurrEmailSetUp.PrimarySMTPAddress
    $DeliverToMailbox = $CurrEmailSetUp.DeliverToMailboxandForward

    if ($CurrEmailSetUp.ForwardingSMTPAddress) {
        $CurrEmailSetUp.ForwardingSMTPAddress = GetPrintableValue (($CurrEmailSetUp.ForwardingSMTPAddress).split(":")[1])
    }
    $ForwardingSMTPAddress = GetPrintableValue $CurrEmailSetUp.ForwardingSMTPAddress

    if ($CurrEmailSetUp.ForwardingAddress) {
        $CurrEmailSetUp.ForwardingAddress = GetPrintableValue ($CurrEmailSetUp.ForwardingAddress)
    }
    $ForwardTo = GetPrintableValue $CurrEmailSetUp.ForwardingAddress

    $ExportResult = @{
        'Mailbox Name' = $MailboxOwner
        'Forwarding SMTP Address' = $ForwardingSMTPAddress
        'Forward To' = $ForwardTo
        'Deliver To Mailbox and Forward' = $DeliverToMailbox
    }
    New-Object PSObject -Property $ExportResult |
        Select-Object 'Mailbox Name', 'Forwarding SMTP Address', 'Forward To', 'Deliver To Mailbox and Forward' |
        Export-Csv -Path $global:ExportCSVFileName -NoType -Append -Force
}

Function GetInboxRulesInfo {
    $global:ReportSize++
    $MailboxOwner = $CurrUserRule.MailboxOwnerId
    $RuleName = $CurrUserRule.Name
    $Enable = $CurrUserRule.Enabled
    $StopProcessingRules = $CurrUserRule.StopProcessingRules

    if ($CurrUserRule.RedirectTo) {
        $CurrUserRule.RedirectTo = GetPrintableValue (($CurrUserRule.RedirectTo).split("[")[0]).Replace('"','').Trim()
    }
    $RedirectTo = GetPrintableValue $CurrUserRule.RedirectTo

    if ($CurrUserRule.ForwardAsAttachmentTo) {
        $CurrUserRule.ForwardAsAttachmentTo = GetPrintableValue (($CurrUserRule.ForwardAsAttachmentTo).split("[")[0]).Replace('"','').Trim()
    }
    $ForwardAsAttachment = GetPrintableValue $CurrUserRule.ForwardAsAttachmentTo

    if ($CurrUserRule.ForwardTo) {
        $CurrUserRule.ForwardTo = GetPrintableValue (($CurrUserRule.ForwardTo).split("[")[0]).Replace('"','').Trim()
    }
    $ForwardTo = GetPrintableValue $CurrUserRule.ForwardTo

    $ExportResult = @{
        'Mailbox Name' = $MailboxOwner
        'Inbox Rule' = $RuleName
        'Rule Status' = $Enable
        'Forward As Attachment To' = $ForwardAsAttachment
        'Forward To' = $ForwardTo
        'Stop Processing Rules' = $StopProcessingRules
        'Redirect To' = $RedirectTo
    }
    New-Object PSObject -Property $ExportResult |
        Select-Object 'Mailbox Name', 'Inbox Rule', 'Forward To', 'Redirect To', 'Forward As Attachment To', 'Stop Processing Rules', 'Rule Status' |
        Export-Csv -Path $global:ExportCSVFileName -NoType -Append -Force
}

Function GetMailFlowRulesInfo {
    $global:ReportSize++
    $RuleName = $CurrEmailFlowRule.Name
    $State = $CurrEmailFlowRule.State
    $Mode = $CurrEmailFlowRule.Mode
    $Priority = $CurrEmailFlowRule.Priority
    $StopProcessingRules = $CurrEmailFlowRule.StopRuleProcessing

    if ($CurrEmailFlowRule.RedirectMessageTo) {
        $CurrEmailFlowRule.RedirectMessageTo = GetPrintableValue ($CurrEmailFlowRule.RedirectMessageTo).Replace('{}','').Trim()
    }
    $RedirectTo = $CurrEmailFlowRule.RedirectMessageTo

    $ExportResult = @{
        'Mail Flow Rule Name' = $RuleName
        'State' = $State
        'Mode' = $Mode
        'Priority' = $Priority
        'Redirect To' = $RedirectTo
        'Stop Processing Rule' = $StopProcessingRules
    }
    New-Object PSObject -Property $ExportResult |
        Select-Object 'Mail Flow Rule Name','Redirect To', 'Stop Processing Rule','State', 'Mode', 'Priority' |
        Export-Csv -Path $global:ExportCSVFileName -NoType -Append -Force
}

Function ConnectToExchange {
    if (-not (Get-Module ExchangeOnlineManagement -ListAvailable)) {
        Write-Host "ExchangeOnline module not found." -ForegroundColor Yellow
        $confirm = Read-Host "Install ExchangeOnlineManagement module? [Y] Yes [N] No"
        if ($confirm -match "[yY]") { Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force }
        else { Write-Host "ExchangeOnline module required. Exiting." -ForegroundColor Red; Exit }
    }

    if ($UserName -and $Password) {
        $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
        $Credential = New-Object System.Management.Automation.PSCredential $UserName, $SecuredPassword
        Connect-ExchangeOnline -Credential $Credential -ShowProgress:$false | Out-Null
    }
    else { Connect-ExchangeOnline | Out-Null }

    Write-Host "ExchangeOnline connected successfully." -ForegroundColor Cyan
}

# --------------------------------------------
# Execution
# --------------------------------------------
ConnectToExchange
$global:ReportSize = 0
GetAllMailForwardingRules
Write-Progress -Activity "--" -Completed

if (Test-Path $global:ExportCSVFileName) {
    Write-Host "`nThe output file is available at:" -NoNewline -ForegroundColor Yellow
    Write-Host ".\$global:ExportCSVFileName`n"
    Write-Host "The exported report has $global:ReportSize email forwarding configurations"
    $prompt = New-Object -ComObject wscript.shell
    $userInput = $prompt.popup("Do you want to open output file?", 0, "Open Output File", 4)
    if ($userInput -eq 6) { Invoke-Item "$global:ExportCSVFileName" }
}
else {
    Write-Host "No data found with the specified criteria" -ForegroundColor Red
}

Disconnect-ExchangeOnline -Confirm:$false -InformationAction Ignore -ErrorAction SilentlyContinue
Write-Host "`nDisconnected active ExchangeOnline session"
Write-Host "`n~~ Script prepared by Ryan Adams ~~" -ForegroundColor Green
Write-Host "~~ Check out " -NoNewline -ForegroundColor Green; Write-Host "https://www.governmentcontrol.net/" -ForegroundColor Yellow -NoNewline; Write-Host " for auditing resources. ~~" -ForegroundColor Green
