<#
=============================================================================================
Name:           Export Office 365 users real last activity time report
Version:        3.0
Website:        https://www.governmentcontrol.net/
Author:         Ryan Adams
GitHub:         https://github.com/Ryan-Adams57
Gitlab:         https://gitlab.com/Ryan-Adams57
PasteBin:       https://pastebin.com/u/Removed_Content

Script Highlights: 
~~~~~~~~~~~~~~~~~

1. Reports user activity time based on LastUserActionTime. 
2. Exports results to CSV. 
3. Filters by inactive days. 
4. Filters by user/mailbox type. 
5. Optionally filters never logged in mailboxes. 
6. Optionally filters licensed users. 
7. Shows administrative roles for each user. 
8. Assigned licenses shown with user-friendly names. 
9. Supports MFA-enabled accounts. 
10. Scheduler friendly: credentials can be passed as parameters. 
============================================================================================
#>

Param (
    [Parameter(Mandatory = $false)]
    [string]$MBNamesFile,
    [int]$InactiveDays,
    [switch]$UserMailboxOnly,
    [switch]$LicensedUserOnly,
    [switch]$ReturnNeverLoggedInMBOnly,
    [string]$UserName,
    [string]$Password,
    [switch]$FriendlyTime,
    [switch]$NoMFA
)

Function Get_LastLogonTime {
    $MailboxStatistics = Get-MailboxStatistics -Identity $upn
    $LastActionTime = $MailboxStatistics.LastUserActionTime
    $LastActionTimeUpdatedOn = $MailboxStatistics.LastUserActionUpdateTime
    $RolesAssigned = ""
    Write-Progress -Activity "`nProcessed mailbox count: $MBUserCount`nCurrently Processing: $DisplayName"

    if(-not $LastActionTime) {
        $LastActionTime = "Never Logged In"
        $InactiveDaysOfUser = "-"
    } else {
        $InactiveDaysOfUser = (New-TimeSpan -Start $LastActionTime).Days
        if($FriendlyTime.IsPresent) {
            $FriendlyLastActionTime = ConvertTo-HumanDate ($LastActionTime)
            $LastActionTime = "$LastActionTime ($FriendlyLastActionTime)"
        }
    }

    if($FriendlyTime.IsPresent -and $LastActionTimeUpdatedOn) {
        $FriendlyLastActionTimeUpdatedOn = ConvertTo-HumanDate ($LastActionTimeUpdatedOn)
        $LastActionTimeUpdatedOn = "$LastActionTimeUpdatedOn ($FriendlyLastActionTimeUpdatedOn)"
    } elseif(-not $LastActionTimeUpdatedOn) {
        $LastActionTimeUpdatedOn = "-"
    }

    $User = Get-MsolUser -UserPrincipalName $upn
    $Licenses = $User.Licenses.AccountSkuId
    $AssignedLicense = ""

    if($Licenses.Count -eq 0) { 
        $AssignedLicense = "No License Assigned" 
    } else {
        for($i=0; $i -lt $Licenses.Count; $i++) {
            $LicenseItem = ($Licenses[$i] -split ":")[-1]
            $NamePrint = $FriendlyNameHash[$LicenseItem] ? $FriendlyNameHash[$LicenseItem] : $LicenseItem
            $AssignedLicense += $NamePrint
            if($i -lt $Licenses.Count - 1) { $AssignedLicense += "," }
        }
    }

    if($InactiveDaysOfUser -ne "-" -and $InactiveDays -and $InactiveDays -gt $InactiveDaysOfUser) { return }
    if($UserMailboxOnly.IsPresent -and $MBType -ne "UserMailbox") { return }
    if($ReturnNeverLoggedInMBOnly.IsPresent -and $LastActionTime -ne "Never Logged In") { return }
    if($LicensedUserOnly.IsPresent -and $AssignedLicense -eq "No License Assigned") { return }

    $Roles = (Get-MsolUserRole -UserPrincipalName $upn).Name
    if($Roles.Count -eq 0) { 
        $RolesAssigned = "No roles" 
    } else {
        $RolesAssigned = ($Roles -join ",")
    }

    $Result = @{
        'UserPrincipalName'     = $upn
        'DisplayName'           = $DisplayName
        'LastUserActionTime'    = $LastActionTime
        'LastActionTimeUpdatedOn' = $LastActionTimeUpdatedOn
        'CreationTime'          = $CreationTime
        'InactiveDays'          = $InactiveDaysOfUser
        'MailboxType'           = $MBType
        'AssignedLicenses'      = $AssignedLicense
        'Roles'                 = $RolesAssigned
    }

    $Output = New-Object PSObject -Property $Result
    $Output | Select-Object UserPrincipalName, DisplayName, LastUserActionTime, LastActionTimeUpdatedOn, InactiveDays, CreationTime, MailboxType, AssignedLicenses, Roles | Export-Csv -Path $ExportCSV -NoTypeInformation -Append
}

Function main {
    if(-not (Get-Module ExchangeOnlineManagement -ListAvailable)) {
        Write-Host "Exchange Online PowerShell V2 module not found" -ForegroundColor Yellow
        $Confirm = Read-Host "Install module? [Y/N]"
        if($Confirm -match "[yY]") {
            Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force
            Import-Module ExchangeOnlineManagement
        } else { Exit }
    }

    if(-not (Get-Module MsOnline -ListAvailable)) {
        Write-Host "MSOnline module not found" -ForegroundColor Yellow
        $Confirm = Read-Host "Install module? [Y/N]"
        if($Confirm -match "[yY]") {
            Install-Module MSOnline -Repository PSGallery -AllowClobber -Force
            Import-Module MSOnline
        } else { Exit }
    }

    if($NoMFA.IsPresent) {
        if($UserName -and $Password) {
            $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
            $Credential = New-Object System.Management.Automation.PSCredential $UserName, $SecuredPassword
        } else {
            $Credential = Get-Credential
        }
        Write-Host "Connecting Azure AD..."
        Connect-MsolService -Credential $Credential | Out-Null
        Write-Host "Connecting Exchange Online..."
        Connect-ExchangeOnline -Credential $Credential
    } else {
        Write-Host "Connecting Exchange Online..."
        Connect-ExchangeOnline
        Write-Host "Connecting Azure AD..."
        Connect-MsolService | Out-Null
    }

    if($FriendlyTime.IsPresent -and -not (Get-Module -Name PowerShellHumanizer -ListAvailable)) {
        Write-Host "Installing PowerShellHumanizer for friendly date/time"
        Install-Module PowerShellHumanizer
    }

    $MBUserCount = 0
    $Output = @()
    $FriendlyNameHash = Get-Content -Raw -Path .\LicenseFriendlyName.txt -ErrorAction Stop | ConvertFrom-StringData
    $ExportCSV = ".\LastAccessTimeReport_$(Get-Date -Format 'yyyy-MMM-dd-ddd_hh-mm_tt').csv"

    if($MBNamesFile) {
        $Mailboxes = Import-Csv -Header "MBIdentity" $MBNamesFile
        foreach($item in $Mailboxes) {
            $MBDetails = Get-Mailbox -Identity $item.MBIdentity
            $upn = $MBDetails.UserPrincipalName
            $CreationTime = $MBDetails.WhenCreated
            $DisplayName = $MBDetails.DisplayName
            $MBType = $MBDetails.RecipientTypeDetails
            $MBUserCount++
            Get_LastLogonTime
        }
    } else {
        Write-Progress -Activity "Getting Mailbox details from Office 365..." -Status "Please wait."
        Get-Mailbox -ResultSize Unlimited | Where { $_.DisplayName -notlike "Discovery Search Mailbox" } | ForEach-Object {
            $upn = $_.UserPrincipalName
            $CreationTime = $_.WhenCreated
            $DisplayName = $_.DisplayName
            $MBType = $_.RecipientTypeDetails
            $MBUserCount++
            Get_LastLogonTime
        }
    }

    Write-Host "`nScript executed successfully"
    if(Test-Path $ExportCSV) {
        Write-Host "`nDetailed report available at:" -NoNewline -ForegroundColor Yellow
        Write-Host $ExportCSV
        Write-Host "`n~~ Script prepared by Ryan Adams ~~" -ForegroundColor Green
        Write-Host "~~ Check out " -NoNewline -ForegroundColor Green; Write-Host "https://www.governmentcontrol.net/" -ForegroundColor Yellow -NoNewline; Write-Host " for more tools and resources. ~~" -ForegroundColor Green
        $Prompt = New-Object -ComObject wscript.shell
        $UserInput = $Prompt.popup("Do you want to open output file?", 0, "Open Output File", 4)
        if($UserInput -eq 6) { Invoke-Item $ExportCSV }
    } else {
        Write-Host "No mailbox found" -ForegroundColor Red
    }

    Get-PSSession | Remove-PSSession
}

.main
