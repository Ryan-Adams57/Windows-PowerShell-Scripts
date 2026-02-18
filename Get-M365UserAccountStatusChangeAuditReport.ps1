<#
=============================================================================================
Name:           Get M365 User Account Status Change Audit Report Using PowerShell  
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
    [switch]$EnabledEventsOnly,
    [switch]$DisabledEventsOnly,
    [switch]$SucceedOnly,
    [switch]$FailedOnly,
    [switch]$GuestUserOnly,
    [switch]$InternalUserOnly,
    [string[]]$PerformedBy,
    [string[]]$TargetUser,
    [string]$ClientId,
    [string]$Organization,
    [string]$CertificateThumbprint,
    [string]$UserName,
    [string]$Password
)

$MaxStartDate=((Get-Date).AddDays(-180)).Date

if(($null -eq $StartDate) -and ($null -eq $EndDate)) {
    $EndDate=(Get-Date).Date
    $StartDate=$MaxStartDate
}

While($true) {
    if ($null -eq $StartDate) {
        $StartDate=Read-Host Enter start time for report generation '(Eg:03/21/2025)'
    }
    try {
        $Date=[DateTime]$StartDate
        if($Date -ge $MaxStartDate) { 
            break
        }
        else {
            Write-Host `nAudit can be retrieved only for the past 180 days. Please select a date after $($MaxStartDate.ToString("MM/dd/yyyy.")) -ForegroundColor Red
            return
        }
    }
    Catch {
        Write-Host `nNot a valid date -ForegroundColor Red
    }
}

While($true) {
    if ($null -eq $EndDate) {
        $EndDate=Read-Host Enter End time for report generation '(Eg: 05/28/2025)'
    }
    try {
        $Date=[DateTime]$EndDate
        if($EndDate -lt ($StartDate)) {
            Write-Host End time should be later than start time -ForegroundColor Red
            return
        }
        break
    }
    Catch {
        Write-Host `nNot a valid date -ForegroundColor Red
    }
}

Function Connect_Exo
{
    $Module = Get-Module ExchangeOnlineManagement -ListAvailable
    if($Module.count -eq 0)  { 
        Write-Host Exchange Online PowerShell module is not available -ForegroundColor yellow  
        $Confirm= Read-Host Are you sure you want to install module? [Y] Yes [N] No 
        if($Confirm -match "[yY]")  { 
            Write-host "Installing Exchange Online PowerShell module"
            Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force
        } 
        else  { 
            Write-Host EXO module is required to connect Exchange Online. Please install module using Install-Module ExchangeOnlineManagement cmdlet. 
            Exit
        }
    } 

    Write-Host Connecting to Exchange Online...

    if(($UserName -ne "") -and ($Password -ne "")) {
        $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
        $Credential  = New-Object System.Management.Automation.PSCredential $UserName,$SecuredPassword
        Connect-ExchangeOnline -Credential $Credential -ShowBanner:$false
    }
    elseif($Organization -ne "" -and $ClientId -ne "" -and $CertificateThumbprint -ne "") {
        Connect-ExchangeOnline -AppId $ClientId -CertificateThumbprint $CertificateThumbprint  -Organization $Organization -ShowBanner:$false
    }
    else {
        Connect-ExchangeOnline -ShowBanner:$false
    }
}

Connect_Exo

$Location=Get-Location
$OutputCSV="$Location\M365Users_AccountStatus_Changes_Report_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"
$IntervalTimeInMinutes=1440
$CurrentStart=$StartDate
$CurrentEnd=$CurrentStart.AddMinutes($IntervalTimeInMinutes)

if($CurrentEnd -gt $EndDate) {
    $CurrentEnd=$EndDate
}

$AggregateResults = 0
$CurrentResult= @()
$CurrentResultCount=0
$AccountStatusChangesCount=0

Write-Host `nRetrieving audit log from $StartDate to $EndDate...  -ForegroundColor Cyan

while($true) {
    if($CurrentStart -eq $CurrentEnd) {
        Write-Host Start and end time are same. Please enter different time range -ForegroundColor Red
        Exit
    }
    else { 
        $CurrentResult=Search-UnifiedAuditLog -StartDate $CurrentStart -EndDate $CurrentEnd -Operations "Update user." -SessionId s -SessionCommand ReturnLargeSet -ResultSize 5000
    }
 
    $AllAuditData=@()
    $AllAudits=$null
 
    foreach($Result in $CurrentResult) {
        $AuditData=$Result.auditdata | ConvertFrom-Json

        if (($AuditData.ModifiedProperties[0].Name -match "AccountEnabled")) {

            $EventTime = (Get-Date($AuditData.CreationTime)).ToLocalTime()
            $User = $AuditData.ObjectId
            $UserType = $AuditData.ModifiedProperties[-1].NewValue
            $ResultStatus = $AuditData.ResultStatus
            $Actor = $AuditData.Actor[0].ID
            $ActorType = $AuditData.Actor[-1].ID
            $OldValue = [bool]::Parse($($AuditData.ModifiedProperties[0].OldValue | ConvertFrom-Json))
            $NewValue = [bool]::Parse($($AuditData.ModifiedProperties[0].NewValue | ConvertFrom-Json))
            $Operation = if($OldValue -eq $false) { "Re-Enabled User" } else { "Disabled User" }

            if((!([string]::IsNullOrEmpty($PerformedBy))) -and ($PerformedBy -notcontains $Actor)) { continue }
            if((!([string]::IsNullOrEmpty($TargetUser))) -and ($TargetUser -notcontains $User)) { continue }
            if(($GuestUserOnly.IsPresent) -and ($UserType -ne "Guest")) { continue }
            if(($InternalUserOnly.IsPresent) -and ($UserType -ne "Member")) { continue }
            if(($SucceedOnly.IsPresent) -and ($ResultStatus -ne "Success")) { continue }
            if(($FailedOnly.IsPresent) -and ($ResultStatus -ne "Failure")) { continue }
            if(($EnabledEventsOnly.IsPresent) -and ($Operation -ne "Re-Enabled User")) { continue }
            if(($DisabledEventsOnly.IsPresent) -and ($Operation -ne "Disabled User")) { continue }

            if($OldValue -eq $true) { $OldValue = "Enabled" } else { $OldValue = "Disabled" }
            if($NewValue -eq $true) { $NewValue = "Enabled" } else { $NewValue = "Disabled" }

            $AccountStatusChangesCount++
            $AllAudits=@{
                'Event Time'=$EventTime
                'User'=$User
                'User Type'=$UserType
                'Operation'=$Operation
                'Result Status'=$ResultStatus
                'Performed By'=$Actor
                'Performer Type'=$ActorType
                'Changed From'=$OldValue
                'Changed To'=$NewValue
                'Audit Info'=$AuditData
            }

            $AllAuditData= New-Object PSObject -Property $AllAudits
            $AllAuditData | Sort-Object 'Event Time' | Select-Object 'Event Time','User','User Type','Operation','Result Status','Performed By','Performer Type','Changed From','Changed To','Audit Info' | Export-Csv $OutputCSV -NoTypeInformation -Append
        }
    }
 
    $CurrentResultCount=$CurrentResultCount+($CurrentResult.count)
    $AggregateResults +=$CurrentResult.count

    Write-Progress -Activity "`n     Retrieving audit log for $CurrentStart : $CurrentResultCount records"`n" Total processed audit record count: $AggregateResults"

    if(($CurrentResultCount -eq 50000) -or ($CurrentResult.count -lt 5000)) {

        if($CurrentResultCount -eq 50000) {
            Write-Host Retrieved max record for the current range. Proceeding further may cause data loss or rerun the script with reduced time interval. -ForegroundColor Red
            $Confirm=Read-Host `nAre you sure you want to continue? [Y] Yes [N] No
            if($Confirm -notmatch "[Y]") {
                Write-Host Please rerun the script with reduced time interval -ForegroundColor Red
                Exit
            }
            else {
                Write-Host Proceeding audit log collection with data loss
            }
        }

        if(($CurrentEnd -eq $EndDate)) {
            break
        }

        [DateTime]$CurrentStart=$CurrentEnd

        if($CurrentStart -gt (Get-Date)) {
            break
        }

        [DateTime]$CurrentEnd=$CurrentStart.AddMinutes($IntervalTimeInMinutes)

        if($CurrentEnd -gt $EndDate) {
            $CurrentEnd=$EndDate
        }

        $CurrentResultCount=0
        $CurrentResult = @()
    }
}

Write-Host `n~~ Script maintained by Ryan Adams ~~`n -ForegroundColor Green
Write-Host "~~ Visit https://www.governmentcontrol.net/ for additional Microsoft 365 security and reporting resources. ~~" -ForegroundColor Green  

If($AccountStatusChangesCount -eq 0) {
    Write-Host No records found
}
else {
    Write-Host `nThe output file contains $AccountStatusChangesCount audit records."
    if((Test-Path -Path $OutputCSV) -eq "True") {
        Write-Host `nThe Output file available in: " -NoNewline -ForegroundColor Yellow
        Write-Host $OutputCSV 
        $Prompt = New-Object -ComObject wscript.shell
        $UserInput = $Prompt.popup("Do you want to open output file?",0,"Open Output File",4)
        If ($UserInput -eq 6) {
            Invoke-Item "$OutputCSV"
        }
    }
}

Disconnect-ExchangeOnline -Confirm:$false
