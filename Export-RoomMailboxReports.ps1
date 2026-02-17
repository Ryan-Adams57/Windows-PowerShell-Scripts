<#
=============================================================================================
Name:           Export Exchange Online Room Mailbox Reports
Description:    This script can generate multiple detailed room mailbox reports
Version:        1.0
Author:         Ryan Adams
Website:        https://www.governmentcontrol.net/
GitHub:         https://github.com/Ryan-Adams57
GitLab:         https://gitlab.com/Ryan-Adams57
PasteBin:       https://pastebin.com/u/Removed_Content

Script Highlights:
~~~~~~~~~~~~~~~~~~
1. Generates multiple Room mailbox reports.    
2. Supports MFA-enabled accounts.
3. Supports certificate-based authentication (CBA).       
4. Exports report results to CSV files.    
5. Lists all mailboxes and their capacity.
6. Exports meeting room booking details.
7. Identifies room mailboxes' resource delegates.
8. Exports room mailbox permission details, including full access, send-as, and send-on-behalf permissions.
9. Built-in filtering options for granular reports.
10. Automatically installs the EXO module if not present.
11. Scheduler-friendly.

For detailed script execution: https://www.governmentcontrol.net/
============================================================================================
#>

param(
    [string]$Organization,
    [string]$ClientId,
    [string]$CertificateThumbprint,
    [string]$CSVFilePath,
    [Switch]$AnyoneCanBook,
    [Switch]$BookingAllowedForLimitedPersons,
    [Switch]$RequiresApproval,
    [Switch]$AllowsBookingForExternalUsers,
    [string]$UserName,
    [string]$Password,
    [int]$Action
)

Function Connect_Exo
{
    # Check for EXO module installation
    $Module = Get-Module ExchangeOnlineManagement -ListAvailable
    if ($Module.Count -eq 0) {
        Write-Host "Exchange Online PowerShell module is not available." -ForegroundColor Yellow
        $Confirm = Read-Host "Do you want to install the module? [Y] Yes [N] No"
        if ($Confirm -match "[yY]") {
            Write-Host "Installing Exchange Online PowerShell module..."
            Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force -Scope CurrentUser
        } else {
            Write-Host "EXO module is required. Please install using Install-Module ExchangeOnlineManagement." -ForegroundColor Red
            Exit
        }
    }
    Write-Host "Connecting to Exchange Online..."
    # Credential-based authentication
    if (($UserName -ne "") -and ($Password -ne "")) {
        $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
        $Credential = New-Object System.Management.Automation.PSCredential $UserName, $SecuredPassword
        Connect-ExchangeOnline -Credential $Credential -ShowBanner:$false
    } elseif (($Organization -ne "") -and ($ClientId -ne "") -and ($CertificateThumbprint -ne "")) {
        Connect-ExchangeOnline -AppId $ClientId -CertificateThumbprint $CertificateThumbprint -Organization $Organization -ShowBanner:$false
    } else {
        Connect-ExchangeOnline -ShowBanner:$false
    }
}
Connect_Exo

if ($Action -eq "") { 
    Write-Host ""
    Write-Host "    1. Get all room mailboxes and their capacity" -ForegroundColor Cyan
    Write-Host "    2. Export room mailboxes' booking options" -ForegroundColor Cyan
    Write-Host "    3. Get room mailbox booking delegates" -ForegroundColor Cyan
    Write-Host "    4. Get room mailbox permissions" -ForegroundColor Cyan
    Write-Host ""
    $GetAction = Read-Host 'Please choose the action to continue' 
} else {
    $GetAction = $Action
}

$Result = ""  
$Results = @() 
$Count = 0

Switch ($GetAction) {
    1 {
        $Path = "./RoomMailboxReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"
        Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails "RoomMailbox" | ForEach-Object {
            $Count++
            $UPN = $_.UserPrincipalName
            $Name = $_.DisplayName
            $PrimarySMTPAddress = $_.PrimarySMTPAddress
            $Alias = $_.Alias
            $Capacity = $_.ResourceCapacity
            Write-Progress -Activity "`n     Processing room: $Count - $UPN"
            $Result = @{
                'Room Mailbox Name' = $Name
                'UPN' = $UPN
                'Primary SMTP Address' = $PrimarySMTPAddress
                'Alias' = $Alias
                'Capacity' = $Capacity
            }
            $Results = New-Object psobject -Property $Result
            $Results | Select 'Room Mailbox Name','UPN','Primary SMTP Address','Alias','Capacity' | Export-Csv $Path -NoTypeInformation -Append
        }
        Write-Host "`nThe output file contains $Count room mailbox records"
    }

    2 {
        $Path = "./RoomMailbox_BookingOptionsReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"
        $OutputCount = 0
        $FilterPresent = (($AnyoneCanBook.IsPresent) -or ($BookingAllowedForLimitedPersons.IsPresent) -or ($RequiresApproval.IsPresent) -or ($AllowsBookingForExternalUsers.IsPresent)) ? 'True' : 'False'
        Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails "RoomMailbox" | ForEach-Object {
            $Count++
            $Print = 0
            $UPN = $_.UserPrincipalName
            $Name = $_.DisplayName
            $Capacity = $_.ResourceCapacity
            $BookingDetails = Get-CalendarProcessing -Identity $UPN
            $ResourceDelegates = $BookingDetails.ResourceDelegates
            $Delegates = $ResourceDelegates -join ","
            $AllBookInPolicy = $BookingDetails.AllBookInPolicy
            $AllRequestInPolicy = $BookingDetails.AllRequestInPolicy
            $AllRequestOutOfPolicy = $BookingDetails.AllRequestOutOfPolicy

            $BookInPolicy = ($BookingDetails.BookInPolicy | ForEach-Object { ($_ -split '-' | Select-Object -Skip 1) -join '-' }) -join ','
            $RequestInPolicy = ($BookingDetails.RequestInPolicy | ForEach-Object { ($_ -split '-' | Select-Object -Skip 1) -join '-' }) -join ','
            $RequestOutOfPolicy = ($BookingDetails.RequestOutOfPolicy | ForEach-Object { ($_ -split '-' | Select-Object -Skip 1) -join '-' }) -join ','

            $BookingWindow = $BookingDetails.BookingWindowInDays
            $MaximumDuration = $BookingDetails.MaximumDurationInMinutes
            $MinimumDuration = $BookingDetails.MinimumDurationInMinutes
            $AllowConflicts = $BookingDetails.AllowConflicts
            $AllowRecurringMeetings = $BookingDetails.AllowRecurringMeetings
            $EnforceCapacity = $BookingDetails.EnforceCapacity
            $AutomateProcessing = $BookingDetails.AutomateProcessing
            $ProcessExternalMeetingMessages = $BookingDetails.ProcessExternalMeetingMessages

            if ($FilterPresent -eq 'False') { $Print = 1 } else {
                if ($AnyoneCanBook.IsPresent -and ($AllBookInPolicy -eq $true)) { $Print = 1 }
                elseif ($BookingAllowedForLimitedPersons.IsPresent -and ($BookInPolicy -ne "" -and $AllBookInPolicy -eq $false)) { $Print = 1 }
                elseif ($RequiresApproval.IsPresent -and ($AllBookInPolicy -eq $false -and $AllRequestInPolicy -eq $true -and $ResourceDelegates -ne "")) { $Print = 1 }
                elseif ($AllowsBookingForExternalUsers.IsPresent -and $ProcessExternalMeetingMessages -eq $true) { $Print = 1 }
            }

            $BookInPolicy = if ($BookInPolicy -eq "") { "-" } else { $BookInPolicy }
            $RequestInPolicy = if ($RequestInPolicy -eq "") { "-" } else { $RequestInPolicy }
            $RequestOutOfPolicy = if ($RequestOutOfPolicy -eq "") { "-" } else { $RequestOutOfPolicy }
            $Delegates = if ($Delegates -eq "") { "-" } else { $Delegates }

            if ($Print -eq 1) {
                $OutputCount++
                $Result = @{
                    'Room Mailbox Name' = $Name
                    'UPN' = $UPN
                    'Capacity' = $Capacity
                    'All Book In Policy' = $AllBookInPolicy
                    'All Request In Policy' = $AllRequestInPolicy
                    'All Request Out Of Policy' = $AllRequestOutOfPolicy
                    'Resource Delegate' = $Delegates
                    'Book In Policy' = $BookInPolicy
                    'Request In Policy' = $RequestInPolicy
                    'Request Out Of Policy' = $RequestOutOfPolicy
                    'Booking Window (days)' = $BookingWindow
                    'Max Duration (mins)' = $MaximumDuration
                    'Min Duration (mins)' = $MinimumDuration
                    'Allow Booking for External Users' = $ProcessExternalMeetingMessages
                    'Allow Conflicts' = $AllowConflicts
                    'Allow Recurring Meetings' = $AllowRecurringMeetings
                    'Enforce Capacity' = $EnforceCapacity
                }
                $Results = New-Object psobject -Property $Result
                $Results | Select 'Room Mailbox Name','UPN','Capacity','All Book In Policy','All Request In Policy','All Request Out Of Policy','Resource Delegate','Book In Policy','Request In Policy','Request Out Of Policy','Booking Window (days)','Max Duration (mins)','Min Duration (mins)','Allow Booking for External Users','Allow Conflicts','Allow Recurring Meetings','Enforce Capacity' | Export-Csv $Path -NoTypeInformation -Append
            }
        }
        Write-Host "`nThe output file contains $OutputCount room mailbox records"
    }

    3 {
        $Path = "./RoomMailboxDelegates_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"
        Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails "RoomMailbox" | ForEach-Object {
            $Count++
            $UPN = $_.UserPrincipalName
            $Name = $_.DisplayName
            $PrimarySMTPAddress = $_.PrimarySMTPAddress
            $RoomDetails = Get-CalendarProcessing -Identity $UPN
            $ResourceDelegates = $RoomDetails.ResourceDelegates
            $Delegates = if ($ResourceDelegates -join "," -eq "") { "-" } else { $ResourceDelegates -join "," }
            Write-Progress -Activity "`n     Processing room: $Count - $UPN"
            $Result = @{
                'Room Mailbox Name' = $Name
                'UPN' = $UPN
                'Primary SMTP Address' = $PrimarySMTPAddress
                'Resource Delegates' = $Delegates
            }
            $Results = New-Object psobject -Property $Result
            $Results | Select 'Room Mailbox Name','UPN','Primary SMTP Address','Resource Delegates' | Export-Csv $Path -NoTypeInformation -Append
        }
        Write-Host "`nThe output file contains $Count room mailbox records"
    }

    4 {
        $Path = "./RoomMailbox_PermissionsReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"
        Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails "RoomMailbox" | ForEach-Object {
            $Count++
            $UPN = $_.UserPrincipalName
            $Name = $_.DisplayName
            $SendOnBehalf = ($_.GrantSendOnBehalfTo) -join ","
            $SendAs = (Get-RecipientPermission -Identity $UPN | Where { -not (($_.Trustee -match "NT AUTHORITY") -or ($_.Trustee -match "S-1-5-21")) }).Trustee -join ","
            $FullAccess = (Get-EXOMailboxPermission -Identity $UPN | Where { ($_.AccessRights -contains "FullAccess") -and ($_.IsInherited -eq $false) -and -not ($_.User -match "NT AUTHORITY" -or $_.User -match "S-1-5-21") }).User -join ","

            $SendOnBehalf = if ($SendOnBehalf -eq "") { "-" } else { $SendOnBehalf }
            $SendAs = if ($SendAs -eq "") { "-" } else { $SendAs }
            $FullAccess = if ($FullAccess -eq "") { "-" } else { $FullAccess }

            Write-Progress -Activity "`n     Processing room: $Count - $UPN"
            $Result = @{
                'Room Mailbox Name' = $Name
                'UPN' = $UPN
                'Full Access' = $FullAccess
                'Send As' = $SendAs
                'Send On Behalf' = $SendOnBehalf
            }
            $Results = New-Object psobject -Property $Result
            $Results | Select 'Room Mailbox Name','UPN','Full Access','Send As','Send On Behalf' | Export-Csv $Path -NoTypeInformation -Append
        }
        Write-Host "`nThe output file contains $Count room mailbox records"
    }
}

# Open output file after execution
if ((Test-Path -Path $Path) -eq $true) {
    Write-Host "`nThe output file is available at: " -NoNewline -ForegroundColor Yellow
    Write-Host $Path
    Write-Host "`n~~ Script prepared by Ryan Adams ~~`n" -ForegroundColor Green
    Write-Host "~~ Check out " -NoNewline -ForegroundColor Green
    Write-Host "https://www.governmentcontrol.net/" -ForegroundColor Yellow -NoNewline
    Write-Host " for more Microsoft 365 reports. ~~" -ForegroundColor Green
    $Prompt = New-Object -ComObject wscript.shell
    $UserInput = $Prompt.popup("Do you want to open the output file?", 0, "Open Output File", 4)
    If ($UserInput -eq 6) { Invoke-Item "$Path" }
}

# Disconnect Exchange Online session
Disconnect-ExchangeOnline -Confirm:$false
