<#
=============================================================================================
Name:           Get SendAs Email Audit Report
Description:    Monitor emails sent using SendAs permission
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
    [Nullable[DateTime]]$StartDate,
    [Nullable[DateTime]]$EndDate,
    [string]$UserName,
    [string]$Password
)

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
   Import-Module ExchangeOnlineManagement
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
  Connect-ExchangeOnline -Credential $Credential
 }
 else
 {
  Connect-ExchangeOnline
 }
}

$MaxStartDate=((Get-Date).AddDays(-89)).Date

if(($StartDate -eq $null) -and ($EndDate -eq $null))
{
 $EndDate=(Get-Date).Date
 $StartDate=$MaxStartDate
}

While($true)
{
 if ($StartDate -eq $null)
 {
  $StartDate=Read-Host Enter start time for report generation '(Eg:04/28/2021)'
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
   Write-Host `nAudit can be retrieved only for past 90 days. Please select a date after $MaxStartDate -ForegroundColor Red
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
  $EndDate=Read-Host Enter End time for report generation '(Eg: 04/28/2021)'
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

$OutputCSV=".\SendAs_Email_Audit_Report_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv" 
$IntervalTimeInMinutes=1440
$CurrentStart=$StartDate
$CurrentEnd=$CurrentStart.AddMinutes($IntervalTimeInMinutes)

if($CurrentEnd -gt $EndDate)
{
 $CurrentEnd=$EndDate
}

if($CurrentStart -eq $CurrentEnd)
{
 Write-Host Start and end time are same. Please enter different time range -ForegroundColor Red
 Exit
}

Connect_Exo

$CurrentResultCount=0
$AggregateResultCount=0
Write-Host `nAuditing SendAs emails from $StartDate to $EndDate...
$ProcessedAuditCount=0
$OutputEvents=0

while($true)
{
 Search-UnifiedAuditLog -StartDate $CurrentStart -EndDate $CurrentEnd -Operations SendAs -SessionId s -SessionCommand ReturnLargeSet -ResultSize 5000 | ForEach-Object {

  $ResultCount++
  $ProcessedAuditCount++

  Write-Progress -Activity "`n     Retrieving SendAs activities from $CurrentStart to $CurrentEnd.."`n" Processed audit record count: $ProcessedAuditCount"

  $MoreInfo=$_.auditdata
  $Operation=$_.Operations
  $SentBy=$_.UserIds

  if($SentBy -eq "S-1-5-18")
  {
   $SentBy="Service account"
  }

  $AuditData=$_.auditdata | ConvertFrom-Json
  $SentAs=$AuditData.SendAsUserSMTP
  $Subject=$AuditData.Item.Subject
  $Result=$AuditData.ResultStatus
  $SentTime=(Get-Date($AuditData.CreationTime)).ToLocalTime()

  $OutputEvents++

  $ExportResult=@{
    'Sent Time'=$SentTime
    'Sent By'=$SentBy
    'Sent As'=$SentAs
    'Subject'=$Subject
    'Operation'=$Operation
    'Result'=$Result
    'More Info'=$MoreInfo
  }

  $ExportObject= New-Object PSObject -Property $ExportResult  
  $ExportObject | Select-Object 'Sent Time','Sent By','Sent As','Subject','Operation','Result','More Info' | Export-Csv -Path $OutputCSV -NoTypeInformation -Append 
 }

 $CurrentResultCount=$CurrentResultCount+$ResultCount
 
 if($CurrentResultCount -ge 50000)
 {
  Write-Host Retrieved max record for current range. Proceeding further may cause data loss or rerun with reduced time interval. -ForegroundColor Red
  $Confirm=Read-Host `nAre you sure you want to continue? [Y] Yes [N] No
  if($Confirm -match "[Y]")
  {
   Write-Host Proceeding audit log collection with potential data loss
   [DateTime]$CurrentStart=$CurrentEnd
   [DateTime]$CurrentEnd=$CurrentStart.AddMinutes($IntervalTimeInMinutes)
   $CurrentResultCount=0
   if($CurrentEnd -gt $EndDate)
   {
    $CurrentEnd=$EndDate
   }
  }
  else
  {
   Write-Host Please rerun the script with reduced time interval -ForegroundColor Red
   Exit
  }
 }

 if($ResultCount -lt 5000)
 { 
  if($CurrentEnd -eq $EndDate)
  {
   break
  }
  $CurrentStart=$CurrentEnd 
  if($CurrentStart -gt (Get-Date))
  {
   break
  }
  $CurrentEnd=$CurrentStart.AddMinutes($IntervalTimeInMinutes)
  $CurrentResultCount=0
  if($CurrentEnd -gt $EndDate)
  {
   $CurrentEnd=$EndDate
  }
 }                                                                                             
 $ResultCount=0
}

If($OutputEvents -eq 0)
{
 Write-Host No records found
}
else
{
 Write-Host `nThe output file contains $OutputEvents audit records `n
 if((Test-Path -Path $OutputCSV) -eq "True") 
 {
  Write-Host "The Output file available in:" -NoNewline -ForegroundColor Yellow
  Write-Host  $OutputCSV 
  $Prompt = New-Object -ComObject wscript.shell   
  $UserInput = $Prompt.popup("Do you want to open output file?",0,"Open Output File",4)   
  If ($UserInput -eq 6)   
  {   
   Invoke-Item "$OutputCSV"  
  } 
 }
}

Disconnect-ExchangeOnline -Confirm:$false -InformationAction Ignore -ErrorAction SilentlyContinue

Write-Host `n~~ Script maintained by Ryan Adams ~~`n -ForegroundColor Green 
Write-Host "~~ Visit https://www.governmentcontrol.net/ for Microsoft 365 reporting and security resources. ~~" -ForegroundColor Green `n`n
