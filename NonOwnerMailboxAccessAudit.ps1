<#
=============================================================================================
Name:           Non-Owner Mailbox Access Audit
Version:        2.0
Website:        https://www.governmentcontrol.net/

Script Highlights: 
~~~~~~~~~~~~~~~~~~

1. Allows filtering out external users’ access. 
2. Can be executed with MFA-enabled accounts.
3. Exports the report to CSV.
4. Scheduler-friendly: credentials can be passed as parameters.
5. Supports date-range audit search.
6. Supports certificate-based authentication.

For detailed script execution: GitHub - https://github.com/Ryan-Adams57

Change Log
~~~~~~~~~~

    V1.0 (Feb 17, 2020) - File created
    V1.1 (Oct 06, 2023) - Minor changes
    V2.0 (Nov 25, 2023) - Added certificate-based authentication support for scheduling
    V2.1 (Sep 24, 2024) - Special handling for SendAs and SendOnBehalf activities
============================================================================================
#>

Param
(
    [Parameter(Mandatory = $false)]
    [Boolean]$IncludeExternalAccess = $false,
    [Nullable[DateTime]]$StartDate,
    [Nullable[DateTime]]$EndDate,
    [string]$Organization,
    [string]$ClientId,
    [string]$CertificateThumbprint,
    [string]$UserName,
    [string]$Password
)

# Validate StartDate and EndDate
if ((($StartDate -eq $null) -and ($EndDate -ne $null)) -or (($StartDate -ne $null) -and ($EndDate -eq $null)))
{
    Write-Host "`nPlease enter both StartDate and EndDate for audit log collection." -ForegroundColor Red
    Exit
}
elseif(($StartDate -eq $null) -and ($EndDate -eq $null))
{
    $StartDate = ((Get-Date).AddDays(-90)).Date
    $EndDate = Get-Date
}
else
{
    $StartDate = [DateTime]$StartDate
    $EndDate = [DateTime]$EndDate
    if($StartDate -lt ((Get-Date).AddDays(-90)))
    {
        Write-Host "`nAudit log can only be retrieved for past 90 days." -ForegroundColor Red
        Exit
    }
    if($EndDate -lt $StartDate)
    {
        Write-Host "`nEnd time must be later than start time." -ForegroundColor Red
        Exit
    }
}

Function Connect_Exo
{
    # Check for Exchange Online module
    $Module = Get-Module ExchangeOnlineManagement -ListAvailable
    if($Module.Count -eq 0) 
    { 
        Write-Host "Exchange Online PowerShell module is not available." -ForegroundColor Yellow
        $Confirm = Read-Host "Do you want to install the module? [Y] Yes [N] No"
        if($Confirm -match "[yY]") 
        { 
            Write-Host "Installing Exchange Online PowerShell module..."
            Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force
        } 
        else 
        { 
            Write-Host "EXO module is required. Please install using Install-Module ExchangeOnlineManagement." -ForegroundColor Red
            Exit
        }
    } 

    Write-Host "Connecting to Exchange Online..."
    if(($UserName -ne "") -and ($Password -ne ""))
    {
        $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
        $Credential = New-Object System.Management.Automation.PSCredential $UserName, $SecuredPassword
        Connect-ExchangeOnline -Credential $Credential -ShowBanner:$false
    }
    elseif(($Organization -ne "") -and ($ClientId -ne "") -and ($CertificateThumbprint -ne ""))
    {
        Connect-ExchangeOnline -AppId $ClientId -CertificateThumbprint $CertificateThumbprint -Organization $Organization -ShowBanner:$false
    }
    else
    {
        Connect-ExchangeOnline -ShowBanner:$false
    }
}

Connect_Exo

$OutputCSV = ".\NonOwner-Mailbox-Access-Report_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"
$IntervalTimeInMinutes = 1440
$CurrentStart = $StartDate
$CurrentEnd = $CurrentStart.AddMinutes($IntervalTimeInMinutes)
$Operation = 'ApplyRecord','Copy','Create','FolderBind','HardDelete','MessageBind','Move','MoveToDeletedItems','RecordDelete','SendAs','SendOnBehalf','SoftDelete','Update','UpdateCalendarDelegation','UpdateFolderPermissions','UpdateInboxRules'

if($CurrentEnd -gt $EndDate)
{
    $CurrentEnd = $EndDate
}

$AggregateResults = 0
$CurrentResult = @()
$CurrentResultCount = 0
$NonOwnerAccess = 0
Write-Host "`nRetrieving audit log from $StartDate to $EndDate..." -ForegroundColor Yellow

while($true)
{
    if($CurrentStart -eq $CurrentEnd)
    {
        Write-Host "Start and end time are the same. Enter a different time range." -ForegroundColor Red
        Exit
    }

    $Results = Search-UnifiedAuditLog -StartDate $CurrentStart -EndDate $CurrentEnd -Operations $Operation -SessionId s -SessionCommand ReturnLargeSet -ResultSize 5000
    $AllAuditData = @()

    foreach($Result in $Results)
    {
        $AuditData = $Result.auditdata | ConvertFrom-Json

        # Remove owner access
        if($AuditData.LogonType -eq 0) { continue }

        # Filter external access
        if(($IncludeExternalAccess -eq $false) -and ($AuditData.ExternalAccess -eq $true)) { continue }

        # Non-owner mailbox access
        if(($AuditData.LogonUserSId -ne $AuditData.MailboxOwnerSid) -or ((($AuditData.Operation -eq "SendAs") -or ($AuditData.Operation -eq "SendOnBehalf")) -and ($AuditData.UserType -eq 0)))
        {
            $AuditData.CreationTime = (Get-Date($AuditData.CreationTime)).ToLocalTime()
            $LogonType = switch ($AuditData.LogonType) {
                1 { "Administrator" }
                2 { "Delegated" }
                default { "Microsoft datacenter" }
            }

            if($AuditData.Operation -eq "SendAs")
            {
                $AccessedMB = $AuditData.SendAsUserSMTP
                $AccessedBy = $AuditData.UserId
            }
            elseif($AuditData.Operation -eq "SendOnBehalf")
            {
                $AccessedMB = $AuditData.SendOnBehalfOfUserSmtp
                $AccessedBy = $AuditData.UserId
            }
            else
            {
                $AccessedMB = $AuditData.MailboxOwnerUPN
                $AccessedBy = $AuditData.UserId
            }

            if($AccessedMB -eq $AccessedBy) { continue }

            $NonOwnerAccess++
            $AllAudits = @{
                'Access Time' = $AuditData.CreationTime
                'Accessed by' = $AccessedBy
                'Performed Operation' = $AuditData.Operation
                'Accessed Mailbox' = $AccessedMB
                'Logon Type' = $LogonType
                'Result Status' = $AuditData.ResultStatus
                'External Access' = $AuditData.ExternalAccess
                'More Info' = $Result.auditdata
            }

            $AllAuditData = New-Object PSObject -Property $AllAudits
            $AllAuditData | Sort 'Access Time','Accessed by' | Select 'Access Time','Logon Type','Accessed by','Performed Operation','Accessed Mailbox','Result Status','External Access','More Info' | Export-Csv $OutputCSV -NoTypeInformation -Append
        }
    }

    $CurrentResultCount += $Results.Count
    $AggregateResults += $Results.Count
    Write-Progress -Activity "`nRetrieving audit log for $CurrentStart: $CurrentResultCount records"`n" Total processed audit record count: $AggregateResults"

    if(($CurrentResultCount -eq 50000) -or ($Results.Count -lt 5000))
    {
        if($CurrentResultCount -eq 50000)
        {
            Write-Host "Retrieved max records for current range. Proceeding may cause data loss." -ForegroundColor Red
            $Confirm = Read-Host "`nDo you want to continue? [Y] Yes [N] No"
            if($Confirm -notmatch "[Y]")
            {
                Write-Host "Please rerun with reduced time interval." -ForegroundColor Red
                Exit
            }
            else
            {
                Write-Host "Proceeding with potential data loss."
            }
        }

        if($CurrentEnd -eq $EndDate) { break }

        $CurrentStart = $CurrentEnd
        if($CurrentStart -gt (Get-Date)) { break }

        $CurrentEnd = $CurrentStart.AddMinutes($IntervalTimeInMinutes)
        if($CurrentEnd -gt $EndDate) { $CurrentEnd = $EndDate }

        $CurrentResultCount = 0
        $CurrentResult = @()
    }
}

Write-Host "`n~~ Script prepared by Ryan Adams ~~`n" -ForegroundColor Green
Write-Host "~~ Check out " -NoNewline -ForegroundColor Green
Write-Host "GitHub - https://github.com/Ryan-Adams57" -ForegroundColor Yellow -NoNewline
Write-Host " for more reporting scripts. ~~" -ForegroundColor Green

if($AggregateResults -eq 0)
{
    Write-Host "No records found"
}
else
{
    Write-Host "`nThe output file contains $NonOwnerAccess audit records"
    if(Test-Path $OutputCSV)
    {
        Write-Host "`nThe output file available in:" -NoNewline -ForegroundColor Yellow
        Write-Host " $OutputCSV"
        $Prompt = New-Object -ComObject wscript.shell
        $UserInput = $Prompt.popup("Do you want to open output file?", 0, "Open Output File", 4)
        if ($UserInput -eq 6) { Invoke-Item "$OutputCSV" }
    }
}

Disconnect-ExchangeOnline -Confirm:$false
