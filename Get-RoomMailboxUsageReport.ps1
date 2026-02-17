<#
=============================================================================================
Name:           Get Office 365 Room Mailbox Usage Statistics Using PowerShell
Description:    This script provides detailed information on all Office 365 room mailbox usage.
Version:        3.0
Author:         Ryan Adams
Website:        https://www.governmentcontrol.net/
GitHub:         https://github.com/Ryan-Adams57
GitLab:         https://gitlab.com/Ryan-Adams57
PasteBin:       https://pastebin.com/u/Removed_Content

For detailed script execution: https://www.governmentcontrol.net/
============================================================================================
#>

Param
(
    [switch]$OnlineMeetingOnly,
    [switch]$ShowTodaysMeetingsOnly,
    [String]$OrgEmailId,
    [switch]$CreateSession,
    [string]$TenantId,
    [string]$ClientId,
    [string]$CertificateThumbprint
)

Function Connect_MgGraph
{
    $MsGraphBetaModule = Get-Module Microsoft.Graph.Beta -ListAvailable
    if ($MsGraphBetaModule -eq $null) {
        Write-Host "Important: Microsoft Graph Beta module is unavailable. It must be installed to run this script." 
        $confirm = Read-Host "Do you want to install Microsoft Graph Beta module? [Y] Yes [N] No"
        if ($confirm -match "[yY]") {
            Write-Host "Installing Microsoft Graph Beta module..."
            Install-Module Microsoft.Graph.Beta -Scope CurrentUser -AllowClobber
            Write-Host "Microsoft Graph Beta module installed successfully." -ForegroundColor Magenta
        } else {
            Write-Host "Exiting. Microsoft Graph Beta module is required." -ForegroundColor Red
            Exit
        }
    }
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    if (($TenantId -ne "") -and ($ClientId -ne "") -and ($CertificateThumbprint -ne "")) {
        Connect-MgGraph -TenantId $TenantId -AppId $ClientId -CertificateThumbprint $CertificateThumbprint -ErrorAction SilentlyContinue -ErrorVariable ConnectionError | Out-Null
        if ($ConnectionError -ne $null) {
            Write-Host $ConnectionError -ForegroundColor Red
            Exit
        }
    } else {
        Connect-MgGraph -Scopes "Place.Read.All,User.Read.All,Calendars.Read.Shared" -ErrorAction SilentlyContinue -ErrorVariable ConnectionError | Out-Null
        if ($ConnectionError -ne $null) {
            Write-Host $ConnectionError -ForegroundColor Red
            Exit
        }
    }
    Write-Host "Microsoft Graph Beta PowerShell module connected successfully." -ForegroundColor Green
    Write-Host "`nNote: If you encounter module conflicts, run the script in a fresh PowerShell window." -ForegroundColor Yellow
}
Connect_MgGraph

$ExportCSV = ".\RoomMailboxUsageReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm-ss` tt).ToString()).csv"
$ExportSummaryCSV = ".\RoomMailboxUsageSummaryReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm-ss` tt).ToString()).csv"
$ExportResult = ""
$ExportSummary = ""
$startDate = (Get-Date).AddDays(-30).Date
$EndDate = (Get-Date).AddDays(1).Date
$MbCount = 0
$PrintedMeetings = 0

# Retrieve all room mailboxes
Get-MgBetaPlaceAsRoom -All | ForEach-Object {
    $RoomAddress = $_.EmailAddress
    $RoomName = $_.DisplayName
    $MeetingCount = 0
    $Count++
    $RoomUsage = 0
    $OnlineMeetingCount = 0
    $AllDayMeetingCount = 0

    Get-MgBetaUserCalendarView -UserId $RoomAddress -StartDateTime $startDate -EndDateTime $EndDate -All | ForEach-Object {
        Write-Progress -Activity "`n     Processing room: $Count - $RoomAddress : Meeting Count - $MeetingCount"
        if ($_.IsCancelled -eq $false) {
            $Print = 1
            $MeetingCount++
            $Organizer = $_.Organizer.EmailAddress.Address
            $MeetingSubject = $_.Subject
            $IsAllDayMeeting = $_.IsAllDay
            $IsOnlineMeeting = $_.IsOnlineMeeting
            if ($IsOnlineMeeting -eq $true) { $OnlineMeetingCount++ }
            if ($IsAllDayMeeting -eq $true) { $AllDayMeetingCount++ }
            $MeetingStartTimeZone = $_.OriginalStartTimeZone
            $MeetingCreatedTime = $_.CreatedDateTime
            $MeetingLastModifiedTime = $_.LastModifiedDateTime
            [Datetime]$MeetingStart = $_.Start.DateTime
            $MeetingStartTime = $MeetingStart.ToLocalTime()
            [Datetime]$MeetingEnd = $_.End.DateTime
            $MeetingEndTime = $MeetingEnd.ToLocalTime()
            if ($_.IsAllDay -eq $true) {
                $MeetingDuration = 480
            } else { 
                $MeetingDuration = ($MeetingEndTime - $MeetingStartTime).TotalMinutes
            }
            $RoomUsage += $MeetingDuration
            $ReqiredAttendees = (($_.Attendees | Where {$_.Type -eq "required"}).emailaddress | Select-Object -ExpandProperty Address) -join ","
            $OptionalAttendees = (($_.Attendees | Where {$_.Type -eq "optional"}).emailaddress | Select-Object -ExpandProperty Address) -join ","
            $AllAttendeesCount = (($_.Attendees | Where {$_.Type -ne "resource"}).emailaddress | Measure-Object).Count

            # Filter for online meetings
            if (($OnlineMeetingOnly.IsPresent) -and ($IsOnlineMeeting -eq $false)) { $Print = 0 }
            # Filter by specific organizer
            if (($OrgEmailId -ne "") -and ($OrgEmailId -ne $Organizer)) { $Print = 0 }
            # Filter today's meetings only
            if (($ShowTodaysMeetingsOnly.IsPresent) -and ($MeetingStartTime -lt (Get-Date).Date)) { $Print = 0 }

            # Detailed report
            if ($Print -eq 1) {
                $PrintedMeetings++
                $ExportResult = [PSCustomObject]@{
                    'Room Name' = $RoomName
                    'Organizer' = $Organizer
                    'Subject' = $MeetingSubject
                    'Start Time' = $MeetingStartTime
                    'End Time' = $MeetingEndTime
                    'Duration(in mins)' = $MeetingDuration
                    'TimeZone' = $MeetingStartTimeZone
                    'Total Attendees Count' = $AllAttendeesCount
                    'Required Attendees' = $ReqiredAttendees
                    'Optional Attendees' = $OptionalAttendees
                    'Is Online Meeting' = $IsOnlineMeeting
                    'Is AllDay Meeting' = $IsAllDayMeeting
                }
                $ExportResult | Export-Csv -Path $ExportCSV -NoTypeInformation -Append
            }
        }
    }
    # Summary report
    $ExportSummary = [PSCustomObject]@{
        'Room Name' = $RoomName
        'Total Meeting Count' = $MeetingCount
        'Online Meeting Count' = $OnlineMeetingCount
        'Usage Duration(in mins)' = $RoomUsage
        'Full Day Meetings' = $AllDayMeetingCount
    }
    $ExportSummary | Export-Csv -Path $ExportSummaryCSV -NoTypeInformation -Append
}

# Open output files after execution
Write-Host "`nScript executed successfully."
if ((Test-Path -Path $ExportCSV) -eq $true) {
    Write-Host "`nExported report has" -NoNewLine
    Write-Host " $PrintedMeetings meeting(s)" -ForegroundColor Magenta
    $Prompt = New-Object -ComObject wscript.shell
    $UserInput = $Prompt.popup("Do you want to open output file?", 0, "Open Output File", 4)
    if ($UserInput -eq 6) {
        Invoke-Item "$ExportCSV"
        Invoke-Item "$ExportSummaryCSV"
    }
    Write-Host "`nDetailed report available in: " -NoNewline -ForegroundColor Yellow
    Write-Host " $ExportCSV"
    Write-Host "`nSummary report available in: " -NoNewline -ForegroundColor Yellow
    Write-Host " $ExportSummaryCSV `n"
} else {
    Write-Host "No meetings found." -ForegroundColor Red
}
