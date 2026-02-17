<#
=============================================================================================
Name:           Exchange Online Mailbox Storage Audit Report
Description:    This script exports Microsoft 365 mailbox size report to CSV
Version:        3.0
Website:        https://www.governmentcontrol.net/
Author:         Ryan Adams
GitHub:         https://github.com/Ryan-Adams57
GitLab:         https://gitlab.com/Ryan-Adams57
PasteBin:       https://pastebin.com/u/Removed_Content

Script Highlights: 
~~~~~~~~~~~~~~~~~
1.Exports mailbox size report for all mailboxes.
2.Retrieves mailbox size for list of mailboxes (import CSV)
3.Allows to use filter to get user mailboxes’ size alone.
4.Allows to use filter to get shared mailboxes’ size alone.
5.Automatically installs the EXO PowerShell module (if not installed already) upon your confirmation.
6.The script can be executed with MFA enabled account too.
7.Exports report results to CSV.
8.The script is scheduler friendly.
9.Supports certificate-based authentication (CBA) too.

============================================================================================
#>
Param
(
    [Parameter(Mandatory = $false)]
    [switch]$SharedMBOnly,
    [switch]$UserMBOnly,
    [string]$MBNamesFile,
    [string]$UserName,
    [string]$Password,
    [string]$Organization,
    [string]$ClientId,
    [string]$CertificateThumbprint
)

Function Get_MailboxSize
{
 $Stats=Get-MailboxStatistics -Identity $UPN
 $ItemCount=$Stats.ItemCount
 $TotalItemSize=$Stats.TotalItemSize
 $TotalItemSizeinBytes= $TotalItemSize –replace “(.*\()|,| [a-z]*\)”, “”
 $TotalSize=$stats.TotalItemSize.value -replace "\(.*",""
 $DeletedItemCount=$Stats.DeletedItemCount
 $TotalDeletedItemSize=$Stats.TotalDeletedItemSize

 #Export result to csv
 $Result=@{'Display Name'=$DisplayName;'User Principal Name'=$upn;'Mailbox Type'=$MailboxType;'Primary SMTP Address'=$PrimarySMTPAddress;'Archive Status'=$Archivestatus;'Item Count'=$ItemCount;'Total Size'=$TotalSize;'Total Size (Bytes)'=$TotalItemSizeinBytes;'Deleted Item Count'=$DeletedItemCount;'Deleted Item Size'=$TotalDeletedItemSize;'Issue Warning Quota'=$IssueWarningQuota;'Prohibit Send Quota'=$ProhibitSendQuota;'Prohibit send Receive Quota'=$ProhibitSendReceiveQuota}
 $Results= New-Object PSObject -Property $Result  
 $Results | Select-Object 'Display Name','User Principal Name','Mailbox Type','Primary SMTP Address','Item Count','Total Size','Total Size (Bytes)','Archive Status','Deleted Item Count','Deleted Item Size','Issue Warning Quota','Prohibit Send Quota','Prohibit Send Receive Quota' | Export-Csv -Path $ExportCSV -Notype -Append 
}

Function main()
{
 #Check for EXO module installation
 $Module = Get-Module ExchangeOnlineManagement -ListAvailable
 if($Module.count -eq 0) 
 { 
  Write-Host Exchange Online PowerShell module is not available  -ForegroundColor yellow  
  $Confirm= Read-Host Are you sure you want to install module? [Y] Yes [N] No 
  if($Confirm -match "[yY]") 
  { 
   Write-host "Installing Exchange Online PowerShell module"
   Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force -Scope CurrentUser
   Import-Module ExchangeOnlineManagement
  } 
  else 
  { 
   Write-Host EXO module is required to connect Exchange Online. Please install module using Install-Module ExchangeOnlineManagement cmdlet. 
   Exit
  }
 } 
 Write-Host Connecting to Exchange Online...
 
 #Storing credential in script for scheduling purpose / Passing credential as parameter - Authentication using non-MFA account
 if(($UserName -ne "") -and ($Password -ne ""))
 {
  $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
  $Credential  = New-Object System.Management.Automation.PSCredential $UserName,$SecuredPassword
  Connect-ExchangeOnline -Credential $Credential
 }
 elseif($Organization -ne "" -and $ClientId -ne "" -and $CertificateThumbprint -ne "")
 {
   Connect-ExchangeOnline -AppId $ClientId -CertificateThumbprint $CertificateThumbprint  -Organization $Organization -ShowBanner:$false
 }
 else
 {
  Connect-ExchangeOnline -ShowBanner:$false
 }

 #Output file declaration 
 $ExportCSV=".\MailboxSizeReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv" 

 $Result=""   
 $Results=@()  
 $MBCount=0
 $PrintedMBCount=0
 Write-Host Generating mailbox size report...
 
 #Check for input file
 if([string]$MBNamesFile -ne "") 
 { 
  #We have an input file, read it into memory 
  $Mailboxes=@()
  $Mailboxes=Import-Csv -Header "MBIdentity" $MBNamesFile
  foreach($item in $Mailboxes)
  {
   $MBDetails=Get-Mailbox -Identity $item.MBIdentity
   $UPN=$MBDetails.UserPrincipalName  
   $MailboxType=$MBDetails.RecipientTypeDetails
   $DisplayName=$MBDetails.DisplayName
   $PrimarySMTPAddress=$MBDetails.PrimarySMTPAddress
   $IssueWarningQuota=$MBDetails.IssueWarningQuota -replace "\(.*",""
   $ProhibitSendQuota=$MBDetails.ProhibitSendQuota -replace "\(.*",""
   $ProhibitSendReceiveQuota=$MBDetails.ProhibitSendReceiveQuota -replace "\(.*",""
   #Check for archive enabled mailbox
   if(($MBDetails.ArchiveDatabase -eq $null) -and ($MBDetails.ArchiveDatabaseGuid -eq $MBDetails.ArchiveGuid))
   {
    $ArchiveStatus = "Disabled"
   }
   else
   {
    $ArchiveStatus= "Active"
   }
   $MBCount++
   Write-Progress -Activity "`n     Processed mailbox count: $MBCount "`n"  Currently Processing: $DisplayName"
   Get_MailboxSize
   $PrintedMBCount++
  }
 }

 #Get all mailboxes
 else
 {
  Get-Mailbox -ResultSize Unlimited | foreach {
   $UPN=$_.UserPrincipalName
   $Mailboxtype=$_.RecipientTypeDetails
   $DisplayName=$_.DisplayName
   $PrimarySMTPAddress=$_.PrimarySMTPAddress
   $IssueWarningQuota=$_.IssueWarningQuota -replace "\(.*",""
   $ProhibitSendQuota=$_.ProhibitSendQuota -replace "\(.*",""
   $ProhibitSendReceiveQuota=$_.ProhibitSendReceiveQuota -replace "\(.*",""
   $MBCount++
   Write-Progress -Activity "`n     Processed mailbox count: $MBCount "`n"  Currently Processing: $DisplayName"
   if($SharedMBOnly.IsPresent -and ($Mailboxtype -ne "SharedMailbox"))
   {
    return
   }
   if($UserMBOnly.IsPresent -and ($MailboxType -ne "UserMailbox"))
   {
    return
   }  
   #Check for archive enabled mailbox
   if(($_.ArchiveDatabase -eq $null) -and ($_.ArchiveDatabaseGuid -eq $_.ArchiveGuid))
   {
    $ArchiveStatus = "Disabled"
   }
   else
   {
    $ArchiveStatus= "Active"
   }
   Get_MailboxSize
   $PrintedMBCount++
  }
 }

 #Open output file after execution 
 If($PrintedMBCount -eq 0)
 {
  Write-Host No mailbox found
 }
 else
 {
  Write-Host `nThe output file contains $PrintedMBCount mailboxes.
  if((Test-Path -Path $ExportCSV) -eq "True") 
  {
   Write-Host `n The Output file available in: -NoNewline -ForegroundColor Yellow
   Write-Host $ExportCSV 
   $Prompt = New-Object -ComObject wscript.shell      
   $UserInput = $Prompt.popup("Do you want to open output file?",0,"Open Output File",4)   
   If ($UserInput -eq 6)   
   {   
    Invoke-Item "$ExportCSV"   
   } 
  }
 }

 #Disconnect Exchange Online session
 Disconnect-ExchangeOnline -Confirm:$false | Out-Null
 Write-Host `n~~ Script prepared by Ryan Adams ~~`n -ForegroundColor Green
 Write-Host "~~ Visit https://www.governmentcontrol.net/ for more Microsoft 365 automation resources. ~~" -ForegroundColor Green `n`n
 
}
. main
