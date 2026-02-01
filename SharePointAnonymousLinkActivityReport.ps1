<#
=============================================================================================
Name:           SharePoint Online Anonymous Link Activity Report
Description:    This script exports SharePoint Online anonymous link activities report to CSV
Version:        1.0

Script Highlights: 
~~~~~~~~~~~~~~~~~
1. Allow to generate different anonymous link reports. 
2. Uses modern authentication to retrieve audit logs.   
3. Can be executed with MFA enabled accounts.   
4. Exports report results to CSV file.   
5. Automatically installs the EXO V2 module (if not installed already) upon confirmation.  
6. Scheduler friendly (credentials can be passed as parameters). 
============================================================================================
#>

Param
(
    [Parameter(Mandatory = $false)]
    [Nullable[DateTime]]$StartDate,
    [Nullable[DateTime]]$EndDate,
    [switch]$SharePointOnline,
    [switch]$OneDrive,
    [switch]$AnonymousSharing,
    [switch]$AnonymousAccess,
    [string]$AdminName,
    [string]$Password
)

Function Connect_Exo
{
    # Check for EXO v2 module installation
    $Module = Get-Module ExchangeOnlineManagement -ListAvailable
    if ($Module.Count -eq 0)
    { 
        Write-Host "Exchange Online PowerShell V2 module is not available" -ForegroundColor Yellow  
        $Confirm = Read-Host "Are you sure you want to install module? [Y] Yes [N] No"
        if ($Confirm -match "[yY]")
        { 
            Write-Host "Installing Exchange Online PowerShell module"
            Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force
        } 
        else
        { 
            Write-Host "EXO V2 module is required to connect Exchange Online." 
            Exit
        }
    } 

    Write-Host "`nConnecting to Exchange Online..."

    if (($AdminName -ne "") -and ($Password -ne ""))
    {
        $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
        $Credential = New-Object System.Management.Automation.PSCredential $AdminName,$SecuredPassword
        Connect-ExchangeOnline -Credential $Credential
    }
    else
    {
        Connect-ExchangeOnline
    }
}

$MaxStartDate = ((Get-Date).AddDays(-89)).Date

if (($StartDate -eq $null) -and ($EndDate -eq $null))
{
    $EndDate = (Get-Date).Date
    $StartDate = $MaxStartDate
}

while ($true)
{
    if ($StartDate -eq $null)
    {
        $StartDate = Read-Host "Enter start time for report generation (Eg: 04/28/2021)"
    }
    try
    {
        $Date = [DateTime]$StartDate
        if ($Date -ge $MaxStartDate) { break }
        Write-Host "Anonymous activity report can be retrieved only for past 90 days." -ForegroundColor Red
        return
    }
    catch
    {
        Write-Host "Not a valid date" -ForegroundColor Red
    }
}

while ($true)
{
    if ($EndDate -eq $null)
    {
        $EndDate = Read-Host "Enter end time for report generation (Eg: 04/28/2021)"
    }
    try
    {
        if ($EndDate -lt $StartDate)
        {
            Write-Host "End time should be later than start time" -ForegroundColor Red
            return
        }
        break
    }
    catch
    {
        Write-Host "Not a valid date" -ForegroundColor Red
    }
}

$OutputCSV = ".\AnonymousLinksActivityReport_$((Get-Date -Format 'yyyy-MMM-dd-ddd hh-mm tt')).csv"
$IntervalTimeInMinutes = 1440
$CurrentStart = $StartDate
$CurrentEnd = $CurrentStart.AddMinutes($IntervalTimeInMinutes)

if ($CurrentEnd -gt $EndDate) { $CurrentEnd = $EndDate }
if ($CurrentStart -eq $CurrentEnd)
{
    Write-Host "Start and end time are the same." -ForegroundColor Red
    Exit
}

Connect_Exo

$ProcessedAuditCount = 0
$OutputEvents = 0

if ($AnonymousSharing.IsPresent)
{
    $RetrieveOperation = "AnonymousLinkCreated"
}
elseif ($AnonymousAccess.IsPresent)
{
    $RetrieveOperation = "AnonymousLinkUsed"
}
else
{
    $RetrieveOperation = "AnonymousLinkRemoved,AnonymousLinkCreated,AnonymousLinkUpdated,AnonymousLinkUsed"
}

while ($true)
{
    $Results = Search-UnifiedAuditLog -StartDate $CurrentStart -EndDate $CurrentEnd `
        -Operations $RetrieveOperation -SessionId s -SessionCommand ReturnLargeSet -ResultSize 5000

    foreach ($Result in $Results)
    {
        $ProcessedAuditCount++
        $AuditData = $Result.AuditData | ConvertFrom-Json
        $Workload = $AuditData.Workload

        if ($SharePointOnline.IsPresent -and $Workload -eq "OneDrive") { continue }
        if ($OneDrive.IsPresent -and $Workload -eq "SharePoint") { continue }

        $EditEnabled = "NA"
        if ($Result.Operations -ne "AnonymousLinkUsed")
        {
            $EditEnabled = if ($AuditData.EventData -like "*View*") { "False" } else { "True" }
        }

        $ExportObject = [PSCustomObject]@{
            'Activity Time'             = (Get-Date $AuditData.CreationTime -Format g)
            'Activity'                  = $Result.Operations
            'Performed By'              = $AuditData.UserId
            'User IP'                   = $AuditData.ClientIP
            'Resource Type'             = $AuditData.ItemType
            'Shared/Accessed Resource'  = $AuditData.ObjectId
            'Edit Enabled'              = $EditEnabled
            'Site URL'                  = $AuditData.SiteURL
            'Workload'                  = $Workload
            'More Info'                 = $Result.AuditData
        }

        $ExportObject | Export-Csv -Path $OutputCSV -NoTypeInformation -Append
        $OutputEvents++
    }

    if ($Results.Count -lt 5000)
    {
        if ($CurrentEnd -eq $EndDate) { break }
        $CurrentStart = $CurrentEnd
        $CurrentEnd = $CurrentStart.AddMinutes($IntervalTimeInMinutes)
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
    Write-Host "Output file location:" -ForegroundColor Yellow
    Write-Host $OutputCSV
}

# Disconnect-ExchangeOnline -Confirm:$false -InformationAction Ignore -ErrorAction SilentlyContinue
