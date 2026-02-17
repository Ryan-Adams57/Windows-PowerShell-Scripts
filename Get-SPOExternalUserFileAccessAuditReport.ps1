<#
=============================================================================================
Name:           SharePoint Online External User File Access Audit Report
Description:    This script exports SharePoint Online external user file access report to CSV
Version:        1.0
Website:        https://www.governmentcontrol.net/
Author:         Ryan Adams
GitHub:         https://github.com/Ryan-Adams57
GitLab:         https://gitlab.com/Ryan-Adams57
PasteBin:       https://pastebin.com/u/Removed_Content

Script Highlights: 
~~~~~~~~~~~~~~~~~
1. The script uses modern authentication to connect to Exchange Online.   
2. The script can be executed with MFA enabled account too.   
3. Exports report results to CSV file.   
4. Allows you to generate an external file access report for a custom period.   
5. Automatically installs the EXO V2 module (if not installed already) upon your confirmation.  
6. The script is scheduler friendly. Credential can be passed as a parameter instead of saving inside the script. 

For detailed script execution: https://www.governmentcontrol.net/
============================================================================================
#>
Param
(
    [Parameter(Mandatory = $false)]
    [Nullable[DateTime]]$StartDate,
    [Nullable[DateTime]]$EndDate,
    [string]$AdminName,
    [string]$Password
)

#Check for EXO v2 module installation
$Module = Get-Module ExchangeOnlineManagement -ListAvailable
if($Module.count -eq 0) 
{ 
 Write-Host Exchange Online PowerShell V2 module is not available  -ForegroundColor Yellow  
 $Confirm= Read-Host Are you sure you want to install module? [Y] Yes [N] No 
 if($Confirm -match "[yY]") 
 { 
  Write-Host "Installing Exchange Online PowerShell module"
  Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force
 } 
 else 
 { 
  Write-Host EXO V2 module is required to connect Exchange Online. Please install module using Install-Module ExchangeOnlineManagement cmdlet. 
  Exit
 }
} 

Write-Host "Connecting to Exchange Online..."

if(($AdminName -ne "") -and ($Password -ne ""))
{
 $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
 $Credential  = New-Object System.Management.Automation.PSCredential $AdminName,$SecuredPassword
 Connect-ExchangeOnline -Credential $Credential
}
else
{
 Connect-ExchangeOnline
}

if(($StartDate -eq $null) -and ($EndDate -eq $null))
{
 $EndDate=(Get-Date).Date
 $StartDate= ((Get-Date).AddDays(-89)).Date
}
 
While($true)
{
 if ($StartDate -eq $null)
 {
  $StartDate=Read-Host "Enter start time for report generation (Eg:03/18/2021)"
 }
 Try
 {
  $Date=[DateTime]$StartDate
  if($Date -gt ((Get-Date).AddDays(-90)))
  { 
   break
  }
  else
  {
   Write-Host "`nFile access report can be retrieved only for past 90 days. Please select a valid date within the allowed range." -ForegroundColor Red
   return
  }
 }
 Catch
 {
  Write-Host "`nNot a valid date" -ForegroundColor Red
 }
}

While($true)
{
 if ($EndDate -eq $null)
 {
  $EndDate=Read-Host "Enter End time for File access audit report (Eg: 03/18/2021)"
 }
 Try
 {
  $Date=[DateTime]$EndDate
  if($EndDate -lt ($StartDate))
  {
   Write-Host "End time should be later than start time" -ForegroundColor Red
   return
  }
  break
 }
 Catch
 {
  Write-Host "`nNot a valid date" -ForegroundColor Red
 }
}

$OutputCSV=".\ExternalUserFileAccessReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv" 
$IntervalTimeInMinutes=1440
$CurrentStart=$StartDate
$CurrentEnd=$CurrentStart.AddMinutes($IntervalTimeInMinutes)

if($CurrentEnd -gt $EndDate)
{
 $CurrentEnd=$EndDate
}

$AggregateResultCount=0
Write-Host "`nRetrieving external user file access data from $StartDate to $EndDate..." -ForegroundColor Yellow
$i=0

while($true)
{ 
 if($CurrentStart -eq $CurrentEnd)
 {
  Write-Host "Start and end time are same. Please enter different time range" -ForegroundColor Red
  Exit
 }

 $Results=Search-UnifiedAuditLog -StartDate $CurrentStart -EndDate $CurrentEnd -Operations FileAccessed -UserIds *#EXT#* -SessionId s -SessionCommand ReturnLargeSet -ResultSize 5000
 $ResultCount=($Results | Measure-Object).Count

 foreach($Result in $Results)
 {
  $i++
  $MoreInfo=$Result.AuditData
  $AuditData=$Result.AuditData | ConvertFrom-Json
  $ActivityTime=Get-Date($AuditData.CreationTime) -Format g
  $UserID=$AuditData.UserId
  $AccessedFile=$AuditData.SourceFileName
  $FileExtension=$AuditData.SourceFileExtension
  $SiteURL=$AuditData.SiteURL
  $Workload=$AuditData.Workload

  $ExportResult=@{
   'Accessed Time'=$ActivityTime
   'External User'=$UserID
   'Workload'=$Workload
   'More Info'=$MoreInfo
   'Accessed File'=$AccessedFile
   'Site URL'=$SiteURL
   'File Extension'=$FileExtension
  }

  $ExportObject= New-Object PSObject -Property $ExportResult  
  $ExportObject | Select-Object 'Accessed Time','External User','Accessed File','Site URL','File Extension','Workload','More Info' | Export-Csv -Path $OutputCSV -NoTypeInformation -Append 
 }

 Write-Progress -Activity "Retrieving external user file access audit data from $StartDate to $EndDate.." -Status "Processed audit record count: $i"

 if($ResultCount -lt 5000)
 {
  $AggregateResultCount +=$ResultCount
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
  if($CurrentEnd -gt $EndDate)
  {
   $CurrentEnd=$EndDate
  }
 }
}

If($AggregateResultCount -eq 0)
{
 Write-Host "No records found"
}
else
{
 Write-Host "`nThe output file contains $AggregateResultCount audit records"
 if((Test-Path -Path $OutputCSV) -eq "True") 
 {
  Write-Host "`nThe Output file available in: " -NoNewline -ForegroundColor Yellow
  Write-Host $OutputCSV 
  Write-Host "`n~~ Script maintained by Ryan Adams ~~`n" -ForegroundColor Green
  $Prompt = New-Object -ComObject wscript.shell   
  $UserInput = $Prompt.popup("Do you want to open output file?",0,"Open Output File",4)   
  If ($UserInput -eq 6)   
  {   
   Invoke-Item "$OutputCSV"   
  } 
 }
}

Disconnect-ExchangeOnline -Confirm:$false | Out-Null
