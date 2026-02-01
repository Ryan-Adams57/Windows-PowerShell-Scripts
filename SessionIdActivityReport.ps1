<#
=============================================================================================
Name:           Trace Session ID–Based Activities Across Microsoft 365
Description:    Retrieves audit activities associated with a specific session ID
                and exports the results to a CSV file.

Script Highlights:
1. Retrieves all activities performed during a specific session (up to 180 days).
2. Generates a structured, user-friendly CSV report.
3. Supports certificate-based authentication (CBA).
============================================================================================
#>

Param
(
    [Parameter(Mandatory = $false)]
    [Nullable[DateTime]]$StartDate,
    [Nullable[DateTime]]$EndDate,
    [string]$UserId,
    [string]$SessionId,
    [string]$Organization,
    [string]$ClientId,
    [string]$CertificateThumbprint,
    [string]$AdminName,
    [string]$Password
)

# Check for Exchange Online module installation
$Module = Get-Module ExchangeOnlineManagement -ListAvailable
if ($Module.Count -eq 0)
{ 
    Write-Host "Exchange Online PowerShell module is not available" -ForegroundColor Yellow  
    $Confirm = Read-Host "Are you sure you want to install the module? [Y] Yes [N] No"
    if ($Confirm -match "[yY]")
    { 
        Write-Host "Installing Exchange Online PowerShell module"
        Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force
    } 
    else
    { 
        Write-Host "Exchange Online module is required to run this script."
        Exit
    }
}

Write-Host "Connecting to Exchange Online..."

# Authentication options
if (($AdminName) -and ($Password))
{
    $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
    $Credential = New-Object System.Management.Automation.PSCredential $AdminName, $SecuredPassword
    Connect-ExchangeOnline -Credential $Credential
}
elseif (($Organization) -and ($ClientId) -and ($CertificateThumbprint))
{
    Connect-ExchangeOnline -AppId $ClientId `
        -CertificateThumbprint $CertificateThumbprint `
        -Organization $Organization `
        -ShowBanner:$false
}
else
{
    Connect-ExchangeOnline
}

$MaxStartDate = ((Get-Date).AddDays(-179)).Date

# Default date range (last 180 days)
if (($StartDate -eq $null) -and ($EndDate -eq $null))
{
    $EndDate = (Get-Date).Date
    $StartDate = $MaxStartDate
}

# Validate start date
while ($true)
{
    if ($StartDate -eq $null)
    {
        $StartDate = Read-Host "Enter start date (Eg: 12/15/2023)"
    }
    try
    {
        if ([DateTime]$StartDate -ge $MaxStartDate) { break }
        Write-Host "Audit data is available only for the past 180 days." -ForegroundColor Red
        return
    }
    catch
    {
        Write-Host "Not a valid date" -ForegroundColor Red
    }
}

# Validate end date
while ($true)
{
    if ($EndDate -eq $null)
    {
        $EndDate = Read-Host "Enter end date (Eg: 12/15/2023)"
    }
    try
    {
        if ($EndDate -lt $StartDate)
        {
            Write-Host "End date must be later than start date." -ForegroundColor Red
            return
        }
        break
    }
    catch
    {
        Write-Host "Not a valid date" -ForegroundColor Red
    }
}

$Location = Get-Location
$OutputCSV = "$Location\SessionId_Activity_Report_$((Get-Date -Format 'yyyy-MMM-dd-ddd hh-mm tt')).csv"

$IntervalTimeInMinutes = 1440
$CurrentStart = $StartDate
$CurrentEnd = $CurrentStart.AddMinutes($IntervalTimeInMinutes)
if ($CurrentEnd -gt $EndDate) { $CurrentEnd = $EndDate }

Write-Host "`nRetrieving session ID–based activity from $StartDate to $EndDate..." -ForegroundColor Yellow

# Prompt for required inputs
if (-not $SessionId)
{
    $SessionId = Read-Host "Enter Session ID"
}
if (-not $UserId)
{
    $UserId = Read-Host "Enter user UPN"
}

$i = 0
$AggregateResultCount = 0

while ($true)
{
    if ($CurrentStart -eq $CurrentEnd)
    {
        Write-Host "Start and end time cannot be the same." -ForegroundColor Red
        Exit
    }

    $Results = Search-UnifiedAuditLog `
        -StartDate $CurrentStart `
        -EndDate $CurrentEnd `
        -UserIds $UserId `
        -FreeText $SessionId `
        -SessionId s `
        -SessionCommand ReturnLargeSet `
        -ResultSize 5000

    foreach ($Result in $Results)
    {
        $i++
        $AuditData = $Result.AuditData | ConvertFrom-Json

        [PSCustomObject]@{
            'Activity Time' = (Get-Date $AuditData.CreationTime -Format g)
            'User Name'     = $AuditData.UserId
            'Operation'     = $AuditData.Operation
            'Result'        = $AuditData.ResultStatus
            'Workload'      = $AuditData.Workload
            'More Info'     = $Result.AuditData
        } | Export-Csv -Path $OutputCSV -NoTypeInformation -Append
    }

    Write-Progress -Activity "Retrieving audit data..." `
        -Status "Processed audit record count: $i"

    if ($Results.Count -lt 5000)
    {
        if ($CurrentEnd -eq $EndDate) { break }
        $CurrentStart = $CurrentEnd
        $CurrentEnd = $CurrentStart.AddMinutes($IntervalTimeInMinutes)
        if ($CurrentEnd -gt $EndDate) { $CurrentEnd = $EndDate }
    }
}

$AggregateResultCount = $i

if ($AggregateResultCount -eq 0)
{
    Write-Host "No records found."
}
else
{
    Write-Host "`nThe output file contains $AggregateResultCount audit records."
    Write-Host "Output file location:" -ForegroundColor Yellow
    Write-Host $OutputCSV

    $Prompt = New-Object -ComObject wscript.shell
    if ($Prompt.Popup("Do you want to open the output file?", 0, "Open Output File", 4) -eq 6)
    {
        Invoke-Item $OutputCSV
    }
}

Disconnect-ExchangeOnline -Confirm:$false | Out-Null
