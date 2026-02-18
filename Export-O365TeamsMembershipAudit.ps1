<#
=============================================================================================
Name:           Audit Microsoft Teams membership changes in Office 365
Version:        1.0
Website:        https://www.governmentcontrol.net/

Script Highlights: 
~~~~~~~~~~~~~~~~~
1. The script uses modern authentication to retrieve audit logs.    
2. The script can be executed with an MFA enabled account too.      
3. Exports report results to CSV file.    
4. Exports all the teams’ membership changes 
5. The script has a filter to track private channel membership changes. 
6. The script has a filter to monitor shared channel membership changes. 
7. Allows you to generate an audit report for a custom period.   
8. Automatically installs the EXO V2 module (if not installed already) upon your confirmation.  
9. The script is scheduler friendly. i.e., Credentials can be passed as a parameter instead of saved inside the script. 

For detailed script execution: GitHub - https://github.com/Ryan-Adams57
============================================================================================
#>

Param
(
    [Parameter(Mandatory = $false)]
    [Nullable[DateTime]]$StartDate,
    [Nullable[DateTime]]$EndDate,
    [switch]$TeamsMembershipChangesOnly,
    [switch]$PrivateChannelMembershipChangesOnly,
    [switch]$SharedChannelMembershipChangesOnly,
    [string]$UserName,
    [string]$Password
)

Function Connect_Exo
{
    # Check for EXO v2 module installation
    $Module = Get-Module ExchangeOnlineManagement -ListAvailable
    if ($Module.count -eq 0) 
    { 
        Write-Host "Exchange Online PowerShell V2 module is not available" -ForegroundColor Yellow  
        $Confirm = Read-Host "Are you sure you want to install module? [Y] Yes [N] No"
        if ($Confirm -match "[yY]") 
        { 
            Write-Host "Installing Exchange Online PowerShell module"
            Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force
            Import-Module ExchangeOnlineManagement
        } 
        else 
        { 
            Write-Host "EXO V2 module is required to connect Exchange Online. Please install module using Install-Module ExchangeOnlineManagement cmdlet."
            Exit
        }
    } 
    Write-Host "Connecting to Exchange Online..."
    if (($UserName -ne "") -and ($Password -ne ""))
    {
        $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
        $Credential  = New-Object System.Management.Automation.PSCredential $UserName,$SecuredPassword
        Connect-ExchangeOnline -Credential $Credential
    }
    else
    {
        Connect-ExchangeOnline
    }
}

$MaxStartDate = ((Get-Date).AddDays(-89)).Date

# Audit Teams membership changes for past 90 days
if (($StartDate -eq $null) -and ($EndDate -eq $null))
{
    $EndDate = (Get-Date).Date
    $StartDate = $MaxStartDate
}

# Getting start date to audit report
while ($true)
{
    if ($StartDate -eq $null)
    {
        $StartDate = Read-Host "Enter start time for report generation '(Eg:04/28/2021)'"
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
            Write-Host "`nAudit can be retrieved only for past 90 days. Please select a date after $MaxStartDate" -ForegroundColor Red
            return
        }
    }
    catch
    {
        Write-Host "`nNot a valid date" -ForegroundColor Red
    }
}

# Getting end date to audit report
while ($true)
{
    if ($EndDate -eq $null)
    {
        $EndDate = Read-Host "Enter End time for report generation '(Eg: 04/28/2021)'"
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

$OutputCSV = ".\Audit_Teams_Membership_Changes_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv" 
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
$CurrentResultCount = 0
$AggregateResultCount = 0
Write-Host "`nAuditing Microsoft Teams membership changes from $StartDate to $EndDate..."
$ProcessedAuditCount = 0
$OutputEvents = 0
$ExportResult = ""   
$ExportResults = @()  
$Operations = "MemberAdded,MemberRemoved,MemberRoleChanged"

while ($true)
{
    # Getting audit data for the given time range
    Search-UnifiedAuditLog -StartDate $CurrentStart -EndDate $CurrentEnd -Operations $Operations -SessionId s -SessionCommand ReturnLargeSet -ResultSize 5000 | ForEach-Object {
        $ResultCount++
        $ProcessedAuditCount++
        Write-Progress -Activity "`n     Retrieving Teams membership changes from $CurrentStart to $CurrentEnd.." -Status "Processed audit record count: $ProcessedAuditCount"
        $MoreInfo = $_.auditdata
        $Operation = $_.Operations
        $PerformedBy = $_.UserIds
        $PrintFlag = "True"
        if ($user -like "NT Authority*") { $PrintFlag = "False" }

        $AuditData = $_.auditdata | ConvertFrom-Json
        $EventTime = (Get-Date($AuditData.CreationTime)).ToLocalTime()
        $CommunicationType = $AuditData.CommunicationType
        $User = $AuditData.Members.UPN -join ','
        $TeamName = $AuditData.TeamName
        
        if ($CommunicationType -ne "Team")
        {
            $CommunicationType = $AuditData.ChannelType
            $ChannelName = $AuditData.ChannelName
        }
        else
        {
            $ChannelName = "-"
        }

        $Roles = $AuditData.Members.Role
        $MemberRoles = @()
        foreach ($Role in $Roles)
        {
            switch ($Role)
            {
                "1" { $Role = "Member" }
                "2" { $Role = "Owner" }
                "3" { $Role = "Guest" }
            }
            $MemberRoles += $Role
        }
        $MemberRoles = $MemberRoles -join ","

        # Filters for granular report
        if ($TeamsMembershipChangesOnly.IsPresent -and $ChannelName -ne "-") { $PrintFlag = "False" }
        elseif ($SharedChannelMembershipChangesOnly.IsPresent -and $CommunicationType -ne "Shared") { $PrintFlag = "False" }
        elseif ($PrivateChannelMembershipChangesOnly.IsPresent -and $CommunicationType -ne "Private") { $PrintFlag = "False" }

        # Export result to CSV
        if ($PrintFlag -eq "True")
        {
            $OutputEvents++
            $ExportResult = @{
                'Event Time'         = $EventTime
                'Performed By'       = $PerformedBy
                'Operation'          = $Operation
                'Team/Channel Type'  = $CommunicationType
                'Team Name'          = $TeamName
                'Channel Name'       = $ChannelName
                'User'               = $User
                'Role'               = $MemberRoles
                'More Info'          = $MoreInfo
            }
            $ExportResults = New-Object PSObject -Property $ExportResult  
            $ExportResults | Select-Object 'Event Time','Performed By','Operation','Team/Channel Type','Team Name','Channel Name','User','Role','More Info' | Export-Csv -Path $OutputCSV -NoTypeInformation -Append 
        }
    }

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
            if ($CurrentEnd -gt $EndDate) { $CurrentEnd = $EndDate }
        }
        else
        {
            Write-Host "Please rerun the script with reduced time interval" -ForegroundColor Red
            Exit
        }
    }

    if ($ResultCount -lt 5000)
    { 
        if ($CurrentEnd -eq $EndDate) { break }
        $CurrentStart = $CurrentEnd 
        if ($CurrentStart -gt (Get-Date)) { break }
        $CurrentEnd = $CurrentStart.AddMinutes($IntervalTimeInMinutes)
        $CurrentResultCount = 0
        if ($CurrentEnd -gt $EndDate) { $CurrentEnd = $EndDate }
    }                                                                                             
    $ResultCount = 0
}

# Open output file after execution
if ($OutputEvents -eq 0)
{
    Write-Host "No records found"
}
else
{
    Write-Host "`nThe output file contains $OutputEvents audit records"
    if (Test-Path -Path $OutputCSV) 
    {
        Write-Host "`nThe Output file available in:" -NoNewline -ForegroundColor Yellow
        Write-Host "$OutputCSV"
        $Prompt = New-Object -ComObject wscript.shell   
        $UserInput = $Prompt.popup("Do you want to open output file?", 0, "Open Output File", 4)   
        if ($UserInput -eq 6) { Invoke-Item "$OutputCSV" }
        Write-Host "`n~~ Script prepared by Ryan Adams ~~`n" -ForegroundColor Green
        Write-Host "~~ Check out " -NoNewline -ForegroundColor Green
        Write-Host "https://pastebin.com/u/Removed_Content" -ForegroundColor Yellow -NoNewline
        Write-Host " for sample scripts and resources. ~~" -ForegroundColor Green `n`n
    }
}

# Disconnect Exchange Online session
Disconnect-ExchangeOnline -Confirm:$false -InformationAction Ignore -ErrorAction SilentlyContinue
