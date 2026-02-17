<#
=============================================================================================
Name:          Save sent items in Shared Mailbox using PowerShell  
Description:   By default, emails sent from shared mailboxes are saved in the user's Sent Items. This script configures shared mailboxes to save copies of sent emails within their own Sent Items folder.
Version:       1.0
Author:        Ryan Adams
Website:       https://www.governmentcontrol.net/
GitHub:        https://github.com/Ryan-Adams57
GitLab:        https://gitlab.com/Ryan-Adams57
PasteBin:      https://pastebin.com/u/Removed_Content

For details:   https://www.governmentcontrol.net/
============================================================================================
#>

# Check for Exchange Online PowerShell module installation
$Module = Get-Module ExchangeOnlineManagement -ListAvailable
if ($Module.Count -eq 0) {
    Write-Host "Exchange Online PowerShell module is not available." -ForegroundColor Yellow
    $Confirm = Read-Host "Do you want to install the module? [Y] Yes [N] No"
    if ($Confirm -match "[yY]") {
        Write-Host "Installing Exchange Online PowerShell module..."
        Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force -Scope CurrentUser
        Import-Module ExchangeOnlineManagement
    } else {
        Write-Host "EXO module is required to connect to Exchange Online. Please install the module using Install-Module ExchangeOnlineManagement cmdlet."
        Exit
    }
}

Write-Host "Connecting to Exchange Online..."

# Connect using credentials or certificate
if (($UserName -ne "") -and ($Password -ne "")) {
    $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
    $Credential = New-Object System.Management.Automation.PSCredential $UserName, $SecuredPassword
    Connect-ExchangeOnline -Credential $Credential
} elseif ($Organization -ne "" -and $ClientId -ne "" -and $CertificateThumbprint -ne "") {
    Connect-ExchangeOnline -AppId $ClientId -CertificateThumbprint $CertificateThumbprint -Organization $Organization -ShowBanner:$false
} else {
    Connect-ExchangeOnline
}

# Retrieve all shared mailboxes and configure to save copies of sent emails in their own Sent Items
Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails SharedMailbox | ForEach-Object {
    Set-Mailbox -Identity $_.UserPrincipalName -MessageCopyForSendOnBehalfEnabled $true -MessageCopyForSentAsEnabled $true
}
