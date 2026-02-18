<#
=============================================================================================
Name:           Get SharePoint Online Folder Activity Audit Report
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
    [string]$PerformedBy,
    [string]$SiteUrl,
    [string]$ImportSitesCsv,
    [switch]$SharePointOnline,
    [switch]$OneDrive,
    [string]$UserName,
    [string]$Password,
    [string]$Organization,
    [string]$ClientId,
    [string]$CertificateThumbPrint,
    [switch]$IncludeSystemEvent
)

Function Connect_Module {
    $ExchangeModule = Get-Module ExchangeOnlineManagement -ListAvailable
    if ($ExchangeModule.count -eq 0) {
        Write-Host "ExchangeOnline module is not available" -ForegroundColor Yellow
        $confirm = Read-Host "Do you want to install ExchangeOnline module? [Y] Yes  [N] No"
        if ($confirm -match "[Yy]") {
            Write-Host "Installing ExchangeOnline module ..."
            Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force -Scope CurrentUser
            Import-Module ExchangeOnlineManagement
        } else {
            Write-Host "ExchangeOnline module is required. Install using 'Install-Module ExchangeOnlineManagement' cmdlet."
            Exit
        }
    }

    Write-Host "`nConnecting to Exchange Online..." -ForegroundColor Yellow
    if (($UserName -ne "") -and ($Password -ne "")) {
        $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
        $Credential = New-Object System.Management.Automation.PSCredential $UserName, $SecuredPassword
        Connect-ExchangeOnline -Credential $Credential
    } elseif ($Organization -ne "" -and $ClientId -ne "" -and $CertificateThumbPrint -ne "") {
        Connect-ExchangeOnline -AppId $ClientId -CertificateThumbprint $CertificateThumbPrint -Organization $Organization -ShowBanner:$false
    } else {
        Connect-ExchangeOnline -ShowBanner:$false
    }
}

$MaxStartDate = ((Get-Date).AddDays(-180)).Date

if (($StartDate -eq $null) -and ($EndDate -eq $null)) {
    $EndDate = (Get-Date).Date
    $StartDate = $MaxStartDate
}

While ($true) {
    if ($StartDate -eq $null) {
        $StartDate = Read-Host "Enter start time for report generation '(Eg: 04/28/2021)'"
    }
    Try {
        $Date = [DateTime]$StartDate
        if ($Date -ge $MaxStartDate) {
            break
        } else {
            Write-Host "`nAudit can be retrieved only for past 180 days. Please select a date after $MaxStartDate" -ForegroundColor Red
            return
        }
    } Catch {
        Write-Host "`nNot a valid date" -ForegroundColor Red
    }
}

While ($true) {
    if ($EndDate -eq $null) {
        $EndDate = Read-Host "Enter End time for report generation '(Eg: 04/28/2021)'"
    }
    Try {
        $Date = [DateTime]$EndDate
        if ($EndDate -lt ($StartDate)) {
            Write-Host "End time should be later than start time" -ForegroundColor Red
            return
        }
        break
    } Catch {
        Write-Host "`nNot a valid date" -ForegroundColor Red
    }
}

$Location = Get-Location
$OutputCSV = "$Location\SPO_Folder_Activity_Audit_Report_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"
$IntervalTimeInMinutes = 1440
$CurrentStart = $StartDate
$CurrentEnd = $CurrentStart.AddMinutes($IntervalTimeInMinutes)

if ($CurrentEnd -gt $EndDate) {
    $CurrentEnd = $EndDate
}

if ($CurrentStart -eq $CurrentEnd) {
    Write-Host "Start and end time are the same. Please enter a different time range." -ForegroundColor Red
    Exit
}

Connect_Module

$FilterSites = @()
$CurrentResultCount = 0
$AggregateResultCount = 0
Write-Host "`nAuditing folder activities from $StartDate to $EndDate..."
$ExportResults = @()
$OutputEvents = 0
$OperationNames = "FolderCreated, FolderModified, FolderRenamed, FolderCopied, FolderMoved, FolderDeleted, FolderRecycled, FolderDeletedFirstStageRecycleBin, FolderDeletedSecondStageRecycleBin, FolderRestored"

if ($ImportSitesCsv.Length -ne 0)
{
 $FilterSites = Import-Csv -Path $ImportSitesCsv | Select-Object -ExpandProperty SiteUrl
}

while ($true) {
    $Results = Search-UnifiedAuditLog -StartDate $CurrentStart -EndDate $CurrentEnd -Operations $OperationNames -SessionId s -SessionCommand ReturnLargeSet -ResultSize 5000
    $ResultCount = ($Results | Measure-Object).count

    ForEach ($Result in $Results) {
        $AggregateResultCount++
        $MoreInfo = $Result.auditdata
        $Operation = $Result.Operations
        $ActionBy = $Result.UserIds
        $AuditData = $Result.auditdata | ConvertFrom-Json
        $Workload = $AuditData.Workload
        $Site = $AuditData.SiteUrl
        $PrintFlag = "True"

        if (-not $IncludeSystemEvent) {
            if ($ActionBy -in @("app@sharepoint", "SHAREPOINT\system"))
            {
             $PrintFlag = "False"
            }
        }
        
        if(($PerformedBy.Length -ne 0) -and ($PerformedBy -ne $ActionBy))
        {
         $PrintFlag = "False"
        }

        if($SharePointOnline.IsPresent -and ($Workload -eq "OneDrive"))
        {
         $PrintFlag = "False"
        }

        if($OneDrive.IsPresent -and ($Workload -eq "SharePoint"))
        {
         $PrintFlag = "False"
        }

        if(($SiteUrl.Length -ne 0) -and ($SiteUrl -ne $Site))
        {
         $PrintFlag = "False"
        }

        if (($FilterSites.Count -gt 0) -and (-not ($FilterSites -contains $Site)))
        {
         $PrintFlag = "False"
        }

        if($PrintFlag -eq "True")
        {
            $ActivityTime = (Get-Date($AuditData.CreationTime)).ToLocalTime()  
            $AccessFolder = $AuditData.SourceFileName
            $FolderURL = $AuditData.ObjectID
            
            $OutputEvents++
            $ExportResult = @{
                'Activity Time' = $ActivityTime
                'Folder Name' = $AccessFolder
                'Activity' = $Operation
                'Performed By' = $ActionBy
                'Folder URL' = $FolderURL
                'Site URL' = $Site
                'Workload' = $Workload
                'More Info' = $MoreInfo
            }

            $ExportObject = New-Object PSObject -Property $ExportResult  
            $ExportObject | Sort-Object 'Activity Time' | 
            Select-Object 'Activity Time','Activity','Folder Name','Performed By','Folder URL','Site URL','Workload','More Info' | 
            Export-Csv -Path $OutputCSV -NoTypeInformation -Append 
        }
    }

    $CurrentResultCount=$CurrentResultCount+$ResultCount
    Write-Progress -Activity "`n     Retrieving folder activity audit log for $CurrentStart : $CurrentResultCount records"`n" Processed audit record count: $AggregateResultCount"

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

if ($OutputEvents -eq 0) {
    Write-Host "`nNo records found"
} else {
    Write-Host "`nThe output file contains $OutputEvents audit records"
    if ((Test-Path -Path $OutputCSV) -eq $true) {
        Write-Host "`nThe Output file is available at: " -NoNewline -ForegroundColor Yellow
        Write-Host $OutputCSV
        $Prompt = New-Object -ComObject wscript.shell
        $UserInput = $Prompt.popup("Do you want to open output file?", 0, "Open Output File", 4)
        If ($UserInput -eq 6) {
            Invoke-Item "$OutputCSV"
        }
    }
}

Write-Host "`n~~ Script maintained by Ryan Adams ~~" -ForegroundColor Green
Write-Host "~~ Visit https://www.governmentcontrol.net/ for Microsoft 365 security and audit resources. ~~" -ForegroundColor Green

Disconnect-ExchangeOnline -Confirm:$false -InformationAction Ignore -ErrorAction SilentlyContinue
