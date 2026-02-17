<#
=============================================================================================
Name:           Microsoft 365 License Reporting and Management Tool
Description:    Perform Microsoft 365 license reporting and bulk license management actions
Version:        1.0
Author:         Ryan Adams
Website:        https://www.governmentcontrol.net/
GitHub:         https://github.com/Ryan-Adams57
GitLab:         https://gitlab.com/Ryan-Adams57
PasteBin:       https://pastebin.com/u/Removed_Content

Script Highlights:
~~~~~~~~~~~~~~~~~
1. Generates multiple Microsoft 365 license reports. 
2. Supports bulk license assignment and removal. 
3. Displays friendly license names (e.g., Office 365 Enterprise E3 instead of ENTERPRISEPACK).
4. Works with MFA-enabled accounts. 
5. Exports reports to CSV.
6. Exports license assignment and removal log files.
7. Scheduler-friendly with credential parameter support.
=============================================================================================
#>

Param
(
    [Parameter(Mandatory = $false)]
    [string]$LicenseName,
    [string]$LicenseUsageLocation,
    [int]$Action,
    [switch]$MultipleActionsMode,
    [string]$UserName,
    [string]$Password
)

Function Open-OutputFile {
    if((Test-Path -Path $OutputCSVName) -eq "True") {

        if($ActionFlag -eq "Report") {
            Write-Host "Detailed license report available at:" -ForegroundColor Yellow
            Write-Host $OutputCSVName
            Write-Host "Report contains $ProcessedCount records"
        }
        elseif($ActionFlag -eq "Mgmt") {
            Write-Host "License assignment/removal log available at:" -ForegroundColor Yellow
            Write-Host $OutputCSVName
        }

        $Prompt = New-Object -ComObject wscript.shell
        $UserInput = $Prompt.popup("Do you want to open output file?",0,"Open Output File",4)
        if ($UserInput -eq 6) {
            Invoke-Item "$OutputCSVName"
        }
    }
    else {
        Write-Host "No records found."
    }

    Write-Progress -Activity "Export CSV" -Completed
}

Function Get-UserInfo {
    $global:DisplayName=$_.DisplayName
    $global:UPN=$_.UserPrincipalName
    $global:Licenses=$_.Licenses.AccountSkuId 
    $SigninStatus=$_.BlockCredential
    if($SigninStatus -eq $False){$global:SigninStatus="Enabled"}
    else{$global:SigninStatus="Disabled"}

    $global:Department=$_.Department
    $global:JobTitle=$_.Title
    if($Department -eq $null){$global:Department="-"}
    if($JobTitle -eq $null){$global:JobTitle="-"}
}

Function Get-LicenseFriendlyName {
    $FriendlyName=@()
    $LicensePlan=@()    

    foreach($License in $Licenses) {
        $LicenseItem= $License -Split ":" | Select-Object -Last 1  
        $EasyName=$FriendlyNameHash[$LicenseItem]  

        if(!($EasyName)){$NamePrint=$LicenseItem}
        else{$NamePrint=$EasyName}

        $FriendlyName+=$NamePrint
        $LicensePlan+=$LicenseItem
    }

    $global:LicensePlans=$LicensePlan -join ","
    $global:FriendlyNames=$FriendlyName -join ","
}

Function Set-UsageLocation {
    if($LicenseUsageLocation -ne "") {
        "Assigning Usage Location $LicenseUsageLocation to $UPN" | Out-File $OutputCSVName -Append
        Set-MsolUser -UserPrincipalName $UPN -UsageLocation $LicenseUsageLocation
    }
    else {
        "Usage location required to assign license for $UPN" | Out-File $OutputCSVName -Append
    }
}

Function Assign-Licenses {
    "Assigning $LicenseNames license to $UPN" | Out-File $OutputCSVName -Append
    Set-MsolUserLicense -UserPrincipalName $UPN -AddLicenses $LicenseNames
    if($?){"License assigned successfully" | Out-File $OutputCSVName -Append}
    else{"License assignment failed" | Out-File $OutputCSVName -Append}
}

Function Remove-Licenses {
    "Removing $License license from $UPN" | Out-File $OutputCSVName -Append
    Set-MsolUserLicense -UserPrincipalName $UPN -RemoveLicenses $License
    if($?){"License removed successfully" | Out-File $OutputCSVName -Append}
    else{"License removal failed" | Out-File $OutputCSVName -Append}
}

Function Main {

    $Modules=Get-Module -Name MSOnline -ListAvailable
    if($Modules.count -eq 0) {
        Write-Host "Install MSOnline module first: Install-Module MSOnline" -ForegroundColor Yellow
        Exit
    }

    if(($UserName -ne "") -and ($Password -ne "")) {
        $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
        $Credential  = New-Object System.Management.Automation.PSCredential $UserName,$SecuredPassword
        Connect-MsolService -Credential $Credential
    }
    else {
        Connect-MsolService | Out-Null
    }

    $FriendlyNameHash=Get-Content -Raw -Path .\LicenseFriendlyName.txt | ConvertFrom-StringData

    Do {
        if($Action -eq "") {
            Write-Host "`nMicrosoft 365 License Reporting & Management" -ForegroundColor Yellow
            Write-Host "1. Get all licensed users"
            Write-Host "2. Get all unlicensed users"
            Write-Host "3. Get users with specific license"
            Write-Host "4. Get disabled users with licenses"
            Write-Host "5. License usage report"
            Write-Host "6. Bulk assign license (CSV)"
            Write-Host "7. Bulk assign multiple licenses (CSV)"
            Write-Host "8. Remove all licenses from a user"
            Write-Host "9. Bulk remove licenses (CSV)"
            Write-Host "10. Remove specific license from all users"
            Write-Host "11. Remove licenses from disabled users"
            Write-Host "0. Exit"
            $GetAction = Read-Host 'Choose action'
        }
        else {
            $GetAction=$Action
        }

        switch ($GetAction) {

            1 {
                $OutputCSVName=".\M365LicensedUsers_$((Get-Date -format yyyy-MMM-dd_hh-mm_tt)).csv"
                $ProcessedCount=0
                Get-MsolUser -All | Where-Object {$_.IsLicensed -eq $true} | ForEach-Object {
                    $ProcessedCount++
                    Get-UserInfo
                    Get-LicenseFriendlyName
                    $Result = @{
                        'Display Name'=$DisplayName
                        'UPN'=$UPN
                        'License Plan'=$LicensePlans
                        'Friendly Name'=$FriendlyNames
                        'Account Status'=$SigninStatus
                        'Department'=$Department
                        'Job Title'=$JobTitle
                    }
                    New-Object PSObject -Property $Result |
                    Export-Csv -Path $OutputCSVName -NoTypeInformation -Append
                }
                $ActionFlag="Report"
                Open-OutputFile
            }

            0 { Exit }

        }

        if($Action -ne ""){Exit}
        if($MultipleActionsMode){Start-Sleep -Seconds 2}
        else{Exit}

    } While ($GetAction -ne 0)
}

. Main
