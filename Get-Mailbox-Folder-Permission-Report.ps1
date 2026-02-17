<#
=============================================================================================
Name: Get Mailbox Folder Permission Report Using PowerShell
Version: 1.0
Website: https://www.governmentcontrol.net/

~~~~~~~~~~~~~~~~~
Script Highlights: 
~~~~~~~~~~~~~~~~~
1. The script automatically installs the Exchange PowerShell module (if not installed already) upon your confirmation. 
2. The script can generate 7+ folder permission reports. 
3. Retrieves all mailbox folders and their permissions for all mailboxes. 
4. Shows permission for a specific folder in all mailboxes. 
5. Get a list of mailbox folders a user has access to. 
6. Retrieves all mailbox folders delegated with specific access rights. 
7. Provides option to exclude default and anonymous access. 
8. Allows to get folder permissions for all user mailboxes. 
9. Allows to get folder permissions for all shared mailboxes. 
10. Exports report results to CSV. 
11. The script is scheduler friendly. 
12. It can be executed with certificate-based authentication (CBA) too.

For detailed script execution: https://pastebin.com/u/Removed_Content
============================================================================================
#>   
Param (
   [Parameter(Mandatory = $false)]
        [string]$ClientId,
        [string]$Organization,
        [string]$CertificateThumbprint,
        [string]$UserName,
        [string]$Password,
        [string]$MailboxUPN ,
        [string]$MailboxCSV  ,
        [string]$SpecificFolder ,
        [string]$FoldersUserCanAccess,
        [ValidateSet("None","Reviewer","PublishingEditor","PublishingAuthor","Owner","NonEditingAuthor","Editor","Contributor","Author")]
        [array]$AccessRights,
        [switch]$ExcludeDefaultAndAnonymousUsers,
        [switch]$UserMailboxOnly ,
        [switch]$SharedMailboxOnly
)

#Check for EXO module installation
$Module = Get-Module ExchangeOnlineManagement -ListAvailable
if($Module.count -eq 0) 
{ 
    Write-Host "Exchange Online PowerShell module is not available" -ForegroundColor yellow  
    $Confirm = Read-Host "Are you sure you want to install module? [Y] Yes [N] No" 
    if($Confirm -match "[yY]") 
    { 
        Write-host "Installing Exchange Online PowerShell module"
        Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force -Scope CurrentUser
    } 
    else 
    { 
        Write-Host "EXO module is required to connect Exchange Online. Please install module using Install-Module ExchangeOnlineManagement cmdlet." 
        Exit
    }
} 
Write-Host "Connecting to Exchange Online..."
if(($UserName -ne "") -and ($Password -ne ""))
{
    $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
    $Credential = New-Object System.Management.Automation.PSCredential $UserName,$SecuredPassword
    Connect-ExchangeOnline -Credential $Credential -ShowBanner:$false
}
elseif($Organization -ne "" -and $ClientId -ne "" -and $CertificateThumbprint -ne "")
{
    Connect-ExchangeOnline -AppId $ClientId -CertificateThumbprint $CertificateThumbprint -Organization $Organization -ShowBanner:$false
}
else
{
    Connect-ExchangeOnline -ShowBanner:$false
}

# Output file declaration 
$Location = (Get-Location) 
$OutputCSV = "$($Location)\MailboxFolderPermissionReport_$((Get-Date -format 'yyyy-MMM-dd-ddd hh-mm-ss').ToString()).csv"

# Function to export csv in mailbox folder permissions
Function GetPermission {
    param($MailboxUPN, $FolderPermissions)

    foreach ($Permission in $FolderPermissions) {
        $MailboxFolderPermissionsData = [PSCustomObject]@{
            "Display Name" = $DisplayName
            "UPN" = $MailboxUPN
            "Mailbox Type" = $MailboxType
            "Folder Name" = $Permission.FolderName
            "Folder Identity" = $Permission.Identity
            "Shared To" = $Permission.User
            "Access Rights" = $Permission.AccessRights.Trim('{', '}')
        }  
        $MailboxFolderPermissionsData | Export-Csv -Path "$OutputCSV" -Append -NoTypeInformation -Force
    }
}

# Function to get mailbox folder names
Function FolderStatistics{  
    param($MailboxUPN)
    
    Get-EXOMailboxFolderStatistics -Identity $MailboxUPN | ForEach {  
        $FolderIdentity = $_.Identity
        $FolderName = $FolderIdentity.Substring($FolderIdentity.IndexOf('\')+1)
        
        if ($FolderName -like "Top of Information Store") {
            $FolderName = ""
        } 
        elseif ($FolderName -in "Recoverable Items", "Audits", "Calendar Logging", "Deletions", "Purges", "Versions", "SubstrateHolds", "DiscoveryHolds") {
            return 
        }
        if ($ExcludeDefaultAndAnonymousUsers.IsPresent) {
            ProcessExcludeDefaultAndAnonymousUsers -MailboxUPN $MailboxUPN -FolderName $FolderName
        }
        elseif ($FoldersUserCanAccess -ne "") {
            ProcessFoldersUserCanAccess -MailboxUPN $MailboxUPN -FolderName $FolderName -User $FoldersUserCanAccess
        }
        elseif ($AccessRights.Count -gt 0) {
            ProcessToFilterFolderPermissionsByAccessRights -MailboxUPN $MailboxUPN -AccessRights $AccessRights -FolderName $FolderName
        }
        else {
            ProcessAllMailboxFolderPermission -MailboxUPN $MailboxUPN -FolderName $FolderName
        }
    }
}

# Function to permission for all mailbox folders
Function ProcessAllMailboxFolderPermission {
    param($MailboxUPN, $FolderName)
    $FolderPermissions = Get-EXOMailboxFolderPermission -Identity "${MailboxUPN}:\${FolderName}"
    GetPermission -MailboxUPN $MailboxUPN -FolderPermissions $FolderPermissions
}

# Function to mailbox permissions for particular folders
Function ProcessSpecificMailboxFolderPermission {
    param($MailboxUPN, $FolderName)
    $FolderPermissions = Get-EXOMailboxFolderPermission -Identity "${MailboxUPN}:\${FolderName}"
    if($FolderPermissions) {
        GetPermission -MailboxUPN $MailboxUPN -FolderPermissions $FolderPermissions
    } 
    else {
        Write-Host "Failed to retrieve specific folder statistics for mailbox: $MailboxUPN in $SpecificFolder" -ForegroundColor Yellow
    }  
}

# Function to mailbox folders user permission 
Function ProcessExcludeDefaultAndAnonymousUsers{
    param($MailboxUPN, $FolderName)
    $FolderPermissions = Get-EXOMailboxFolderPermission -Identity "${MailboxUPN}:\${FolderName}" | Where-Object { $_.User -notin @("Default", "Anonymous") }
    GetPermission -MailboxUPN $MailboxUPN -FolderPermissions $FolderPermissions
}

# Function to identify the particular user in the mailbox folders permission          
Function ProcessFoldersUserCanAccess{
    param($MailboxUPN, $FolderName, $User)        
    $FolderPermissions = Get-EXOMailboxFolderPermission -Identity "${MailboxUPN}:\${FolderName}" -User $User -ErrorAction SilentlyContinue
    GetPermission -MailboxUPN $MailboxUPN -FolderPermissions $FolderPermissions
}

# Function to retrieve permissions for all folders with a specific access right
Function ProcessToFilterFolderPermissionsByAccessRights {
    param($MailboxUPN, $AccessRights, $FolderName)
    $FolderPermissions = Get-MailboxFolderPermission -Identity "${MailboxUPN}:\${FolderName}" | Where-Object { $_.AccessRights -in $AccessRights }
    if($FolderPermissions) {
        GetPermission -MailboxUPN $MailboxUPN -FolderPermissions $FolderPermissions
    }
}

# Function to get mailbox
Function Getmailbox{
    param($MailboxUPN)
    $MailBoxInfo = Get-EXOMailbox -UserPrincipalName $MailboxUPN
    $DisplayName = $MailBoxInfo.DisplayName
    $MailboxType = $MailBoxInfo.RecipientTypeDetails
    Process-Mailbox -MailboxUPN $MailboxUPN
}

Function Process-Mailbox {
    param($MailboxUPN)
    Write-Progress -Activity "Processed Mailbox Count : $ProgressIndex" -Status "Currently Processing : $MailboxUPN"
    if ($SpecificFolder -ne "") {
        ProcessSpecificMailboxFolderPermission -MailboxUPN $MailboxUPN -FolderName $SpecificFolder
    }
    else {
        FolderStatistics -MailboxUPN $MailboxUPN
    }
}

# Single mailboxUPN
if ($MailboxUPN) {
    $ProgressIndex = 1
    Getmailbox -MailboxUPN $MailboxUPN     
}

# CSV file input
elseif($MailBoxCSV) {
    $Mailboxes = Import-Csv -Path $MailBoxCSV
    $ProgressIndex = 0
    foreach ($Mailbox in $Mailboxes) {
        $ProgressIndex++
        Getmailbox -MailboxUPN $Mailbox.Mailboxes
    }
}

else { 
    $ProgressIndex = 0
    if ($SharedMailboxOnly.IsPresent -or $UserMailboxOnly.IsPresent) {
        if ($SharedMailboxOnly.IsPresent) {
            $RecipientType = "SharedMailbox"
        }
        else {
            $RecipientType = "UserMailbox"
        }
        Get-EXOMailbox -RecipientTypeDetails $RecipientType -
