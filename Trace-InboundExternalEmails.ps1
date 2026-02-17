<#
=============================================================================================
Name:           Trace Inbound External Emails in Exchange Online
Version:        1.1
Author:         Ryan Adams
Website:        https://www.governmentcontrol.net/

Script Highlights:  
~~~~~~~~~~~~~~~~~
1. Exports emails received from external domains into a CSV file.
2. Supports exporting emails within a specified 90-day time range.
3. Lists emails received from a specific external domain.
4. Finds emails received from a specific external user.
5. Audits emails received by a specific user from external domains.
6. Allows filtering the mail flow report based on mail status.
7. Automatically verifies and installs the Exchange Online PowerShell module (if not installed) upon confirmation.
8. Supports MFA and Certificate-based Authentication.
9. Scheduler-friendly.

For detailed script execution: 
GitHub - https://github.com/Ryan-Adams57
Gitlab - https://gitlab.com/Ryan-Adams57
PasteBin - https://pastebin.com/u/Removed_Content

Change Log
~~~~~~~~~~

    V1.0 (Jun 03, 2025) - File created
    V1.1 (Jun 09, 2025) - Extended message tracing period from 30 to 90 days.
============================================================================================
#>

param(
    [Parameter(Mandatory = $false)]
    [Nullable[DateTime]]$StartDate,
    [Nullable[DateTime]]$EndDate,
    [string]$UserName,
    [string]$Password,
    [string]$SenderAddress = "",
    [string]$RecipientAddress = "",
    [ValidateSet("Delivered", "Failed", "Gettingstatus", "FilteredAsSpam","Quarantined")]
    [string]$MailStatus,
    [string]$ExternalDomainName,
    [string]$Organization,
    [string]$ClientId,
    [string]$CertificateThumbprint
)

#--------------------------------------------------- Date Time Checking ---------------------------------------------------
$MaxStartDate = ((Get-Date).AddDays(-90)).Date

if (-not $StartDate -and -not $EndDate) {
    $EndDate = (Get-Date).Date
    $StartDate = $MaxStartDate
}

try {
    if ($StartDate) { $StartDate = [DateTime]$StartDate }
    if ($EndDate) { $EndDate = [DateTime]$EndDate }

    if ($StartDate -lt $MaxStartDate) {
        Write-Host "Error: MessageTrace can only be retrieved for the past 90 days. Select a date after $MaxStartDate" -ForegroundColor Red
        Exit
    }
    if ($EndDate -lt $StartDate) {
        Write-Host "Error: End date must be later than start date." -ForegroundColor Red
        Exit
    }
}
catch {
    Write-Host "Error: Invalid date format. Please enter a valid date." -ForegroundColor Red
    Exit
}

$CurrentStart = $StartDate
$CurrentEnd = $EndDate.AddDays(1).AddSeconds(-1)

#-------------------------------------------------- Function: Connect Exchange Online --------------------------------------
Function Connect_Exo {
    $installedModule = Get-Module ExchangeOnlineManagement -ListAvailable | Where-Object { $_.Version -ge [version]"3.0" }

    if (-not $installedModule) {
        Write-Host "Exchange Online PowerShell module is not available or unsupported version is available" -ForegroundColor Yellow
        $confirm = Read-Host "Do you want to install the latest module? [Y] Yes [N] No"
        if ($confirm -match "[yY]") {
            Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force
        }
        else {
            Write-Host "EXO module is required. Please install it manually using 'Install-Module ExchangeOnlineManagement'."
            exit
        }
    }

    Write-Host "Connecting to Exchange Online..."
    
    if ($UserName -and $Password) {
        $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
        $Credential = New-Object System.Management.Automation.PSCredential ($UserName, $SecuredPassword)
        Connect-ExchangeOnline -Credential $Credential -ShowBanner:$false
    }
    elseif($Organization -ne "" -and $ClientId -ne "" -and $CertificateThumbprint -ne "") {
        Connect-ExchangeOnline -AppId $ClientId -CertificateThumbprint $CertificateThumbprint -Organization $Organization -ShowBanner:$false
    }
    else {
        Connect-ExchangeOnline -ShowBanner:$false
    }
}

#-------------------------------------------------- Function: Export To CSV -----------------------------------------------
Function Export-ToCSV {
    param (
        [Parameter(Mandatory = $true)]
        $Results
    )

    $Results | 
    Select-Object MessageTraceID, 
    @{Name = "Received Time"; Expression = { ($_.Received).ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss") } }, 
    @{Name = "Sender Address"; Expression = { $_.SenderAddress } }, 
    @{Name = "Recipient Address"; Expression = { $_.RecipientAddress } }, 
    Subject, Status,
    @{Name = "Sender Domain"; Expression = { ($_.SenderAddress -split "@")[1] } },  
    @{Name = "Recipient Domain"; Expression = { ($_.RecipientAddress -split "@")[1] } },
    @{Name = "Sender IP"; Expression = { $_.FromIP } }, 
    @{Name = "Receipient IP"; Expression = { $_.ToIP } }, 
    @{Name = "Mail Size(KB)"; Expression = { [math]::Round($_.Size / 1KB, 2) } } | 
    Export-Csv -Path $OutputCSV -Append -Force -NoTypeInformation
}

#-------------------------------------------------- Function: Filter Data --------------------------------------------------
Function Filterdata {
    $FilteredResults = @()

    foreach ($queryResult in $queryResults) {
        $senderDomain = ($queryResult.SenderAddress -split "@")[-1]
        $recipientDomain = ($queryResult.RecipientAddress -split "@")[-1]

        if (
        ($InternalDomains -contains $recipientDomain) -and
        (-not ($InternalDomains -contains $senderDomain)) -and
        ([string]::IsNullOrEmpty($SenderAddress) -or $queryResult.SenderAddress -eq $SenderAddress) -and
        ([string]::IsNullOrEmpty($RecipientAddress) -or $queryResult.RecipientAddress -eq $RecipientAddress) -and
        ([string]::IsNullOrEmpty($ExternalDomainName) -or $ExternalDomainName -eq $SenderDomain) -and
        ([string]::IsNullOrEmpty($MailStatus) -or $queryResult.Status -eq $MailStatus)
        ) {
            $FilteredResults += $queryResult
        }
    }

    if ($FilteredResults.Count -gt 0) {
        $Global:FilteredCount += $FilteredResults.Count
        Export-ToCSV -Results $FilteredResults
    }
}

#-------------------------------------------------- Initialization ---------------------------------------------------------
Connect_Exo
$batchSize = 5000
$InternalDomains = (Get-AcceptedDomain).DomainName
$Location = Get-Location
$Timestamp = (Get-Date -Format "yyyy-MM-dd_HH-mm-ss")
$OutputCSV = "$Location\MailsReceivedFromExternalDomain_Report_$Timestamp.csv"
$queryResults = $null
$ProcessedCount = 0
$Global:FilteredCount = 0

#-------------------------------------------------- Core Processing Loop ---------------------------------------------------
while ($CurrentEnd -ge $CurrentStart) {
    $IntervalStartDate = $CurrentEnd.AddDays(-10)

    if ($IntervalStartDate -lt $CurrentStart) { $IntervalStartDate = $CurrentStart }  
    if ($IntervalStartDate -ge $CurrentEnd) { break } 

    try {
        $queryResults = Get-MessageTraceV2 -StartDate $IntervalStartDate -EndDate $CurrentEnd -ResultSize $batchSize -ErrorAction Stop
        $ProcessedCount += $queryResults.Count

        if ($queryResults.Count -eq 0) {
            $CurrentEnd = $IntervalStartDate
            continue
        }

        Filterdata
    }
    catch {
        Write-Host "Error fetching message trace data: $_" -ForegroundColor Red
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
        Exit
    }

    Write-Progress -Activity "Retrieving Mail Record from $StartDate to $EndDate" -Status "Processed count: $ProcessedCount"

    while ($queryResults.Count -eq $batchSize) {
        $lastMessage = $queryResults[-1]
        $LastEndDate = $lastMessage.Received.ToString("O")
        $StartingRecipientAddress = $lastMessage.RecipientAddress

        try {
            $queryResults = Get-MessageTraceV2 -StartDate $IntervalStartDate -EndDate $LastEndDate -StartingRecipientAddress $StartingRecipientAddress -ResultSize $batchSize -ErrorAction Stop
            $ProcessedCount += $queryResults.Count
            Write-Progress -Activity "Retrieving Mail Record from $StartDate to $EndDate" -Status "Processed count: $ProcessedCount"
            if ($queryResults.Count -eq 0) { break }
            Filterdata
        }
        catch {
            Write-Host "Error fetching additional message trace data: $_" -ForegroundColor Red
            Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
            Exit
        }
    }

    $CurrentEnd = $IntervalStartDate
}

#-------------------------------------------------- Final Output -----------------------------------------------------------
Write-Host "`n~~ Script prepared by Ryan Adams ~~`n" -ForegroundColor Green
Write-Host "Check out: GitHub - https://github.com/Ryan-Adams57 | Gitlab - https://gitlab.com/Ryan-Adams57 | PasteBin - https://pastebin.com/u/Removed_Content" -ForegroundColor Green

If ($FilteredCount -eq 0) {
    Write-Host "No records found"
}
else {
    Write-Host "`nThe output file contains $FilteredCount mail records."
    if (Test-Path -Path $OutputCSV) {
        Write-Host "`nThe Output file is available at: " -NoNewline -ForegroundColor Yellow
        Write-Host $OutputCSV
        $Prompt = New-Object -ComObject wscript.shell
        $UserInput = $Prompt.popup("Do you want to open the output file?", 0, "Open Output File", 4)
        If ($UserInput -eq 6) {
            Invoke-Item "$OutputCSV"
        }
    }
}

Disconnect-ExchangeOnline -Confirm:$false
