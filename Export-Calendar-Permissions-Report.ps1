# ==============================================================================
# Name:           Export calendar permission Report for Exchange Online Mailboxes
# Version:        2.0
# Website:        https://www.governmentcontrol.net/
#    

# Script Highlights: 
# ~~~~~~~~~~~~~~~~~
# 1. Generates 6 different mailbox calendar permissions reports. 
# 2. The script uses modern authentication to retrieve calendar permissions. 
# 3. The script can be executed with MFA enabled account too.    
# 4. Exports report results to CSV file.    
# 5. Allows you to track all the calendars’ permission  
# 6. Helps to view default calendar permission for all the mailboxes 
# 7. Displays all the mailbox calendars to which a user has access. 
# 8. Lists calendars shared with external users. 
# 9. Helps to find out calendar permissions for a list of mailboxes through input CSV. 
# 10. Automatically install the EXO V2 module (if not installed already) upon your confirmation.   
# 11. The script is scheduler-friendly. I.e., Credential can be passed as a parameter instead of saving inside the script. 

# For detailed Script execution: https://www.governmentcontrol.net/

# Change Log
# ~~~~~~~~~~~

#     V1.0 (Nov 02, 2021) - File created
#     V1.1 (Sep 28, 2023) - Minor changes
#     V2.0 (Oct 14, 2024) - Updated the script to use REST based cmdlets and added certificate-based authentication support to enhance scheduling capability

# ==============================================================================
param (
    [string] $UserName = $null,
    [string] $Password = $null,
    [Switch] $ShowAllPermissions,
    [String] $DisplayAllCalendarsSharedTo,
    [Switch] $DefaultCalendarPermissions,
    [Switch] $ExternalUsersCalendarPermissions,
    [String] $CSVIdentityFile,
    [string]$Organization,
    [string]$ClientId,
    [string]$CertificateThumbprint
)

Function Connect_Exo
{
    # Check for EXO module installation
    $Module = Get-Module ExchangeOnlineManagement -ListAvailable
    if($Module.count -eq 0) 
    { 
        Write-Host "Exchange Online PowerShell module is not available" -ForegroundColor yellow  
        $Confirm= Read-Host "Are you sure you want to install the module? [Y] Yes [N] No"
        if($Confirm -match "[yY]") 
        { 
            Write-host "Installing Exchange Online PowerShell module"
            Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force
        } 
        else 
        { 
            Write-Host "EXO module is required to connect Exchange Online. Please install the module using Install-Module ExchangeOnlineManagement cmdlet." 
            Exit
        }
    } 
    Write-Host "Connecting to Exchange Online..."
    # Storing credentials for scheduling purpose or Passing credentials as parameter - Authentication using non-MFA account
    if(($UserName -ne "") -and ($Password -ne ""))
    {
        $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
        $Credential  = New-Object System.Management.Automation.PSCredential $UserName,$SecuredPassword
        Connect-ExchangeOnline -Credential $Credential -ShowBanner:$false
    }
    elseif($Organization -ne "" -and $ClientId -ne "" -and $CertificateThumbprint -ne "")
    {
        Connect-ExchangeOnline -AppId $ClientId -CertificateThumbprint $CertificateThumbprint -Organization $Organization -ShowBanner:$false
    }
    else
    {
        Connect-ExchangeOnline -ShowBanner:$false
    }
}

Function OutputFile_Declaration
{
    if ($DisplayAllCalendarsSharedTo -ne "")
    {
        $global:ExportCSVFileName = "CalendarsSharedTo" + $DisplayAllCalendarsSharedTo + "_" + ((Get-Date -format "MMM-dd hh-mm-ss tt").ToString()) + ".csv" 
    }
    elseif ($ShowAllPermissions.IsPresent) 
    {
        $global:ExportCSVFileName = "AllCalendarPermissionReport-" + ((Get-Date -format "MMM-dd hh-mm-ss tt").ToString()) + ".csv" 
    }
    elseif ($DefaultCalendarPermissions.IsPresent) 
    {
        $global:ExportCSVFileName = "DefaultCalendarPermissionsReport-" + ((Get-Date -format "MMM-dd hh-mm-ss tt").ToString()) + ".csv" 
    }
    elseif ($ExternalUsersCalendarPermissions.IsPresent) 
    {
        $global:ExportCSVFileName = "SharedCalendarsWithExternalUsersReport-" + ((Get-Date -format "MMM-dd hh-mm-ss tt").ToString()) + ".csv" 
    }
    else 
    {
        $global:ExportCSVFileName = "CalendarPermissionsReport-" + ((Get-Date -format "MMM-dd hh-mm-ss tt").ToString()) + ".csv" 
    }
}

# Checks the user input file availability. Then, processes the mailbox 
Function RetrieveMBs 
{
    if ([string]$CSVIdentityFile -ne "") 
    {
        $IdentityList = Import-Csv -Header "IdentityValue" $CSVIdentityFile
        foreach ($Identity in $IdentityList) {
            $CurrIdentity = $Identity.IdentityValue
            $CurrUserData = Get-EXOMailbox -identity $currIdentity -ErrorAction SilentlyContinue 
            if ($null -eq $CurrUserData) 
            {
                Write-Host "$currIdentity mailbox is not found/invalid."
            }
            else 
            {
                GetCalendars                 
            }
        }
    }
    else 
    {
        Get-EXOMailbox -ResultSize Unlimited | ForEach-Object {
            $CurrUserData = $_
            GetCalendars
        }
    }
}

Function GetCalendars
{
    $global:MailboxCount = $global:MailboxCount + 1
    $EmailAddress = $CurrUserData.PrimarySmtpAddress
    $global:DisplayName = $CurrUserData.DisplayName
    $CalendarFolders = @()
    $CalendarStats = Get-EXOMailboxFolderStatistics -Identity $EmailAddress -FolderScope Calendar
    
    # Processing the calendar folder path
    ForEach($LiveCalendarFolder in $CalendarStats) 
    {
        if (($LiveCalendarFolder.FolderType) -eq "Calendar") 
        {
            $CurrCalendarFolder = $EmailAddress + ":\Calendar"
        }
        else 
        {
            $CurrCalendarFolder = $EmailAddress + ":\Calendar\" + $LiveCalendarFolder.Name
        }
        $CalendarFolders += $CurrCalendarFolder
    }
    RetrieveCalendarPermissions
}

# Processes the mailbox calendars and retrieves the calendar permissions 
Function RetrieveCalendarPermissions 
{ 
    # Determine the use case 
    # Processing the DisplayAllCalendarsSharedTo switch param   
    if ($DisplayAllCalendarsSharedTo -ne "") 
    {
        $DisplayName = $CurrUserData.DisplayName
        $Flag = "DisplayAllCalendarsSharedTo"
        foreach($CalendarFolder in $CalendarFolders)
        {
            $CalendarName = $CalendarFolder -split "\\" | Select-Object -Last 1
            Write-Progress "Checking calendar permission in: $CalendarFolder" "Processed mailbox count: $global:MailboxCount"
            $CurrCalendarData = Get-EXOMailboxFolderPermission -Identity $CalendarFolder -User $CurrMailboxData.PrimarySmtpAddress -ErrorAction SilentlyContinue 
            if ($null -ne $CurrCalendarData) 
            {
                SaveCalendarPermissionsData
            }
        }
    }
    # Processing the ShowAllPermissions switch param  
    elseif ($ShowAllPermissions.IsPresent) 
    {
        foreach($CalendarFolder in $CalendarFolders)
        {
            $CalendarName = $CalendarFolder -split "\\" | Select-Object -Last 1
            Write-Progress "Checking calendar permission in: $CalendarFolder" "Processed mailbox count: $global:MailboxCount"
            Get-EXOMailboxFolderPermission -Identity $CalendarFolder | foreach {
                $CurrCalendarData = $_
                SaveCalendarPermissionsData
            }
        }
    }
    # Processing the DefaultCalendarPermissions switch param 
    elseif ($DefaultCalendarPermissions.IsPresent) 
    {
        $Flag = "DefaultUserCalendar"
        foreach($CalendarFolder in $CalendarFolders)
        {
            Write-Progress "Checking default calendar permission for $CalendarFolder" "Processed mailbox count: $global:MailboxCount"
            $CalendarName = $CalendarFolder -split "\\" | Select-Object -Last 1
            $CurrCalendarData = Get-EXOMailboxFolderPermission -Identity $CalendarFolder | where-Object { $_.User.ToString() -eq "Default" }
            SaveCalendarPermissionsData
        } 
    }
    # Processing the ExternalUsersCalendarPermissions switch param 
    elseif ($ExternalUsersCalendarPermissions.IsPresent) 
    {
        $Flag = "ExternalUserCalendarSharing"
        foreach($CalendarFolder in $CalendarFolders)
        {
            Write-Progress "Checking default calendar permission for $CalendarFolder" "Processed mailbox count: $global:MailboxCount"
            $CalendarName = $CalendarFolder -split "\\" | Select-Object -Last 1
            Get-EXOMailboxFolderPermission -Identity $CalendarFolder | where-Object { $_.User.DisplayName.StartsWith("ExchangePublishedUser.") } | foreach-object {
                $CurrCalendarData = $_
                SaveCalendarPermissionsData
            }
        }
    }
    #
	