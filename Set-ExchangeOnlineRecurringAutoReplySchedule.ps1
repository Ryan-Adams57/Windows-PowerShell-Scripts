<#
=============================================================================================
Name:           Configure Recurring Out-of-Office Replies in Exchange Online
Description:    This script automates recurring out-of-office replies for Microsoft 365 users
Version:        1.0
Website:        https://www.governmentcontrol.net/

Author:         Ryan Adams
GitHub:         https://github.com/Ryan-Adams57
GitLab:         https://gitlab.com/Ryan-Adams57
PasteBin:       https://pastebin.com/u/Removed_Content

Script Highlights: 
~~~~~~~~~~~~~~~~~
1. The script can be executed using either username/password or certificate-based authentication (CBA).
2. It automatically calculates and sets the out-of-office start and end times for upcoming occurrences based on provided day and time parameters.
3. Designed for recurring OOF scheduling via tools like Windows Task Scheduler or Azure Automation.
4. Allows admins to configure recurring out-of-office replies for themselves or other users.
5. The external out-of-office message defaults to the internal message if not provided.
6. The external audience defaults to "All" if not specified.

For detailed script execution: https://www.governmentcontrol.net/
============================================================================================
#>

param (
    [Parameter(Mandatory=$true)][string]$Identity,
    [Parameter(Mandatory=$true)][string]$StartDay,
    [Parameter(Mandatory=$true)][string]$StartTime,
    [Parameter(Mandatory=$true)][string]$EndDay,
    [Parameter(Mandatory=$true)][string]$EndTime,
    [Parameter(Mandatory=$true)][string]$InternalMessage,
    [string]$ExternalMessage,
    [string]$ExternalAudience,
    [string]$UserName,
    [string]$Password,
    [string]$ClientId,
    [string]$Organization,
    [string]$CertificateThumbprint        
)

if (-not $ExternalMessage) { $ExternalMessage = $InternalMessage }
if (-not $ExternalAudience) { $ExternalAudience = "All" }

function Validate-DayOfWeek {
    param ([string]$dayOfWeek)
    return [Enum]::GetNames([System.DayOfWeek]) -contains $dayOfWeek
}

function Validate-TimeFormat {
    param ([string]$time)
    return $time -match '^(0?[0-9]|1[0-9]|2[0-3]):[0-5][0-9]$'
}

if (-not (Validate-DayOfWeek $StartDay) -or 
    -not (Validate-DayOfWeek $EndDay) -or 
    -not (Validate-TimeFormat $StartTime) -or 
    -not (Validate-TimeFormat $EndTime)) {

    Write-Host "There was an error while calculating the startDateTime or endDateTime. Please verify spelling and time format (HH:mm)." -ForegroundColor Red
    exit
}

function Get-DateForDayOfWeek ($dayOfWeek) {
    $daysToAdd = ([Enum]::Parse([System.DayOfWeek], $dayOfWeek)) - (Get-Date).DayOfWeek
    if ($daysToAdd -lt 0) { $daysToAdd += 7 }
    (Get-Date).AddDays($daysToAdd).Date
}

$startDateTime = (Get-DateForDayOfWeek $StartDay).AddHours([int]$StartTime.Split(':')[0]).AddMinutes([int]$StartTime.Split(':')[1])
$endDateTime   = (Get-DateForDayOfWeek $EndDay).AddHours([int]$EndTime.Split(':')[0]).AddMinutes([int]$EndTime.Split(':')[1])

if ($endDateTime -lt $startDateTime) { $endDateTime = $endDateTime.AddDays(7) }

Write-Host "Connecting to Exchange Online..."

if(($UserName -ne "") -and ($Password -ne ""))
{
    $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
    $Credential  = New-Object System.Management.Automation.PSCredential $UserName,$SecuredPassword
    Connect-ExchangeOnline -Credential $Credential
}
elseif($Organization -ne "" -and $ClientId -ne "" -and $CertificateThumbprint -ne "")
{
    Connect-ExchangeOnline -AppId $ClientId -CertificateThumbprint $CertificateThumbprint -Organization $Organization
}
else
{
    Connect-ExchangeOnline
}

try {
    Set-MailboxAutoReplyConfiguration -Identity $Identity `
        -AutoReplyState Scheduled `
        -StartTime $startDateTime `
        -EndTime $endDateTime `
        -InternalMessage $InternalMessage `
        -ExternalMessage $ExternalMessage `
        -ExternalAudience $ExternalAudience `
        -ErrorAction Stop

    Write-Host "Out-of-office automatic replies configured successfully for user: $Identity"
}
catch {
    Write-Host "Failed to configure out-of-office automatic replies for user: $Identity" -ForegroundColor Red
    Write-Host $_.Exception.Message
}

Disconnect-ExchangeOnline -Confirm:$false | Out-Null
Write-Host "`n~~ Script maintained by Ryan Adams ~~`n" -ForegroundColor Green
