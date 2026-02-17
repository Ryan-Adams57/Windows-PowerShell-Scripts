<#
=============================================================================================
Name:           Get Shared Mailbox Permission Report 
Version:        2.0
Website:        governmentcontrol.net

Script Highlights: 
~~~~~~~~~~~~~~~~~~

1. Displays only explicitly assigned permissions to mailboxes (ignores SELF and inherited permissions). 
2. Exports output to CSV file. 
3. Supports MFA-enabled accounts. 
4. Allows exporting permissions for all mailboxes or specific mailboxes from an input file. 
5. Filter output by permission type: Send-as, Send-on-behalf, or Full access. 
6. Scheduler friendly — credentials can be passed as a parameter instead of saving inside the script. 

For detailed script execution:  https://www.governmentcontrol.net/
============================================================================================
#>

#Accept input paramenters
param(
[switch]$FullAccess,
[switch]$SendAs,
[switch]$SendOnBehalf,
[string]$MBNamesFile,
[string]$UserName,
[string]$Password
)


function Print_Output
{
 #Print Output
 if($Print -eq 1)
 {
  $Result = @{'Display Name'=$_.Displayname;'User PrinciPal Name'=$upn;'Primary SMTP Address'=$PrimarySMTPAddress;'Access Type'=$AccessType;'User With Access'=$userwithAccess;'Email Aliases'=$EmailAlias}
  $Results = New-Object PSObject -Property $Result
  $Results |select-object 'Display Name','User PrinciPal Name','Primary SMTP Address','Access Type','User With Access','Email Aliases' | Export-Csv -Path $ExportCSV -Notype -Append
 }
}

#Getting Mailbox permission
function Get_MBPermission
{
 $upn=$_.UserPrincipalName
 $DisplayName=$_.Displayname
 $MBType=$_.RecipientTypeDetails
 $PrimarySMTPAddress=$_.PrimarySMTPAddress
 $EmailAddresses=$_.EmailAddresses
 $EmailAlias=""
 foreach($EmailAddress in $EmailAddresses)
 {
  if($EmailAddress -clike "smtp:*")
  {
   if($EmailAlias -ne "")
   {
    $EmailAlias=$EmailAlias+","
   }
   $EmailAlias=$EmailAlias+($EmailAddress -Split ":" | Select-Object -Last 1 )
  }
 }
 $Print=0
 Write-Progress -Activity "`n     Processed mailbox count: $SharedMBCount "`n"  Currently Processing: $DisplayName"

 #Getting delegated Fullaccess permission for mailbox
 if(($FilterPresent -ne $true) -or ($FullAccess.IsPresent))
 {
  $FullAccessPermissions=(Get-MailboxPermission -Identity $upn | where { ($_.AccessRights -contains "FullAccess") -and ($_.IsInherited -eq $false) -and -not ($_.User -match "NT AUTHORITY" -or $_.User -match "S-1-5-21") }).User
  if([string]$FullAccessPermissions -ne "")
  {
   $Print=1
   $UserWithAccess=""
   $AccessType="FullAccess"
   foreach($FullAccessPermission in $FullAccessPermissions)
   {
    if($UserWithAccess -ne "")
    {
     $UserWithAccess=$UserWithAccess+","
    }
    $UserWithAccess=$UserWithAccess+$FullAccessPermission
   }
   Print_Output
  }
 }

 #Getting delegated SendAs permission for mailbox
 if(($FilterPresent -ne $true) -or ($SendAs.IsPresent))
 {
  $SendAsPermissions=(Get-RecipientPermission -Identity $upn | where{ -not (($_.Trustee -match "NT AUTHORITY") -or ($_.Trustee -match "S-1-5-21"))}).Trustee
  if([string]$SendAsPermissions -ne "")
  {
   $Print=1
   $UserWithAccess=""
   $AccessType="SendAs"
   foreach($SendAsPermission in $SendAsPermissions)
   {
    if($UserWithAccess -ne "")
    {
     $UserWithAccess=$UserWithAccess+","
    }
    $UserWithAccess=$UserWithAccess+$SendAsPermission
   }
   Print_Output
  }
 }

 #Getting delegated SendOnBehalf permission for mailbox
 if(($FilterPresent -ne $true) -or ($SendOnBehalf.IsPresent))
 {
  $SendOnBehalfPermissions=$_.GrantSendOnBehalfTo
  if([string]$SendOnBehalfPermissions -ne "")
  {
   $Print=1
   $UserWithAccess=""
   $AccessType="SendOnBehalf"
   foreach($SendOnBehalfPermissionDN in $SendOnBehalfPermissions)
   {
    if($UserWithAccess -ne "")
    {
     $UserWithAccess=$UserWithAccess+","
    }
    $UserWithAccess=$UserWithAccess+$SendOnBehalfPermissionDN
   }
   Print_Output
  }
 }
}

function main{
  #Check for Exchange Online management module inatallation
 $Module = Get-Module ExchangeOnlineManagement -ListAvailable
 if($Module.count -eq 0) 
 { 
  Write-Host Exchange Online PowerShell V2 module is not available  -ForegroundColor yellow  
  $Confirm= Read-Host Are you sure you want to install module? [Y] Yes [N] No 
  if($Confirm -match "[yY]") 
  { 
   Write-host "Installing Exchange Online PowerShell module"
   Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force
   Import-Module ExchangeOnlineManagement
  } 
  else 
  { 
   Write-Host EXO V2 module is required to connect Exchange Online.Please install module using Install-Module ExchangeOnlineManagement cmdlet. 
   Exit
  }
 } 
 Write-Host Connecting to Exchange Online...
 #Storing credential in script for scheduling purpose/ Passing credential as parameter - Authentication using non-MFA account
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

 #Set output file
 $ExportCSV=".\SharedMBPermissionReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"
 $Result=""
 $Results=@()
 $SharedMBCount=0
 $RolesAssigned=""

 #Check for AccessType filter
 if(($FullAccess.IsPresent) -or ($SendAs.IsPresent) -or ($SendOnBehalf.IsPresent))
 {
  $FilterPresent=$true
 }

 #Check for input file
 if ($MBNamesFile -ne "")
 {
  #We have an input file, read it into memory
  $MBs=@()
  $MBs=Import-Csv -Header "DisplayName" $MBNamesFile
  foreach($item in $MBs)
  {
   Get-Mailbox -Identity $item.displayname | Foreach{
   if($_.RecipientTypeDetails -ne 'SharedMailbox')
   {
     Write-Host $_.UserPrincipalName is not a shared mailbox -ForegroundColor Red
     continue
   }
   $SharedMBCount++
   Get_MBPermission
   }
  }
 }
 #Getting all Shared mailbox
 else
 {
  Get-mailbox -RecipientTypeDetails SharedMailbox -ResultSize Unlimited | foreach{ 
   $SharedMBCount++
   Get_MBPermission}
 }


 #Open output file after execution
 Write-Host `nScript executed successfully
 if((Test-Path -Path $ExportCSV) -eq "True")
 {
  Write-Host ""
  Write-Host " Detailed report available in:" -NoNewline -ForegroundColor Yellow
  Write-Host $ExportCSV
  Write-Host `n~~ Script prepared by Ryan Adams ~~`n -ForegroundColor Green 
Write-Host "~~ Check out " -NoNewline -ForegroundColor Green; Write-Host "https://www.governmentcontrol.net/" -ForegroundColor Yellow -NoNewline; Write-Host " for additional reports and tools. ~~" -ForegroundColor Green `n`n 
  $Prompt = New-Object -ComObject wscript.shell
  $UserInput = $Prompt.popup("Do you want to open output file?",`
 0,"Open Output File",4)
  If ($UserInput -eq 6)
  {
   Invoke-Item "$ExportCSV"
  }
 }
 Else
 {
  Write-Host No shared mailbox found that matches your criteria.
 }
#Clean up session
Get-PSSession | Remove-PSSession
}
 . main
