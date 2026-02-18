<#
=============================================================================================
Name:           Export Microsoft 365 Teams Meeting and Attendance Audit Report Using PowerShell
Version:        2.0
Description:    This script exports Teams meeting details and attendance reports into two CSV files.
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
    [string]$Password,
    [string]$Organization,
    [string]$ClientId,
    [string]$CertificateThumbprint
)

if ((($StartDate -eq $null) -and ($EndDate -ne $null)) -or (($StartDate -ne $null) -and ($EndDate -eq $null)))
{
 Write-Host `nPlease enter both StartDate and EndDate for Audit log collection -ForegroundColor Red
 exit
}   
elseif(($StartDate -eq $null) -and ($EndDate -eq $null))
{
 $StartDate=(((Get-Date).AddDays(-180))).Date
 $EndDate=Get-Date
}
else
{
 $StartDate=[DateTime]$StartDate
 $EndDate=[DateTime]$EndDate
 if($StartDate -lt ((Get-Date).AddDays(-180)))
 { 
  Write-Host `nAudit log can be retrieved only for past 180 days. Please select a valid date range within 180 days. -ForegroundColor Red
  Exit
 }
 if($EndDate -lt ($StartDate))
 {
  Write-Host `nEnd time should be later than start time -ForegroundColor Red
  Exit
 }
}

$Module = Get-Module ExchangeOnlineManagement -ListAvailable
if($Module.count -eq 0) 
{ 
 Write-Host Exchange Online PowerShell module is not available -ForegroundColor yellow  
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

if(($UserName -ne "") -and ($Password -ne ""))
{
 $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
 $Credential  = New-Object System.Management.Automation.PSCredential $UserName,$SecuredPassword
 Connect-ExchangeOnline -Credential $Credential -ShowBanner:$false
}
elseif($Organization -ne "" -and $ClientId -ne "" -and $CertificateThumbprint -ne "")
{
 Connect-ExchangeOnline -AppId $ClientId -CertificateThumbprint $CertificateThumbprint  -Organization $Organization -ShowBanner:$false
}
else
{
 Connect-ExchangeOnline -ShowBanner:$false
}

Function Get_TeamMeetings
{
 $Result=""   
 $Results=@()  
 Write-Host `nRetrieving Teams meeting details from $StartDate to $EndDate...
 Search-UnifiedAuditLog -StartDate $StartDate -EndDate $EndDate -Operations "MeetingDetail" -ResultSize 5000 | ForEach-Object {
  $Global:MeetingCount++
  Write-Progress -Activity "`n     Retrieving Teams meetings data from $StartDate to $EndDate.."`n" Processed Teams meetings count: $Global:MeetingCount"
  $AuditData=$_.AuditData  | ConvertFrom-Json
  $MeetingID=$AuditData.ID
  $CreatedBy=$AuditData.UserId
  $StartTime=(Get-Date($AuditData.StartTime)).ToLocalTime()
  $EndTime=(Get-Date($AuditData.EndTime)).ToLocalTime()
  $MeetingURL=$AuditData.MeetingURL
  $MeetingType=$AuditData.ItemName
  $Result=@{
   'Meeting id'=$MeetingID
   'Created By'=$CreatedBy
   'Start Time'=$StartTime
   'End Time'=$EndTime
   'Meeting Type'=$MeetingType
   'Meeting Link'=$MeetingURL
   'More Info'=$AuditData
  }
  $Results= New-Object PSObject -Property $Result  
  $Results | Select-Object 'Meeting id','Created By','Start Time','End Time','Meeting Type','Meeting Link','More Info' | Export-Csv -Path $ExportCSV -NoTypeInformation -Append 
 }
 if($MeetingCount -ne 0)
 {
  Write-Host "$Global:MeetingCount meeting details exported." 
 }
 else
 {
  Write-Host "No meetings found"
 }
}

$MaxStartDate=((Get-Date).AddDays(-180)).Date

While($true)
{
 if ($StartDate -eq $null)
 {
  $StartDate=Read-Host Enter start time for report generation '(Eg:11/23/2024)'
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
   Write-Host `nAudit can be retrieved only for past 180 days. Please select a valid date. -ForegroundColor Red
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
  $EndDate=Read-Host Enter End time for report generation '(Eg: 11/23/2024)'
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

$OutputCSV=".\TeamsMeetingAttendanceReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv" 
$ExportCSV=".\TeamsMeetingsReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv" 
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

$Global:MeetingCount=0
Get_TeamMeetings

if($Global:MeetingCount -ne 0)
{
 $CurrentResultCount=0
 Write-Host `nGenerating Teams meeting attendance report from $StartDate to $EndDate...
 $ProcessedAuditCount=0
 $OutputEvents=0
 $RetriveOperation="MeetingParticipantDetail"

 while($true)
 { 
  $Results=Search-UnifiedAuditLog -StartDate $CurrentStart -EndDate $CurrentEnd -Operations $RetriveOperation -SessionId s -SessionCommand ReturnLargeSet -ResultSize 5000 
  $ResultsCount=($Results|Measure-Object).count 

  foreach($Result in $Results)
  {
   $ProcessedAuditCount++
   $AuditData=$Result.AuditData  | ConvertFrom-Json
   $MeetingID=$AuditData.MeetingDetailId
   $CreatedBy=$Result.UserIDs
   $AttendeesInfo=($AuditData.Attendees)
   $Attendees=$AttendeesInfo.userObjectId
   $AttendeesType=$AttendeesInfo.RecipientType

   if($AttendeesType -ne "User")
   {
    $Attendees=$AttendeesInfo.DisplayName
   }
   else
   {
    $Attendees=(Get-ExoRecipient -Identity $Attendees).DisplayName
   }

   $JoinTime=(Get-Date($AuditData.JoinTime)).ToLocalTime()
   $LeaveTime=(Get-Date($AuditData.LeaveTime)).ToLocalTime()

   $OutputEvents++
   $ExportResult=@{
    'Meeting id'=$MeetingID
    'Created By'=$CreatedBy
    'Attendees'=$Attendees
    'Attendee Type'=$AttendeesType
    'Joined Time'=$JoinTime
    'Left Time'=$LeaveTime
    'More Info'=$AuditData
   }

   $ExportResults= New-Object PSObject -Property $ExportResult  
   $ExportResults | Select-Object 'Meeting id','Created By','Attendees','Attendee Type','Joined Time','Left Time','More Info' | Export-Csv -Path $OutputCSV -NoTypeInformation -Append 
  }

  $CurrentResultCount=$CurrentResultCount+$ResultsCount

  Write-Progress -Activity "`n     Retrieving audit log for $CurrentStart : $CurrentResultCount records"`n" Total processed audit record count: $ProcessedAuditCount"

  if(($CurrentResultCount -eq 50000) -or ($ResultsCount -lt 5000))
  {
   if($CurrentResultCount -eq 50000)
   {
    Write-Host Retrieved max record for the current range. Proceeding further may cause data loss or rerun the script with reduced time interval. -ForegroundColor Red
    $Confirm=Read-Host `nAre you sure you want to continue? [Y] Yes [N] No
    if($Confirm -notmatch "[Y]")
    {
     Write-Host Please rerun the script with reduced time interval -ForegroundColor Red
     Exit
    }
    else
    {
     Write-Host Proceeding audit log collection with data loss
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
   $CurrentResult = @()
  }
 }
}

Write-Host `n~~ Script maintained by Ryan Adams ~~`n -ForegroundColor Green
Write-Host "~~ Visit https://www.governmentcontrol.net/ for additional Microsoft 365 security and reporting resources. ~~" -ForegroundColor Green `n

if((Test-Path -Path $OutputCSV) -eq "True") 
{
 Write-Host `nThe Teams meeting attendance report contains $OutputEvents audit records"
 Write-Host `nThe Teams meetings attendance report available in: " -NoNewline -ForegroundColor Yellow
 Write-Host "$OutputCSV"

 $Prompt = New-Object -ComObject wscript.shell   
 $UserInput = $Prompt.popup("Do you want to open output file?",0,"Open Output File",4)   
 If ($UserInput -eq 6)   
 {   
  Invoke-Item "$OutputCSV"   
  Invoke-Item "$ExportCSV"
 } 
}

Disconnect-ExchangeOnline -Confirm:$false -InformationAction Ignore -ErrorAction SilentlyContinue
