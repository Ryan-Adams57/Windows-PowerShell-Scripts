<#
=============================================================================================
Name:           Audit Office 365 external sharing activities report
Description:    This script exports Office 365 external sharing activities to CSV
Version:        3.0
Website:        https://www.governmentcontrol.net/

Change Log
~~~~~~~~~~

    V1   (20/5/21) - Initial version 
    V2   (22/5/21) - Description update
    V2.1 (26/9/23) - Minor changes
    V3 (9/18/24) - Added support for certificate-based authentication and extended audit log retrieval period from 90 to 180 days 

Script Highlights: 
~~~~~~~~~~~~~~~~~
1. The script generates external sharing report for the last 180 days.  
2. Allows you to generate an external sharing report for a custom period. 
3. Tracks external sharing in SharePoint Online separately.
4. Tracks external sharing in OneDrive separately
5. Exports report results to CSV file.
6. Automatically installs the EXO PowerShell module (if not installed already) upon your confirmation.     
7. The script can be executed with MFA enabled account too. 
8. Supports Certificate-based Authentication (CBA) too.   
9. The script is scheduler-friendly.

For detailed script execution: GitLab https://gitlab.com/Ryan-Adams57
============================================================================================
#>

Param
(
    [Parameter(Mandatory = $false)]
    [Nullable[DateTime]]$StartDate,
    [Nullable[DateTime]]$EndDate,
    [switch]$SharePointOnline,
    [switch]$OneDrive,
    [string]$Organization,
    [string]$ClientId,
    [string]$CertificateThumbprint,
    [string]$AdminName,
    [string]$Password
)

$MaxStartDate = ((Get-Date).AddDays(-179)).Date

# Retrieve audit log for the past 180 days
if (($StartDate -eq $null) -and ($EndDate -eq $null))
{
    $EndDate = (Get-Date).Date
    $StartDate = $MaxStartDate
}

# Getting start date to audit export report
while ($true)
{
    if ($StartDate -eq $null)
    {
        $StartDate = Read-Host "Enter start time for report generation '(Eg:12/15/2023)'"
    }
    try
    {
        $Date = [DateTime]$StartDate
        if ($Date -ge $MaxStartDate)
        { 
            break
        }
        else
        {
            Write-Host "`nAudit can be retrieved only for the past 180 days. Please select a date after $MaxStartDate" -ForegroundColor Red
            return
        }
    }
    catch
    {
        Write-Host "`nNot a valid date" -ForegroundColor Red
    }
}

# Getting end date to export audit report
while ($true)
{
    if ($EndDate -eq $null)
    {
        $EndDate = Read-Host "Enter End time for report generation '(Eg: 12/15/2023)'"
    }
    try
    {
        $Date = [DateTime]$EndDate
        if ($EndDate -lt ($StartDate))
        {
            Write-Host "End time should be later than start time" -ForegroundColor Red
            return
        }
        break
    }
    catch
    {
        Write-Host "`nNot a valid date" -ForegroundColor Red
    }
}

Function Connect_Exo
{
    # Check for EXO module installation
    $Module = Get-Module ExchangeOnlineManagement -ListAvailable
    if ($Module.count -eq 0) 
    { 
        Write-Host "Exchange Online PowerShell module is not available" -ForegroundColor Yellow  
        $Confirm = Read-Host "Are you sure you want to install module? [Y] Yes [N] No"
        if ($Confirm -match "[yY]") 
        { 
            Write-host "Installing Exchange Online PowerShell module"
            Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force
        } 
        else 
        { 
            Write-Host "EXO module is required to connect Exchange Online. Please install module using Install-Module ExchangeOnlineManagement cmdlet." 
            Exit
        }
    } 

    Write-Host "Connecting to Exchange Online..."
    if (($AdminName -ne "") -and ($Password -ne ""))
    {
        $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
        $Credential  = New-Object System.Management.Automation.PSCredential $AdminName,$SecuredPassword
        Connect-ExchangeOnline -Credential $Credential -ShowBanner:$false
    }
    elseif ($Organization -ne "" -and $ClientId -ne "" -and $CertificateThumbprint -ne "")
    {
        Connect-ExchangeOnline -AppId $ClientId -CertificateThumbprint $CertificateThumbprint  -Organization $Organization -ShowBanner:$false
    }
    else
    {
        Connect-ExchangeOnline -ShowBanner:$false
    }
}

$Location = Get-Location
$OutputCSV = "$Location\ExternalSharingReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv" 
$IntervalTimeInMinutes = 1440
$CurrentStart = $StartDate
$CurrentEnd = $CurrentStart.AddMinutes($IntervalTimeInMinutes)

# Check whether CurrentEnd exceeds EndDate
if ($CurrentEnd -gt $EndDate)
{
    $CurrentEnd = $EndDate
}

if ($CurrentStart -eq $CurrentEnd)
{
    Write-Host "Start and end time are same. Please enter different time range" -ForegroundColor Red
    Exit
}

Connect_Exo
$AggregateResults = @()
$CurrentResult = @()
$CurrentResultCount = 0
$AggregateResultCount = 0
Write-Host "`nRetrieving external sharing events from $StartDate to $EndDate..."
$ProcessedAuditCount = 0
$OutputEvents = 0
$ExportResult = ""   
$ExportResults = @()  

while ($true)
{ 
    $Results = Search-UnifiedAuditLog -StartDate $CurrentStart -EndDate $CurrentEnd -Operations "Sharinginvitationcreated,AnonymousLinkcreated,AddedToSecureLink" -SessionId s -SessionCommand ReturnLargeSet -ResultSize 5000
    $ResultCount = ($Results | Measure-Object).count
    foreach ($Result in $Results)
    {
        $ProcessedAuditCount++
        $MoreInfo = $Result.auditdata
        $Operation = $Result.Operations
        $AuditData = $Result.auditdata | ConvertFrom-Json
        $Workload = $AuditData.Workload

        # Filter for SharePointOnline or OneDrive external sharing events
        if ($SharePointOnline.IsPresent -and ($Workload -eq "OneDrive")) { continue }
        if ($OneDrive.IsPresent -and ($Workload -eq "SharePoint")) { continue }

        # Check for Guest sharing
        if ($Operation -ne "AnonymousLinkcreated")
        {
            if ($AuditData.TargetUserOrGroupType -ne "Guest") { continue }
            $SharedWith = $AuditData.TargetUserOrGroupName
        }
        else
        {
            $SharedWith = "Anyone with the link can access"
        }

        $ActivityTime = Get-Date($AuditData.CreationTime) -format g
        $SharedBy = $AuditData.userId
        $SharedResourceType = $AuditData.ItemType
        $SharedResource = $AuditData.ObjectId
        $SiteURL = $AuditData.SiteURL

        # Export result to CSV
        $OutputEvents++
        $ExportResult = @{
            'Shared Time'        = $ActivityTime
            'Sharing Type'       = $Operation
            'Shared By'          = $SharedBy
            'Shared With'        = $SharedWith
            'Shared Resource Type' = $SharedResourceType
            'Shared Resource'    = $SharedResource
            'Site URL'           = $SiteURL
            'Workload'           = $Workload
            'More Info'          = $MoreInfo
        }
        $ExportResults = New-Object PSObject -Property $ExportResult  
        $ExportResults | Select-Object 'Shared Time','Shared By','Shared With','Shared Resource Type','Shared Resource','Site URL','Sharing Type','Workload','More Info' | Export-Csv -Path $OutputCSV -NoTypeInformation -Append 
    }

    Write-Progress -Activity "`n     Retrieving external sharing events from $CurrentStart to $CurrentEnd.."`n" -Status "Processed audit record count: $ProcessedAuditCount"
    $CurrentResultCount += $ResultCount

    if ($CurrentResultCount -ge 50000)
    {
        Write-Host "Retrieved max record for current range. Proceeding further may cause data loss or rerun the script with reduced time interval." -ForegroundColor Red
        $Confirm = Read-Host "`nAre you sure you want to continue? [Y] Yes [N] No"
        if ($Confirm -match "[Y]")
        {
            Write-Host "Proceeding audit log collection with possible data loss"
            [DateTime]$CurrentStart = $CurrentEnd
            [DateTime]$CurrentEnd = $CurrentStart.AddMinutes($IntervalTimeInMinutes)
            $CurrentResultCount = 0
            $CurrentResult = @()
            if ($CurrentEnd -gt $EndDate) { $CurrentEnd = $EndDate }
        }
        else
        {
            Write-Host "Please rerun the script with reduced time interval" -ForegroundColor Red
            Exit
        }
    }

    if ($Results.count -lt 5000)
    {
        if ($CurrentEnd -eq $EndDate) { break }
        $CurrentStart = $CurrentEnd 
        if ($CurrentStart -gt (Get-Date)) { break }
        $CurrentEnd = $CurrentStart.AddMinutes($IntervalTimeInMinutes)
        $CurrentResultCount = 0
        $CurrentResult = @()
        if ($CurrentEnd -gt $EndDate) { $CurrentEnd = $EndDate }
    }
}

if ($OutputEvents -eq 0)
{
    Write-Host "No records found"
}
else
{
    Write-Host "`nThe output file contains $OutputEvents audit records"
    if (Test-Path -Path $OutputCSV) 
    {
        Write-Host "`n The Output file available in:" -NoNewline -ForegroundColor Yellow
        Write-Host $OutputCSV
        Write-Host "`n~~ Script prepared by Ryan Adams ~~`n" -ForegroundColor Green
        Write-Host "~~ Check out " -NoNewline -ForegroundColor Green
        Write-Host "https://pastebin.com/u/Removed_Content" -ForegroundColor Yellow -NoNewline
        Write-Host " for sample scripts and resources. ~~" -ForegroundColor Green `n`n
        $Prompt = New-Object -ComObject wscript.shell   
        $UserInput = $Prompt.popup("Do you want to open output file?", 0, "Open Output File", 4)   
        if ($UserInput -eq 6) { Invoke-Item "$OutputCSV" }
    }
}

# Disconnect Exchange Online session
Disconnect-ExchangeOnline -Confirm:$false -InformationAction Ignore -ErrorAction SilentlyContinue
