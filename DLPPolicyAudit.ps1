<#
=============================================================================================
Name:           Audit DLP Policy Matches in Microsoft 365 
Version:        1.0

Script Highlights:  
~~~~~~~~~~~~~~~~~  
1. Tracks DLP rules matched Microsoft Teams messages. 
2. Audits SharePoint shared contents for DLP rule violations. 
3. Identifies sensitive info shared through OneDrive files.   
4. Monitors Exchange Email messages flagged by DLP policies.  
5. This script retrieves DLP audit log for the last 180 days by default. 
6. Helps to generate DLP audit reports for custom periods. 
7. Monitors sensitive information shared by a specific user.  
8. Lists DLP policy detections for targeted policy. 
9. Can export DLP policy rule matches based on alerts severity (High, Medium, Low).  
10. Exports report results to CSV file. 
11. The script can be executed with an MFA-enabled account too. 
12. Supports Certificate-based Authentication too. 
13. Automatically installs the EXO Module (if not installed already) upon your confirmation. 
14. This script is scheduler friendly.
============================================================================================
#>
param (
    [Parameter(Mandatory = $false)]
    [string[]]$TargetUser,
    [string]$TargetPolicy,
    [ValidateSet("OneDrive", "SharePoint", "MicrosoftTeams", "Exchange")]
    [string]$WorkloadCategory,
    [ValidateSet("Low", "Medium", "High")]
    [string]$AlertSeverity,
    [Nullable[DateTime]]$StartDate,
    [Nullable[DateTime]]$EndDate,
    [string]$Organization,
    [string]$ClientId,
    [string]$CertificateThumbprint,
    [string]$UserName,
    [string]$Password
)

$MaxStartDate = ((Get-Date).AddDays(-180)).Date 

# Set default StartDate and EndDate if both are null
if ($null -eq $StartDate -and $null -eq $EndDate) {
    $EndDate = (Get-Date).Date
    $StartDate = $MaxStartDate
}

# Validate StartDate input
while ($true) {
    if ($null -eq $StartDate) {
        $StartDate = Read-Host "Enter start date for report generation (Eg: 09/24/2024)"
    }
    try {
        $Date = [DateTime]$StartDate
        if ($Date -ge $MaxStartDate) {
            break
        }
        else {
            Write-Host "`nAudit can be retrieved only for the past 180 days. Please select a date after $MaxStartDate" -ForegroundColor Red
            return
        }
    }
    catch {
        Write-Host "`nNot a valid date" -ForegroundColor Red
    }
}

# Validate EndDate input
while ($true) {
    if ($null -eq $EndDate) {
        $EndDate = Read-Host "Enter end date for report generation (Eg: 09/24/2024)"
    }
    try {
        $Date = [DateTime]$EndDate
        if ($EndDate -lt $StartDate) {
            Write-Host "End date must be later than start date" -ForegroundColor Red
            return
        }
        break
    }
    catch {
        Write-Host "`nNot a valid date" -ForegroundColor Red
    }
}

function Connect-Exo {
    # Ensure the Exchange Online module is available
    $Module = Get-Module ExchangeOnlineManagement -ListAvailable
    if ($Module.Count -eq 0) {
        Write-Host "Exchange Online PowerShell module is not available" -ForegroundColor Yellow
        $Confirm = Read-Host "Do you want to install the module? [Y] Yes [N] No"
        if ($Confirm -match "[yY]") {
            Write-Host "Installing Exchange Online PowerShell module"
            Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force
        }
        else {
            Write-Host "EXO module is required to connect to Exchange Online. Please install the module using Install-Module ExchangeOnlineManagement cmdlet."
            Exit
        }
    }
    
    Write-Host "Connecting to Exchange Online..."
    
    if (-not [string]::IsNullOrEmpty($UserName) -and -not [string]::IsNullOrEmpty($Password)) {
        $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
        $Credential = New-Object System.Management.Automation.PSCredential($UserName, $SecuredPassword)
        Connect-ExchangeOnline -Credential $Credential -ShowBanner:$false
    }
    elseif (-not [string]::IsNullOrEmpty($Organization) -and -not [string]::IsNullOrEmpty($ClientId) -and -not [string]::IsNullOrEmpty($CertificateThumbprint)) {
        Connect-ExchangeOnline -AppId $ClientId -CertificateThumbprint $CertificateThumbprint -Organization $Organization -ShowBanner:$false
    }
    else {
        Connect-ExchangeOnline -ShowBanner:$false
    }
}

Connect-Exo

$Location = Get-Location
$Timestamp = (Get-Date -format 'yyyy-MMM-dd-ddd hh-mm tt')
$IntervalTimeInMinutes = 1440  
$CurrentStart = $StartDate
$CurrentEnd = $CurrentStart.AddMinutes($IntervalTimeInMinutes)
$OutputCSV = switch ($WorkloadCategory) {
    'MicrosoftTeams' { "$Location\AuditDLPRuleMatch_MicrosoftTeams$Timestamp.csv" }
    'Exchange' { "$Location\AuditDLPRuleMatch_Exchange$Timestamp.csv" }
    'OneDrive' { "$Location\AuditDLPRuleMatch_OneDrive$Timestamp.csv" }
    'SharePoint' { "$Location\AuditDLPRuleMatch_SharePoint$Timestamp.csv" }
    default { "$Location\AuditDLPRuleMatch_$Timestamp.csv" }
}

if ($CurrentEnd -gt $EndDate) { $CurrentEnd = $EndDate }

$AggregateResults = 0
$CurrentResult = @()
$CurrentResultCount = 0
$AuditEventsCount = 0
Write-Host `nRetrieving audit log from $StartDate to $EndDate... -ForegroundColor cyan

while ($true) {
    if ($CurrentStart -eq $CurrentEnd) {
        Write-Host "Start and end time are the same. Please enter a different time range." -ForegroundColor Red
        Exit
    }
    else {
        $Results = Search-UnifiedAuditLog -StartDate $CurrentStart -EndDate $CurrentEnd -Operations "DlpRuleMatch" -SessionId s -SessionCommand ReturnLargeSet -ResultSize 5000 
    }

    $AllAuditData = @()
    $AllAudits = $null
  

    foreach ($Result in $Results) {
        $AuditData = $Result.AuditData | ConvertFrom-Json

        if (-not [string]::IsNullOrEmpty($TargetUser) -and $AuditData.UserId -ne $TargetUser) { continue }
        if (-not [string]::IsNullOrEmpty($TargetPolicy) -and $AuditData.PolicyDetails[0].PolicyName -ne $TargetPolicy) { continue }
        if (-not [string]::IsNullOrEmpty($WorkloadCategory) -and $AuditData.Workload -ne $WorkloadCategory) { continue }
        if (-not [string]::IsNullOrEmpty($AlertSeverity) -and $AuditData.PolicyDetails[0].Rules[0].Severity -notin $AlertSeverity) { continue }

        $CreationTime = (Get-Date $AuditData.CreationTime).ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss")
        $Id = $AuditData.Id
        $Operation = $AuditData.Operation
        $Workload = $AuditData.Workload
        $UserId = $AuditData.UserId
        $IncidentId = $AuditData.IncidentId

        $PolicyId = $PolicyName = $RuleId = $RuleName = $RuleActions = $Condition = $SensitiveInformationType = $Confidence = "-"
        $ConditionNames = $ConditionValues = $Sender = $ToRecipients = $MessageID = $FileSize = $Bcc = $CC = $Subject = $FileName = $FileOwner = $FilePathUrl = $FileSharedFrom = $FileSizeKB = $SenstiveInformationCount = "-" 
        $MatchedValues = @() 

        if ($AuditData.PolicyDetails.Count -gt 0) {
            $PolicyId = $AuditData.PolicyDetails[0].PolicyId
            $PolicyName = $AuditData.PolicyDetails[0].PolicyName

            if ($AuditData.PolicyDetails[0].Rules.Count -gt 0) {
                $RuleId = $AuditData.PolicyDetails[0].Rules[0].RuleId
                $RuleName = $AuditData.PolicyDetails[0].Rules[0].RuleName
                $RuleActions = $AuditData.PolicyDetails[0].Rules[0].Actions -join ", "
                $Severity = $AuditData.PolicyDetails[0].Rules[0].Severity

                if ($AuditData.PolicyDetails[0].Rules[0].ConditionsMatched) {
                    $SensitiveInformation = $AuditData.PolicyDetails[0].Rules[0].ConditionsMatched.SensitiveInformation
                    if ($SensitiveInformation -and $SensitiveInformation.Count -gt 0) {
                        $SensitiveInformationType = $SensitiveInformation[0].SensitiveInformationTypeName
                        $Confidence = $SensitiveInformation[0].Confidence
                        $SenstiveInformationCount = $SensitiveInformation[0].Count
                    }
                    if ($AuditData.PolicyDetails[0].Rules[0].ConditionsMatched.OtherConditions) {
                        $ConditionNames = $AuditData.PolicyDetails[0].Rules[0].ConditionsMatched.OtherConditions.Name 
                        $ConditionValues = $AuditData.PolicyDetails[0].Rules[0].ConditionsMatched.OtherConditions.Value
                    }
                }
            }
        }

        if ($AuditData.RecordType -eq 13) {
            $Sender = $AuditData.ExchangeMetaData.From
            $ToRecipients = $AuditData.ExchangeMetaData.To -join ", "
            $MessageID = $AuditData.ExchangeMetaData.MessageID
            $FileSize = $AuditData.ExchangeMetaData.FileSize
            $FileSizeKB = [math]::Round($FileSize / 1KB, 2)
            $Bcc = if ($AuditData.ExchangeMetaData.BCC) { $AuditData.ExchangeMetaData.BCC -join ", " } else { "-" }
            $CC = if ($AuditData.ExchangeMetaData.CC) { $AuditData.ExchangeMetaData.CC -join ", " } else { "-" }
            $Subject = if ($AuditData.ExchangeMetaData.Subject) { $AuditData.ExchangeMetaData.Subject } else { "-" }
            $Sent = (Get-Date $AuditData.ExchangeMetaData.Sent).ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss")
            $SiteCollectionUrl = '-'
        }

        if ($AuditData.RecordType -eq 11) {
            $Sender = $AuditData.SharePointMetaData.From
            $FileName = $AuditData.SharePointMetaData.FileName
            $FileOwner = $AuditData.SharePointMetaData.FileOwner
            $FilePathUrl = $AuditData.SharePointMetaData.FilePathUrl
            $FileSharedFrom = $AuditData.SharePointMetaData.From
            $SiteCollectionUrl = $AuditData.SharePointMetaData.SiteCollectionUrl
            $Sent = "-"
            $FileSize = $AuditData.sharePointMetaData.FileSize
            $FileSizeKB = [math]::Round($FileSize / 1KB, 2)
        }

        $AuditEventsCount++
        $AllAudits = @{
            'Rule Matched Time'          = $CreationTime
            'Audit Id'                   = $Id
            'Operation'                  = $Operation
            'Workload'                   = $Workload
            'User Id'                    = $UserId
            'Incident Id'                = $IncidentId
            'Policy Id'                  = $PolicyId
            'Policy Name'                = $PolicyName
            'Rule Id'                    = $RuleId
            'Rule Name'                  = $RuleName
            'Rule Actions'               = $RuleActions
            'Reason For Detection'       = $ConditionNames -join ", "
            'Sensitive Information Type' = $SensitiveInformationType
            'Confidence'                 = $Confidence
            'Sent By'                    = $Sender
            'Received By'                = $ToRecipients
            'Message ID'                 = $MessageID
            'File Size'                  = $FileSize
            'Bcc'                        = $Bcc
            'CC'                         = $CC
            'Subject'                    = $Subject
            'File Name'                  = $FileName
            'File Owner'                 = $FileOwner
            'File Path Url'              = $FilePathUrl
            'Detected Values'            = $ConditionValues -join ", "
            'Sent Time'                  = $Sent
            'File Shared By'             = $FileSharedFrom
            'Severity'                   = $Severity
            'Site Collection Url'        = $SiteCollectionUrl
            'File Size KB'               = $FileSizeKB
            'Senstive Information Count' = $SenstiveInformationCount
        }

        $AllAuditData += New-Object PSObject -Property $AllAudits
    }

    switch ($WorkloadCategory) {
        'MicrosoftTeams' {
            $AllAuditData | Sort-Object 'Rule Matched Time' | Export-Csv $OutputCSV -NoTypeInformation -Append -Force
        }
        'Exchange' {
            $AllAuditData | Sort-Object 'Rule Matched Time' | Export-Csv $OutputCSV -NoTypeInformation -Append -Force
        }
        'OneDrive' {
            $AllAuditData | Sort-Object 'Rule Matched Time' | Export-Csv $OutputCSV -NoTypeInformation -Append -Force
        }
        'SharePoint' {
            $AllAuditData | Sort-Object 'Rule Matched Time' | Export-Csv $OutputCSV -NoTypeInformation -Append -Force
        }
        default {
            $AllAuditData | Sort-Object 'Rule Matched Time' | Export-Csv $OutputCSV -NoTypeInformation -Append -Force
        }
    }

    $CurrentResultCount += $Results.Count
    $AggregateResults = $AuditEventsCount
    Write-Progress -Activity "`nRetrieving audit log for $CurrentStart : $CurrentResultCount records" -Status "Total processed audit record count: $AggregateResults"
    
    if (($CurrentResultCount -eq 50000) -or ($Results.count -lt 5000)) {
        if ($CurrentResultCount -eq 50000) {
            Write-Host "Retrieved max record for the current range. Proceeding further may cause data loss or rerun the script with reduced time interval." -ForegroundColor Red
            $Confirm = Read-Host "Are you sure you want to continue? [Y] Yes [N] No"
            if ($Confirm -notmatch "[Y]") {
                Write-Host "Please rerun the script with reduced time interval" -ForegroundColor Red
                Exit
            }
            else {
                Write-Host "Proceeding audit log collection with possible data loss"
            }
        }

        if (($CurrentEnd -eq $EndDate)) { break }
    
        $CurrentStart = $CurrentEnd
        if ($CurrentStart -gt (Get-Date)) { break }
    
        $CurrentEnd = $CurrentStart.AddMinutes($IntervalTimeInMinutes)
        if ($CurrentEnd -gt $EndDate) { $CurrentEnd = $EndDate }
        $CurrentResultCount = 0
        $CurrentResult = @()
    }
}

Write-Host "`nScript execution completed." -ForegroundColor Green

If ($AggregateResults -eq 0) {
    Write-Host "No records found"
}
else {
    Write-Host "`nThe output file contains $AuditEventsCount audit records"
    if (Test-Path -Path $OutputCSV) {
        Write-Host "`nThe Output file available at: $OutputCSV" -ForegroundColor Yellow
        $Prompt = New-Object -ComObject wscript.shell
        $UserInput = $Prompt.popup("Do you want to open output file?", 0, "Open Output File", 4)
        If ($UserInput -eq 6) {
            Invoke-Item "$OutputCSV"
        }
    }
}

Disconnect-ExchangeOnline -Confirm:$false -InformationAction Ignore -ErrorAction SilentlyContinue
