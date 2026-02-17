<#
=============================================================================================
Name:           Exchange Online Shared Mailbox Inventory Report
Version:        1.0
Website:        https://www.governmentcontrol.net/

Author:         Ryan Adams
GitHub:         https://github.com/Ryan-Adams57
GitLab:         https://gitlab.com/Ryan-Adams57
PasteBin:       https://pastebin.com/u/Removed_Content

Script Highlights: 
~~~~~~~~~~~~~~~~~
1. The script uses modern authentication to connect to Exchange Online.    
2. The script can be executed with an MFA-enabled account too.    
3. Exports report results to CSV file.    
4. Helps identify shared mailboxes with licenses separately.  
5. Helps track email forwarding configured shared mailboxes. 
6. Automatically installs the EXO V2 module (if not installed already) upon your confirmation.   
7. The script is scheduler-friendly. Credentials can be passed as a parameter instead of getting interactively.

For detailed script execution: https://www.governmentcontrol.net/
============================================================================================
#>

Param
(
    [Parameter(Mandatory = $false)]
    [switch]$LicensedOnly,
    [switch]$EmailForwardingEnabled,
    [switch]$FullAccessOnly,
    [string]$UserName,
    [string]$Password
)

Function Connect_Exo
{
 $Module = Get-Module ExchangeOnlineManagement -ListAvailable
 if($Module.count -eq 0) 
 { 
  Write-Host "Exchange Online PowerShell V2 module is not available" -ForegroundColor Yellow  
  $Confirm= Read-Host "Are you sure you want to install module? [Y] Yes [N] No" 
  if($Confirm -match "[yY]") 
  { 
   Write-Host "Installing Exchange Online PowerShell module"
   Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force
   Import-Module ExchangeOnlineManagement
  } 
  else 
  { 
   Write-Host "EXO V2 module is required to connect Exchange Online. Please install module using Install-Module ExchangeOnlineManagement cmdlet." 
   Exit
  }
 } 

 Write-Host "Connecting to Exchange Online..."

 if(($UserName -ne "") -and ($Password -ne ""))
 {
  $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
  $Credential  = New-Object System.Management.Automation.PSCredential $UserName,$SecuredPassword
  Connect-ExchangeOnline -Credential $Credential
 }
 else
 {
  Connect-ExchangeOnline
 }
}

Connect_Exo

$OutputCSV=".\SharedMailboxReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv" 
$Count=0
$OutputCount=0

Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails SharedMailbox | ForEach-Object {

 $Print=$true
 $Count++
 $Name=$_.Name
 Write-Progress -Activity "Processing $Name.." -Status "Processed mailbox count: $Count"

 $PrimarySMTPAddress=$_.PrimarySMTPAddress
 $UPN=$_.UserPrincipalName
 $Alias=$_.Alias
 $ArchiveStatus=$_.ArchiveStatus
 $LitigationHold=$_.LitigationHoldEnabled
 $RetentionHold=$_.RetentionHoldEnabled
 $IsLicensed=$_.SkuAssigned
 $AuditEnabled=$_.AuditEnabled
 $HideFromAddressList=$_.HiddenFromAddressListsEnabled
 $ForwardingAddress=$_.ForwardingAddress
 $ForwardingSMTPAddress=$_.ForwardingSMTPAddress

 if($ForwardingAddress -eq $null) { $ForwardingAddress="-" }
 if($ForwardingSMTPAddress -eq $null) { $ForwardingSMTPAddress="-" }

 $MBSize=((Get-MailboxStatistics -Identity $UPN).TotalItemSize.Value)
 $MailboxSize=$MBSize.ToString().Split("(") | Select-Object -Index 0

 If(($LicensedOnly.IsPresent) -and ($IsLicensed -eq $false))
 {
  $Print=$false
 }

 if(($EmailForwardingEnabled.IsPresent) -and (($ForwardingAddress -eq "-") -and ($ForwardingSMTPAddress -eq "-")))
 {
  $Print=$false
 }

 if($Print -eq $true)
 {
  $OutputCount++
  $ExportResult=@{
   'Name'=$Name
   'Primary SMTP Address'=$PrimarySMTPAddress
   'Alias'=$Alias
   'MB Size'=$MailboxSize
   'Is Licensed'=$IsLicensed
   'Archive Status'=$ArchiveStatus
   'Hide From Address List'=$HideFromAddressList
   'Audit Enabled'=$AuditEnabled
   'Forwarding Address'=$ForwardingAddress
   'Forwarding SMTP Address'=$ForwardingSMTPAddress
   'Litigation Hold'=$LitigationHold
   'Retention Hold'=$RetentionHold
  }

  $ExportObject= New-Object PSObject -Property $ExportResult  
  $ExportObject | Select-Object 'Name','Primary SMTP Address','Alias','MB Size','Is Licensed','Archive Status','Hide From Address List','Audit Enabled','Forwarding Address','Forwarding SMTP Address','Litigation Hold','Retention Hold' | Export-Csv -Path $OutputCSV -NoTypeInformation -Append 
 }
}
 
If($OutputCount -eq 0)
{
 Write-Host "No records found"
}
else
{
 Write-Host "`nThe output file contains $OutputCount shared mailboxes."
 if((Test-Path -Path $OutputCSV) -eq "True") 
 {
  Write-Host "`nThe Output file available in:" -NoNewline -ForegroundColor Yellow
  Write-Host "$OutputCSV"`n 
  $Prompt = New-Object -ComObject wscript.shell   
  $UserInput = $Prompt.popup("Do you want to open output file?",0,"Open Output File",4)   
  If ($UserInput -eq 6)   
  {   
   Invoke-Item "$OutputCSV"   
  }

  Write-Host "`n~~ Script maintained by Ryan Adams ~~`n" -ForegroundColor Green
 }
}

Disconnect-ExchangeOnline -Confirm:$false -InformationAction Ignore -ErrorAction SilentlyContinue
