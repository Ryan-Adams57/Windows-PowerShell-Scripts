<#
=============================================================================================
Name:           Microsoft 365 User Login History Report
Description:    Exports Microsoft 365 user sign-in history to CSV
Version:        4.0
Author:         Ryan Adams
Website:        https://www.governmentcontrol.net/
GitHub:         https://github.com/Ryan-Adams57
GitLab:         https://gitlab.com/Ryan-Adams57
PasteBin:       https://pastebin.com/u/Removed_Content

Script Highlights: 
~~~~~~~~~~~~~~~~~
1. Automatically installs the Exchange Online PowerShell module (if not installed already) upon confirmation.
2. Allows filtering based on successful and failed logon attempts. 
3. Exports IP addresses from where Microsoft 365 users log in. 
4. Supports MFA-enabled accounts. 
5. Allows exporting login attempts for all users or specific users. 
6. Supports advanced filtering such as sign-in and suspicious login reporting. 
7. Exports results to CSV. 
8. Tracks workload-based sign-in history such as Entra ID, Exchange Online, SharePoint Online, and Microsoft Teams.
9. Scheduler-friendly with credential parameter support. 
10. Supports certificate-based authentication.

Change Log
~~~~~~~~~~
V1.0 - File created
V2.0 - Upgraded from Exchange Online PowerShell V1 module.
V2.1 - Minor usability improvements.
V3.0 - Added certificate-based authentication support.
V4.0 - Added workload parameter to enhance filtering capability.
============================================================================================
#>

Param
(
    [Parameter(Mandatory = $false)]
    [switch]$Success,
    [switch]$Failed,
    [Nullable[DateTime]]$StartDate,
    [Nullable[DateTime]]$EndDate,
    [ValidateSet(
        "EntraID", 
        "MicrosoftTeams",
        "Exchange", 
        "SharePoint"
    )]
    [string[]]$Workload,
    [string]$UserName,
    [string]$Organization,
    [string]$ClientId,
    [string]$CertificateThumbprint,
    [string]$AdminName,
    [string]$Password
)

if ((($StartDate -eq $null) -and ($EndDate -ne $null)) -or (($StartDate -ne $null) -and ($EndDate -eq $null)))
{
 Write-Host "`nPlease enter both StartDate and EndDate for Audit log collection" -ForegroundColor Red
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
  Write-Host "`nAudit log can be retrieved only for past 180 days." -ForegroundColor Red
  Exit
 }
 if($EndDate -lt ($StartDate))
 {
  Write-Host "`nEnd time should be later than start time" -ForegroundColor Red
  Exit
 }
}

$Module = Get-Module ExchangeOnlineManagement -ListAvailable
if($Module.count -eq 0) 
{ 
  Write-Host "Exchange Online PowerShell module is not available" -ForegroundColor Yellow  
  $Confirm= Read-Host "Are you sure you want to install module? [Y] Yes [N] No" 
  if($Confirm -match "[yY]") 
  { 
   Write-Host "Installing Exchange Online PowerShell module"
   Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force -Scope CurrentUser
   Import-Module ExchangeOnlineManagement
  } 
  else 
  { 
   Write-Host "Exchange Online module is required. Please install using Install-Module ExchangeOnlineManagement."
   Exit
  }
} 

Write-Host "Connecting to Exchange Online..."

if(($AdminName -ne "") -and ($Password -ne ""))
{
  $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
  $Credential  = New-Object System.Management.Automation.PSCredential $AdminName,$SecuredPassword
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

$WorkloadOperations = @{
    "EntraID" = "UserLoggedIn,UserLoginFailed";
    "MicrosoftTeams" = "TeamsSessionStarted";
    "Exchange" = "MailboxLogin";
    "SharePoint" = "SignInEvent"
}

$Location=Get-Location
$OutputCSV="$Location\UserLoginHistoryReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv" 
$IntervalTimeInMinutes=1440
$CurrentStart=$StartDate
$CurrentEnd=$CurrentStart.AddMinutes($IntervalTimeInMinutes)

if ($Failed.IsPresent) {
 $Operation="UserLoginFailed"
} elseif (-not [string]::IsNullOrEmpty($Workload)) {
 $Operation = ($Workload | ForEach-Object { $WorkloadOperations[$_] }) -join ","
} elseif ($Success.IsPresent) {
 $Operation="UserLoggedIn,TeamsSessionStarted,MailboxLogin,SignInEvent"
} else {
 $Operation="UserLoggedIn,UserLoginFailed,TeamsSessionStarted,MailboxLogin,SignInEvent"
}

if($CurrentEnd -gt $EndDate)
{
 $CurrentEnd=$EndDate
}

$AggregateResults = 0
$CurrentResult= @()
$CurrentResultCount=0

Write-Host "`nRetrieving audit log from $StartDate to $EndDate..." -ForegroundColor Yellow

while($true)
{ 
 if($CurrentStart -eq $CurrentEnd)
 {
  Write-Host "Start and end time are same. Please enter different time range." -ForegroundColor Red
  Exit
 }

 if($UserName -ne "")
 {
  $Results=Search-UnifiedAuditLog -UserIds $UserName -StartDate $CurrentStart -EndDate $CurrentEnd -Operations $Operation -SessionId s -SessionCommand ReturnLargeSet -ResultSize 5000
 }
 else
 {
  $Results=Search-UnifiedAuditLog -StartDate $CurrentStart -EndDate $CurrentEnd -Operations $Operation -SessionId s -SessionCommand ReturnLargeSet -ResultSize 5000
 }

 $ResultsCount=($Results|Measure-Object).count

 foreach($Result in $Results)
 {
  $AuditData=$Result.AuditData | ConvertFrom-Json
  $AuditData.CreationTime=(Get-Date($AuditData.CreationTime)).ToLocalTime()

  $AllAudits=@{
    'Login Time'=$AuditData.CreationTime
    'User Name'=$AuditData.UserId
    'IP Address'=$AuditData.ClientIP
    'Operation'=$AuditData.Operation
    'Result Status'=$AuditData.ResultStatus
    'Workload'=$AuditData.Workload
  }

  $AllAuditData= New-Object PSObject -Property $AllAudits
  $AllAuditData | Sort-Object 'Login Time','User Name' |
  Select-Object 'Login Time','User Name','IP Address','Operation','Result Status','Workload' |
  Export-Csv $OutputCSV -NoTypeInformation -Append
 }

 $CurrentResultCount+=$ResultsCount
 $AggregateResults +=$ResultsCount

 Write-Progress -Activity "`nRetrieving audit log from $CurrentStart to $CurrentEnd.." -Status "Processed audit record count: $AggregateResults"

 if(($CurrentResultCount -eq 50000) -or ($ResultsCount -lt 5000))
 {
  if($CurrentResultCount -eq 50000)
  {
   Write-Host "Retrieved max record for the current range. Consider reducing time interval." -ForegroundColor Red
   $Confirm=Read-Host "`nAre you sure you want to continue? [Y] Yes [N] No"
   if($Confirm -notmatch "[Y]")
   {
    Write-Host "Please rerun the script with reduced time interval." -ForegroundColor Red
    Exit
   }
   else
   {
    Write-Host "Proceeding audit log collection with potential data loss."
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

If($AggregateResults -eq 0)
{
 Write-Host "No records found"
}
else
{
 if((Test-Path -Path $OutputCSV) -eq "True") 
 {
  Write-Host ""
  Write-Host "The output file available in:" -NoNewline -ForegroundColor Yellow
  Write-Host $OutputCSV 
  Write-Host "`nThe output file contains $AggregateResults audit records"

  Write-Host "`n~~ Script prepared by Ryan Adams ~~`n" -ForegroundColor Green
  Write-Host "Website: https://www.governmentcontrol.net/" -ForegroundColor Yellow
  Write-Host "GitHub: https://github.com/Ryan-Adams57" -ForegroundColor Yellow
  Write-Host "GitLab: https://gitlab.com/Ryan-Adams57" -ForegroundColor Yellow
  Write-Host "PasteBin: https://pastebin.com/u/Removed_Content`n" -ForegroundColor Yellow

  $Prompt = New-Object -ComObject wscript.shell   
  $UserInput = $Prompt.popup("Do you want to open output file?",0,"Open Output File",4)   
  If ($UserInput -eq 6)   
  {   
   Invoke-Item "$OutputCSV"   
  } 
 }
}

Disconnect-ExchangeOnline -Confirm:$false -InformationAction Ignore -ErrorAction SilentlyContinue
