<#
=============================================================================================
Name:           Get Shared Mailbox Activity Audit Report
Version:        1.0
Author:         Ryan Adams
Website:        https://www.governmentcontrol.net/
GitHub:         https://github.com/Ryan-Adams57
GitLab:         https://gitlab.com/Ryan-Adams57
PasteBin:       https://pastebin.com/u/Removed_Content
=============================================================================================
#>

Param
(
    [Parameter(Mandatory = $false)]
    [Switch]$IncludeExternalAccess,
    [Nullable[DateTime]]$StartDate,
    [Nullable[DateTime]]$EndDate,
    [string]$Organization,
    [string]$ClientId,
    [string]$CertificateThumbprint,
    [string]$UserName,
    [string]$Password,
    [string]$SharedMailboxUPN
)

$MaxStartDate=((Get-Date).AddDays(-179)).Date

if(($StartDate -eq $null) -and ($EndDate -eq $null))
{
 $EndDate=(Get-Date).Date
 $StartDate=$MaxStartDate
}

While($true)
{
 if ($StartDate -eq $null)
 {
  $StartDate=Read-Host Enter start time for report generation '(Eg:09/24/2024)'
 }
 Try
 {
  $Date=[DateTime]$StartDate
  if($Date -ge $MaxStartDate)
  { 
   break
  }
  else
  {
   Write-Host `nAudit can be retrieved only for the past 180 days. Please select a date after $MaxStartDate -ForegroundColor Red
   return
  }
 }
 Catch
 {
  Write-Host `nNot a valid date -ForegroundColor Red
 }
}

While($true)
{
 if ($EndDate -eq $null)
 {
  $EndDate=Read-Host Enter End time for report generation '(Eg: 9/24/2024)'
 }
 Try
 {
  $Date=[DateTime]$EndDate
  if($EndDate -lt ($StartDate))
  {
   Write-Host End time should be later than start time -ForegroundColor Red
   return
  }
  break
 }
 Catch
 {
  Write-Host `nNot a valid date -ForegroundColor Red
 }
}

Function Connect_Exo
{
 $Module = Get-Module ExchangeOnlineManagement -ListAvailable
 if($Module.count -eq 0) 
 { 
  Write-Host Exchange Online PowerShell module is not available -ForegroundColor yellow  
  $Confirm= Read-Host Are you sure you want to install module? [Y] Yes [N] No 
  if($Confirm -match "[yY]") 
  { 
   Write-host "Installing Exchange Online PowerShell module"
   Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force
  } 
  else 
  { 
   Write-Host Exchange Online module is required. Install using Install-Module ExchangeOnlineManagement cmdlet. 
   Exit
  }
 } 

 Write-Host Connecting to Exchange Online...

 if(($UserName -ne "") -and ($Password -ne ""))
 {
  $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
  $Credential  = New-Object System.Management.Automation.PSCredential $UserName,$SecuredPassword
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
}

Connect_Exo

if($SharedMailboxUPN -eq "")
{
 $SharedMailboxUPN= Read-Host "Enter shared mailbox name (eg: support@contoso.com)"
}

$MailboxDetails=Get-ExoMailbox -Identity $SharedMailboxUPN
if(!($?))
{
 Write-Host The given mailbox $SharedMailboxUPN is not valid. Please provide a valid shared mailbox name. -ForegroundColor Red
 Exit
}

$Location=Get-Location
$OutputCSV="$Location\Shared_Mailbox_Activity_Audit_Report_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"
$IntervalTimeInMinutes=1440
$CurrentStart=$StartDate
$CurrentEnd=$CurrentStart.AddMinutes($IntervalTimeInMinutes)

if($CurrentEnd -gt $EndDate)
{
 $CurrentEnd=$EndDate
}

$AggregateResults = 0
$CurrentResultCount=0
$SMBActivitiesCount=0

Write-Host `nRetrieving audit log from $StartDate to $EndDate... -ForegroundColor Cyan

while($true)
{
 if($CurrentStart -eq $CurrentEnd)
 {
  Write-Host Start and end time are same. Please enter different time range -ForegroundColor Red
  Exit
 }

 $Results=Search-UnifiedAuditLog -StartDate $CurrentStart -EndDate $CurrentEnd -Operations 'ApplyRecord','Copy','Create','FolderBind','HardDelete','SendAs','SendOnBehalf','MailItemsAccessed','MessageBind','Move','MoveToDeletedItems','RecordDelete','SoftDelete','Update','UpdateCalendarDelegation','UpdateFolderPermissions','UpdateInboxRules' -SessionId s -SessionCommand ReturnLargeSet -ResultSize 5000
 
 foreach($Result in $Results)
 {
  $MoreInfo=$Result.auditData
  $AuditData=$Result.auditdata | ConvertFrom-Json
  $Operation= $AuditData.operation

  if($AuditData.LogonType -eq 0)
  {
   continue
  }
  
  if((!($IncludeExternalAccess.IsPresent)) -and ($AuditData.ExternalAccess -eq $true))
  {
   continue
  }

  if(($AuditData.LogonUserSId -ne $AuditData.MailboxOwnerSid) -or ((($AuditData.Operation -eq "SendAs") -or ($AuditData.Operation -eq "SendOnBehalf")) -and ($AuditData.UserType -eq 0)))
  {
   $AuditData.CreationTime=(Get-Date($AuditData.CreationTime)).ToLocalTime()

   if($AuditData.LogonType -eq 1)
   {
    $LogonType="Administrator"
   }
   elseif($AuditData.LogonType -eq 2)
   {
    $LogonType="Delegated"
   }
   else
   {
    $LogonType="Microsoft datacenter"
   }

   if($AuditData.Operation -eq "SendAs")
   {
    $AccessedMB=$AuditData.SendAsUserSMTP
    $AccessedBy=$AuditData.UserId
   }
   elseif($AuditData.Operation -eq "SendOnBehalf")
   {
    $AccessedMB=$AuditData.SendOnBehalfOfUserSmtp
    $AccessedBy=$AuditData.UserId
   }
   else
   {
    $AccessedMB=$AuditData.MailboxOwnerUPN
    $AccessedBy=$AuditData.UserId
   }

   if(($AccessedMB -eq $AccessedBy) -or ($AccessedMB -ne $SharedMailboxUPN))
   { 
    Continue
   }

   $SMBActivitiesCount++

   $AllAudits=@{
    'Activity Time'=$AuditData.CreationTime
    'Performed by'=$AccessedBy
    'Performed Operation'=$AuditData.Operation
    'Shared Mailbox Name'=$AccessedMB
    'Logon Type'=$LogonType
    'Result Status'=$AuditData.ResultStatus
    'External Access'=$AuditData.ExternalAccess
    'More Info'=$MoreInfo
   }

   $AllAuditData= New-Object PSObject -Property $AllAudits
   $AllAuditData | Sort-Object 'Activity Time' | 
   Select-Object 'Activity Time','Shared Mailbox Name','Performed Operation','Performed by','Result Status','Logon Type','External Access','More Info' | 
   Export-Csv $OutputCSV -NoTypeInformation -Append
  }
 }
 
 $CurrentResultCount=$CurrentResultCount+($Results.count)
 $AggregateResults +=$Results.count

 Write-Progress -Activity "`n     Retrieving audit log for $CurrentStart : $CurrentResultCount records"`n" Total processed audit record count: $AggregateResults"

 if(($CurrentResultCount -eq 50000) -or ($Results.count -lt 5000))
 {
  if($CurrentResultCount -eq 50000)
  {
   Write-Host Retrieved max record for the current range. Proceeding further may cause data loss. -ForegroundColor Red
   $Confirm=Read-Host `nAre you sure you want to continue? [Y] Yes [N] No
   if($Confirm -notmatch "[Y]")
   {
    Write-Host Please rerun the script with reduced time interval -ForegroundColor Red
    Exit
   }
   else
   {
    Write-Host Proceeding audit log collection with potential data loss
   }
  }

  if(($CurrentEnd -eq $EndDate))
  {
   break
  }

  [DateTime]$CurrentStart=$CurrentEnd

  if($CurrentStart -gt (Get-Date))
  {
   break
  }

  [DateTime]$CurrentEnd=$CurrentStart.AddMinutes($IntervalTimeInMinutes)

  if($CurrentEnd -gt $EndDate)
  {
   $CurrentEnd=$EndDate
  }

  $CurrentResultCount=0
 }
}

Write-Host `n~~ Script maintained by Ryan Adams ~~`n -ForegroundColor Green
Write-Host "~~ Visit https://www.governmentcontrol.net/ for Microsoft 365 audit and security reporting resources. ~~" -ForegroundColor Green `n`n
  
If($AggregateResults -eq 0)
{
 Write-Host No records found
}
else
{
 Write-Host `nThe output file contains $SMBActivitiesCount audit records
 if((Test-Path -Path $OutputCSV) -eq "True")
 {
  Write-Host `nThe Output file available in: -NoNewline -ForegroundColor Yellow
  Write-Host $OutputCSV 
  $Prompt = New-Object -ComObject wscript.shell
  $UserInput = $Prompt.popup("Do you want to open output file?",0,"Open Output File",4)
  If ($UserInput -eq 6)
  {
   Invoke-Item "$OutputCSV"
  }
 }
}

Disconnect-ExchangeOnline -Confirm:$false
