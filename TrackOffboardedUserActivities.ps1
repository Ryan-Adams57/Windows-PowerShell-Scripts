<#
=============================================================================================
Name:           Track Offboarded User Activities in Microsoft 365 using PowerShell 
Version:        1.0
Author:         Ryan Adams
Website:        https://www.governmentcontrol.net/

Script Highlights:
~~~~~~~~~~~~~~~~~
1. The script uses modern authentication to connect to Exchange Online.  
2. Supports execution with MFA-enabled accounts.  
3. Exports report results to CSV file.  
4. Retrieves audit logs for the past 180 days by default.
5. Allows custom audit log periods.  
6. Automatically installs the EXO module (if not installed already) upon confirmation. 
7. Scheduler-friendly: Credential can be passed as a parameter. 
8. Supports Certificate-based authentication (CBA).

For detailed execution examples and guidance, see:
GitHub - https://github.com/Ryan-Adams57
Gitlab - https://gitlab.com/Ryan-Adams57
PasteBin - https://pastebin.com/u/Removed_Content
============================================================================================
#>

Param
(
    [Parameter(Mandatory = $false)]
    [Nullable[DateTime]]$StartDate,
    [Nullable[DateTime]]$EndDate,
    [string]$UserID,
    [string]$Organization,
    [string]$ClientId,
    [string]$CertificateThumbprint,
    [string]$AdminName,
    [string]$Password
)

# Check for EXO module installation
$Module = Get-Module ExchangeOnlineManagement -ListAvailable
if ($Module.count -eq 0) 
{ 
    Write-Host "Exchange Online PowerShell module is not available" -ForegroundColor Yellow  
    $Confirm = Read-Host "Do you want to install the module? [Y] Yes [N] No" 
    if ($Confirm -match "[yY]") 
    { 
        Write-Host "Installing Exchange Online PowerShell module"
        Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force -Scope CurrentUser
    } 
    else 
    { 
        Write-Host "EXO module is required to connect Exchange Online. Please install manually."
        Exit
    }
} 

Write-Host "Connecting to Exchange Online..."

# Authentication using credential or certificate
if (($UserName -ne "") -and ($Password -ne ""))
{
    $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
    $Credential  = New-Object System.Management.Automation.PSCredential $UserName,$SecuredPassword
    Connect-ExchangeOnline -Credential $Credential
}
elseif ($Organization -ne "" -and $ClientId -ne "" -and $CertificateThumbprint -ne "")
{
    Connect-ExchangeOnline -AppId $ClientId -CertificateThumbprint $CertificateThumbprint -Organization $Organization -ShowBanner:$false
}
else
{
    Connect-ExchangeOnline
}

$MaxStartDate = ((Get-Date).AddDays(-179)).Date

# Set default audit log range
if (($null -eq $StartDate) -and ($null -eq $EndDate))
{
    $EndDate = (Get-Date).Date
    $StartDate = $MaxStartDate
}

# Validate StartDate
While ($true)
{
    if ($null -eq $StartDate)
    {
        $StartDate = Read-Host "Enter start time for report generation (Eg: 12/15/2023)"
    }
    Try
    {
        $Date = [DateTime]$StartDate
        if ($Date -ge $MaxStartDate)
        { 
            break
        }
        else
        {
            Write-Host "`nAudit logs can only be retrieved for the past 180 days. Please select a date after $MaxStartDate" -ForegroundColor Red
            return
        }
    }
    Catch
    {
        Write-Host "`nNot a valid date" -ForegroundColor Red
    }
}

# Validate EndDate
While ($true)
{
    if ($null -eq $EndDate)
    {
        $EndDate = Read-Host "Enter end time for report generation (Eg: 12/15/2023)"
    }
    Try
    {
        $Date = [DateTime]$EndDate
        if ($EndDate -lt ($StartDate))
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

$OutputCSV = ".\$UserId`_ActivityLogReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv" 
$IntervalTimeInMinutes = 1440
$CurrentStart = $StartDate
$CurrentEnd = $CurrentStart.AddMinutes($IntervalTimeInMinutes)

if ($CurrentEnd -gt $EndDate)
{
    $CurrentEnd = $EndDate
}

if ($UserID -eq "")
{
    $UserID = Read-Host "Enter user UPN (eg: John@contoso.com)"
}

Write-Host "~~~~~~~"
$CurrentResultCount = 0
$AggregateResultCount = 0
Write-Host "`nRetrieving user activity log from $StartDate to $EndDate..." -ForegroundColor Yellow

$Count = 0
$ExportResult = ""   
$ExportResults = @()  

while ($true)
{ 
    if ($CurrentStart -eq $CurrentEnd)
    {
        Write-Host "Start and end time are the same. Please enter a different time range" -ForegroundColor Red
        Exit
    }

    $Results = Search-UnifiedAuditLog -StartDate $CurrentStart -EndDate $CurrentEnd -UserIds $UserID -SessionId s -SessionCommand ReturnLargeSet -ResultSize 5000
    $ResultCount = ($Results | Measure-Object).Count

    foreach ($Result in $Results)
    {
        $Count++
        $MoreInfo = $Result.auditdata
        $AuditData = $Result.auditdata | ConvertFrom-Json
        $ActivityTime = Get-Date($AuditData.CreationTime) -format g
        $UserID = $AuditData.userId
        $Operation = $AuditData.Operation
        $ResultStatus = $AuditData.ResultStatus
        $Workload = $AuditData.Workload

        $ExportResult = @{
            'Activity Time' = $ActivityTime
            'User Name'     = $UserID
            'Operation'     = $Operation
            'Result'        = $ResultStatus
            'Workload'      = $Workload
            'More Info'     = $MoreInfo
        }

        $ExportResults = New-Object PSObject -Property $ExportResult  
        $ExportResults | Select-Object 'Activity Time','User Name','Operation','Result','Workload','More Info' | Export-Csv -Path $OutputCSV -NoTypeInformation -Append 
    }

    Write-Progress -Activity "`n     Retrieving audit log from $StartDate to $EndDate.." -Status "Processed audit record count: $Count"

    $CurrentResultCount = $CurrentResultCount + $ResultCount

    if ($CurrentResultCount -eq 50000)
    {
        Write-Host "Retrieved max record for current range. Consider rerunning with reduced interval." -ForegroundColor Red
        $Confirm = Read-Host "`nDo you want to continue? [Y] Yes [N] No"
        if ($Confirm -match "[Y]")
        {
            $AggregateResultCount += $CurrentResultCount
            Write-Host "Proceeding audit log collection with possible data loss..."
            [DateTime]$CurrentStart = $CurrentEnd
            [DateTime]$CurrentEnd = $CurrentStart.AddMinutes($IntervalTimeInMinutes)
            $CurrentResultCount = 0
            if ($CurrentEnd -gt $EndDate)
            {
                $CurrentEnd = $EndDate
            }
        }
        else
        {
            Write-Host "Please rerun the script with a reduced interval" -ForegroundColor Red
            Exit
        }
    }

    if ($Results.Count -lt 5000)
    {
        $AggregateResultCount += $CurrentResultCount
        if ($CurrentEnd -eq $EndDate)
        {
            break
        }
        $CurrentStart = $CurrentEnd 
        if ($CurrentStart -gt (Get-Date))
        {
            break
        }
        $CurrentEnd = $CurrentStart.AddMinutes($IntervalTimeInMinutes)
        $CurrentResultCount = 0
        if ($CurrentEnd -gt $EndDate)
        {
            $CurrentEnd = $EndDate
        }
    }
}

if ($AggregateResultCount -eq 0)
{
    Write-Host "No records found"
}
else
{
    Write-Host "`nThe output file contains $AggregateResultCount audit records `n"
    if (Test-Path -Path $OutputCSV) 
    {
        Write-Host "Output file available at:" -NoNewline -ForegroundColor Yellow
        Write-Host $OutputCSV
        Write-Host "`n~~ Script prepared by Ryan Adams ~~`n" -ForegroundColor Green
        Write-Host "Check out: GitHub - https://github.com/Ryan-Adams57 | Gitlab - https://gitlab.com/Ryan-Adams57 | PasteBin - https://pastebin.com/u/Removed_Content" -ForegroundColor Green
        $Prompt = New-Object -ComObject wscript.shell   
        $UserInput = $Prompt.popup("Do you want to open the output file?", 0, "Open Output File", 4)   
        If ($UserInput -eq 6)   
        {   
            Invoke-Item "$OutputCSV"   
        } 
    }
}

# Disconnect Exchange Online session
Disconnect-ExchangeOnline -Confirm:$false | Out-Null
