<#
=============================================================================================
Name:           Manage Microsoft 365 licenses using MS Graph PowerShell
Description:    This script can perform 10+ Office 365 reporting and management activities
Website:        https://www.governmentcontrol.net/
Author:         Ryan Adams
GitHub:         https://github.com/Ryan-Adams57
GitLab:         https://gitlab.com/Ryan-Adams57
PasteBin:       https://pastebin.com/u/Removed_Content

Script Highlights :
~~~~~~~~~~~~~~~~~

1.	The script uses MS Graph PowerShell module.
2.	Generates 5 Office 365 license reports.
3.	Allows you to perform 6 license management actions that include adding or removing licenses in bulk.
4.	License Name is shown with its friendly name like ‘Office 365 Enterprise E3’ rather than ‘ENTERPRISEPACK’.
5.	Automatically installs MS Graph PowerShell module (if not installed already) upon your confirmation.
6.	The script can be executed with an MFA enabled account too.
7.	Exports the report result to CSV.
8.	Exports license assignment and removal log file.


Change Log
~~~~~~~~~~
  V1.0 (Sep 08, 2022) - File created
  V2.0 (Mar 10, 2025)  - Upgraded from MS Graph beta to production version
  V2.1 (Mar 21, 2025)  - Feature break due to module upgrade fixed.
  V2.2 (Mar 26, 2025) - Used 'Property' param to retrive user properties.
  V2.3 (Apr 05, 2025) - Updated license friendly name with latest changes and converted it as CSV file

============================================================================================
#>
Param
(
    [Parameter(Mandatory = $false)]
    [string]$LicenseName,
    [string]$LicenseUsageLocation,
    [int]$Action,
    [switch]$MultipleActionsMode
)

function Connect_MgGraph {
    $MsGraphBetaModule =  Get-Module Microsoft.Graph -ListAvailable
    if($MsGraphBetaModule -eq $null)
    { 
        Write-host "Important: Microsoft Graph PowerShell module is unavailable. It is mandatory to have this module installed in the system to run the script successfully." 
        $confirm = Read-Host Are you sure you want to install Microsoft Graph PowerShell module? [Y] Yes [N] No  
        if($confirm -match "[yY]") 
        { 
            Write-host "Installing Microsoft Graph PowerShell module..."
            Install-Module Microsoft.Graph -Scope CurrentUser -AllowClobber
            Write-host "Microsoft Graph PowerShell module is installed in the machine successfully" -ForegroundColor Magenta 
        } 
        else
        { 
            Write-host "Exiting. `nNote: Microsoft Graph PowerShell module must be available in your system to run the script" -ForegroundColor Red
            Exit 
        } 
    }
    Write-Progress "Importing Required Modules..."
    Import-Module -Name Microsoft.Graph.Identity.DirectoryManagement
    Import-Module -Name Microsoft.Graph.Users
    Import-Module -Name Microsoft.Graph.Users.Actions
    Write-Progress "Connecting MgGraph Module..."
    Connect-MgGraph -Scopes "Directory.ReadWrite.All" -NoWelcome
}

Function Open_OutputFile {
    if ((Test-Path -Path $OutputCSVName) -eq "True") {
        if ($ActionFlag -eq "Report") {
            Write-Host Detailed license report is available in: -NoNewline -Foregroundcolor Yellow; Write-Host $OutputCSVName
            Write-Host The report has $ProcessedCount records.
        }
        elseif ($ActionFlag -eq "Mgmt") {
            Write-Host License assignment/removal log file is available in: -NoNewline -Foregroundcolor Yellow; Write-Host $OutputCSVName
        } 
        $Prompt = New-Object -ComObject wscript.shell  
        $UserInput = $Prompt.popup("Do you want to open output file?", 0, "Open Output File", 4)  
        If ($UserInput -eq 6) {  
            Invoke-Item "$OutputCSVName"  
        } 
    }
    else {
        Write-Host No records found
    }
    Write-Host "`n~~ Script prepared by Ryan Adams ~~`n" -ForegroundColor Green
    Write-Host "~~ Visit https://www.governmentcontrol.net/ for more Microsoft 365 automation resources. ~~" -ForegroundColor Green `n`n
    Write-Progress -Activity Export CSV -Completed
}

Function Get_UserInfo {
    $global:DisplayName = $_.DisplayName
    $global:UPN = $_.UserPrincipalName
    $global:Licenses = $_.AssignedLicenses.SkuId
    $SigninStatus = $_.AccountEnabled
    if ($SigninStatus -eq $False) { 
        $global:SigninStatus = "Disabled" 
    }
    else {
        $global:SigninStatus = "Enabled"
    }
    $global:Department = $_.Department
    $global:JobTitle = $_.JobTitle
    if ($Department -eq $null) {
        $global:Department = "-"
    }
    if ($JobTitle -eq $null) {
        $global:JobTitle = "-"
    }
}

Function Get_License_FriendlyName {
    $FriendlyName = @()
    $LicensePlan = @()    
    foreach ($License in $Licenses) {   
        $LicenseItem = $SkuIdHash[$License]  
        $EasyName = $FriendlyNameHash[$LicenseItem]  
        if (!($EasyName)) {
            $NamePrint = $LicenseItem 
        }  
        else {
            $NamePrint = $EasyName 
        } 
        $FriendlyName = $FriendlyName + $NamePrint
        $LicensePlan = $LicensePlan + $LicenseItem
    }
    $global:LicensePlans = $LicensePlan -join ","
    $global:FriendlyNames = $FriendlyName -join ","
}

Function Set_UsageLocation {
    if ($LicenseUsageLocation -ne "") {
        "Assigning Usage Location $LicenseUsageLocation to $UPN" |  Out-File $OutputCSVName -Append
        Update-MgUser -UserId $UPN -UsageLocation $LicenseUsageLocation
        if(!($?))
        {
         "Error occurred while assigning usage location to $UPN or user not found" |  Out-File $OutputCSVName -Append
         Continue
         }
    }
    else {
        "Usage location is mandatory to assign license. Please set Usage location for $UPN" |  Out-File $OutputCSVName -Append
        Continue
    }
}

Function Assign_Licenses {
    "Assigning $LicenseNames license to $UPN" | Out-File $OutputCSVName -Append
    Set-MgUserLicense -UserId $UPN -AddLicenses @{SkuId = $SkuPartNumberHash[$LicenseNames] } -RemoveLicenses @() | Out-Null
    if ($?) {
        "License assigned successfully" | Out-File $OutputCSVName -Append
    }
    else {
        "License assignment failed" | Out-file $OutputCSVName -Append
    }
}

Function Remove_Licenses {
    $SkuPartNumber = @()
    foreach ($Temp in $License) {
        $SkuPartNumber += $SkuIdHash[$Temp]
    }
    $SkuPartNumber = $SkuPartNumber -join (",")
    Write-Progress -Activity "`n     Removing $SkuPartNumber license from $UPN "`n"  Processed users: $ProcessedCount"
    "Removing $SkuPartNumber license from $UPN" | Out-File $OutputCSVName -Append
    Set-MgUserLicense -UserId $UPN -RemoveLicenses @($License) -AddLicenses @() | Out-Null
    if ($?) {
        "License removed successfully" | Out-File $OutputCSVName -Append
    }
    else {
        "License removal failed" | Out-file $OutputCSVName -Append
    }
}

Function main() {
    Disconnect-MgGraph -ErrorAction SilentlyContinue|Out-Null
    Connect_MgGraph
    $Result = ""  
    $Results = @() 
    $FriendlyNameHash = @{}
    Import-Csv -Path .\LicenseFriendlyName.csv -ErrorAction Stop | ForEach-Object {
        $FriendlyNameHash[$_.string_id] = $_.Product_Display_Name
    }
    $SkuPartNumberHash = @{} 
    $SkuIdHash = @{} 
    Get-MgSubscribedSku -All | Select-Object SkuPartNumber, SkuId | ForEach-Object {
        $SkuPartNumberHash.add(($_.SkuPartNumber), ($_.SkuId))
        $SkuIdHash.add(($_.SkuId), ($_.SkuPartNumber))
    }

    Do {                 
        if ($Action -eq "") {                       
            Write-Host ""
            Write-host `nOffice 365 License Reporting -ForegroundColor Yellow
            Write-Host  "    1.Get all licensed users" -ForegroundColor Cyan
            Write-Host  "    2.Get all unlicensed users" -ForegroundColor Cyan
            Write-Host  "    3.Get users with specific license type" -ForegroundColor Cyan
            Write-Host  "    4.Get all disabled users with licenses" -ForegroundColor Cyan
            Write-Host  "    5.Office 365 license usage report" -ForegroundColor Cyan
            Write-Host `nOffice 365 License Management -ForegroundColor Yellow
            Write-Host  "    6.Bulk:Assign a license to users (input CSV)" -ForegroundColor Cyan
            Write-Host  "    7.Bulk:Assign multiple licenses to users (input CSV)" -ForegroundColor Cyan
            Write-Host  "    8.Remove all license from a user" -ForegroundColor Cyan
            Write-Host  "    9.Bulk:Remove all licenses from users (input CSV)" -ForegroundColor Cyan
            Write-Host  "    10.Remove specific license from all users" -ForegroundColor Cyan
            Write-Host  "    11.Remove all license from disabled users" -ForegroundColor Cyan
            Write-Host  "    0.Exit" -ForegroundColor Cyan
            Write-Host ""
            $GetAction = Read-Host 'Please choose the action to continue' 
        }
        else {
            $GetAction = $Action
        }

        Switch ($GetAction) {
            1 {
                $OutputCSVName = ".\O365UserLicenseReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"
                $RequiredProperties=@('UserPrincipalName','DisplayName','AccountEnabled','Department','JobTitle','AssignedLicenses') 
                Write-Host Generating licensed users report...
                $ProcessedCount = 0
                Get-MgUser -All -Property $RequiredProperties | Where-Object {($_.AssignedLicenses.Count) -ne 0 } | ForEach-Object {
                    $ProcessedCount++
                    Get_UserInfo
                    Write-Progress -Activity "`n     Processed users count: $ProcessedCount "`n"  Currently Processing: $DisplayName"
                    Get_License_FriendlyName
                    $Result = @{'Display Name' = $Displayname; 'UPN' = $UPN; 'License Plan' = $LicensePlans; 'License Plan Friendly Name' = $FriendlyNames; 'Account Status' = $SigninStatus; 'Department' = $Department; 'Job Title' = $JobTitle }
                    $Results = New-Object PSObject -Property $Result
                    $Results | select-object 'Display Name', 'UPN', 'License Plan', 'License Plan Friendly Name', 'Account Status', 'Department', 'Job Title' | Export-Csv -Path $OutputCSVName -Notype -Append
                }
                $ActionFlag = "Report"
                Open_OutputFile
            }
        }
    }
    While ($GetAction -ne 0)
    Disconnect-MgGraph
    Write-Host "Disconnected active Microsoft Graph session"
    Clear-Host
}
. main
