<#
=============================================================================================
Name:           Invoke Teams Inactivity Archival Manager
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
    [switch]$CreateSession,
    [string]$TenantId,
    [string]$ClientId,
    [string]$CertificateThumbprint,
    [int]$InactiveDays,
    [Switch]$IncludeTeamsWithNoActivity,
    [Switch]$ArchiveInactiveTeams,
    [switch]$Force
)

Function Connect_MgGraph
{
 $Module=Get-Module -Name Microsoft.Graph -ListAvailable
 if($Module.count -eq 0) 
 { 
  Write-Host Microsoft Graph PowerShell SDK is not available  -ForegroundColor yellow  
  $Confirm= Read-Host Are you sure you want to install module? [Y] Yes [N] No 
  if($Confirm -match "[yY]") 
  { 
   Write-host "Installing Microsoft Graph PowerShell module..."
   Install-Module Microsoft.Graph -Repository PSGallery -Scope CurrentUser -AllowClobber -Force
  }
  else
  {
   Write-Host "Microsoft Graph PowerShell module is required to run this script. Please install module using Install-Module Microsoft.Graph cmdlet." 
   Exit
  }
 }

 if($CreateSession.IsPresent)
 {
  Disconnect-MgGraph | Out-Null
 }

 Write-Host Connecting to Microsoft Graph...
 if(($TenantId -ne "") -and ($ClientId -ne "") -and ($CertificateThumbprint -ne ""))  
 {  
  Connect-MgGraph  -TenantId $TenantId -AppId $ClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome
 }
 else
 {
  Connect-MgGraph -Scopes "Reports.Read.All","TeamSettings.ReadWrite.All"  -NoWelcome
 }
}

Connect_MgGraph

$Location=Get-Location
$TempFile="$Location\TeamsUsageReport_tempFile_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm-ss` tt).ToString()).csv" 
$ExportCSV = "$Location\ArchiveInactiveTeams_Report_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm-ss` tt).ToString()).csv"
$Count=0
$PrintedTeams=0
$ArchiveStatus="-"

if($ArchiveInactiveTeams.IsPresent)
{
 if($InactiveDays -eq "")
 {
  Write-Host `nInactive days is mandatory to archive inactive teams. -ForegroundColor Magenta
  $InactiveDays= Read-host Enter Inactive days
 }

 if(!($Force.IsPresent))
 {
  $Confirm= Read-Host `nDo you want to archive teams that are inactive for $InactiveDays days [Y] Yes [N] No 
  if($Confirm -notmatch "[yY]") 
  { 
   Write-host Exiting script...
   Exit
  }
 }
}

Try
{
 Get-MgReportTeamActivityDetail -Period 'D7' -OutFile $TempFile
}
Catch
{
 Write-Host Unable to fetch teams usage report. Error occurred - $($Error[0].Exception.Message) -ForegroundColor Red
 Exit
}

Write-Host Generating inactive teams report...

Import-Csv -Path $TempFile | foreach {
 $TeamName=$_.'Team Name'
 $Count++
 $Print=1
 Write-Progress -Activity "`n     Processed teams: $Count"
 $TeamType=$_.'Team Type'
 $LastActivityDate=$_.'Last Activity Date'
 if($LastActivityDate -eq "")
 {
  $LastActivityDate = "Never Active"
  $InactivePeriod = "-"
 }
 else
 {
  $InactivePeriod=(New-TimeSpan -Start $LastActivityDate).Days
 }
 $IsDeleted=$_.'Is Deleted'
 $TeamId=$_.'Team Id'

 if($InactivePeriod -ne "-")
 {
  if(($InactiveDays -ne "") -and ($InactiveDays -gt $InactivePeriod))
  {
   $Print=0
  }
 }

 if(!($IncludeTeamsWithNoActivity.IsPresent) -and ($LastActivityDate -eq "Never Active"))
 {
  $Print=0
 }

 if($IsDeleted -eq $true)
 {
  $Print=0
 }

 if(($ArchiveInactiveTeams.IsPresent) -and ($Print -eq 1))
 {
  if((Get-mgteam -TeamId $TeamId).IsArchived)
  {
   $ArchiveStatus="Team is already archived"
  }
  else
  {
   Invoke-MgArchiveTeam -TeamId $TeamId -ShouldSetSpoSiteReadOnlyForMembers
   if($?)
   {
    $ArchiveStatus="Successfully archived"
   }
   else
   {
    $ArchiveStatus="Error occurred"
   }
  }
 }

 if($Print -eq 1)
 {
  $PrintedTeams++
  $ExportResult=[PSCustomObject]@{
   'Team Name'=$TeamName;
   'Team Type'=$TeamType;
   'Last Activity Date'=$LastActivityDate;
   'Inactive Days'=$InactivePeriod;
   'Archive Status Log'=$ArchiveStatus
  }
  $ExportResult | Export-Csv -Path $ExportCSV -Notype -Append
 }
}

Remove-Item $TempFile -ErrorAction SilentlyContinue
Disconnect-MgGraph | Out-Null

Write-Host "`nScript execution completed successfully." -ForegroundColor Green
Write-Host "Maintained by Ryan Adams"
Write-Host "Website: https://www.governmentcontrol.net/"
Write-Host "GitHub: https://github.com/Ryan-Adams57"
Write-Host "GitLab: https://gitlab.com/Ryan-Adams57"
Write-Host "PasteBin: https://pastebin.com/u/Removed_Content`n"

if((Test-Path -Path $ExportCSV) -eq "True") 
{
 Write-Host "The exported report contains $PrintedTeams teams."
 Write-Host `nDetailed report available in: -NoNewline -Foregroundcolor Yellow; Write-Host $ExportCSV
 $Prompt = New-Object -ComObject wscript.shell   
 $UserInput = $Prompt.popup("Do you want to open output file?",0,"Open Output File",4)   
 If ($UserInput -eq 6)   
 {   
  Invoke-Item "$ExportCSV"   
 } 
}
else
{
 Write-Host No teams found for the given criteria.
}
