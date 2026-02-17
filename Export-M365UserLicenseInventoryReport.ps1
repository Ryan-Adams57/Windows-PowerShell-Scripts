<#
=============================================================================================
Name:           Export Microsoft 365 Users License Report
Description:    This script exports Microsoft 365 user license details to CSV files
Version:        1.0
Author:         Ryan Adams
Website:        https://www.governmentcontrol.net/
GitHub:         https://github.com/Ryan-Adams57
GitLab:         https://gitlab.com/Ryan-Adams57
PasteBin:       https://pastebin.com/u/Removed_Content

~~~~~~~~~~~~~~~~~
Script Highlights:
~~~~~~~~~~~~~~~~~
1. Uses Microsoft Graph PowerShell and installs Microsoft Graph PowerShell SDK (if not installed already) upon confirmation. 
2. Supports certificate-based authentication (CBA).
3. Exports Microsoft 365 user license report to CSV files.
4. Allows exporting license report for all users or from an input file with specific users.
5. Displays license names with friendly names where available.
6. Supports MFA-enabled accounts.
7. Generates two output files: a detailed report and a simplified report.
============================================================================================
#>

Param
(
    [Parameter(Mandatory = $false)]
    [string]$UserNamesFile,
    [string]$TenantId,
    [string]$ClientId,
    [string]$CertificateThumbprint
)

Function ConnectMgGraphModule 
{
    $MsGraphBetaModule = Get-Module Microsoft.Graph.Beta -ListAvailable
    if($MsGraphBetaModule -eq $null)
    { 
        Write-Host "Important: Microsoft Graph Beta module is unavailable. It is mandatory to have this module installed in the system to run the script successfully." 
        $confirm = Read-Host "Are you sure you want to install Microsoft Graph Beta module? [Y] Yes [N] No"  
        if($confirm -match "[yY]") 
        { 
            Write-Host "Installing Microsoft Graph Beta module..."
            Install-Module Microsoft.Graph.Beta -Scope CurrentUser -AllowClobber
            Write-Host "Microsoft Graph Beta module is installed successfully." -ForegroundColor Magenta 
        } 
        else
        { 
            Write-Host "Exiting. Note: Microsoft Graph Beta module must be available in your system to run the script." -ForegroundColor Red
            Exit 
        } 
    }

    if(($TenantId -ne "") -and ($ClientId -ne "") -and ($CertificateThumbprint -ne ""))  
    {  
        Connect-MgGraph -TenantId $TenantId -AppId $ClientId -CertificateThumbprint $CertificateThumbprint -ErrorAction SilentlyContinue -ErrorVariable ConnectionError | Out-Null
        if($ConnectionError -ne $null)
        {    
            Write-Host $ConnectionError -ForegroundColor Red
            Exit
        }
    }
    else
    {
        Connect-MgGraph -Scopes "Directory.Read.All" -ErrorAction SilentlyContinue -ErrorVariable ConnectionError | Out-Null
        if($ConnectionError -ne $null)
        {
            Write-Host $ConnectionError -ForegroundColor Red
            Exit
        }
    }

    Write-Host "Microsoft Graph Beta PowerShell module connected successfully." -ForegroundColor Green
}

Function Get_UsersLicenseInfo
{
    $LicensePlanWithEnabledService=""
    $FriendlyNameOfLicensePlanWithService=""
    $UPN = $_.UserPrincipalName
    $Country = $_.Country
    if($Country -eq "")
    {
        $Country="-"
    }

    Write-Progress -Activity "`n     Exported user count:$LicensedUserCount " -Status "Currently Processing:$UPN"

    $SKUs = Get-MgBetaUserLicenseDetail -UserId $UPN -ErrorAction SilentlyContinue
    $LicenseCount = $SKUs.count
    $count = 0

    foreach($Sku in $SKUs)
    {
        if($FriendlyNameHash[$Sku.SkuPartNumber])
        {
            $NamePrint = $FriendlyNameHash[$Sku.SkuPartNumber]
        }
        else
        {
            $NamePrint = $Sku.SkuPartNumber
        }

        $Services = $Sku.ServicePlans

        if(($Count -gt 0) -and ($count -lt $LicenseCount))
        {
            $LicensePlanWithEnabledService += ","
            $FriendlyNameOfLicensePlanWithService += ","
        }

        $DisabledServiceCount = 0
        $EnabledServiceCount = 0
        $serviceExceptDisabled = ""
        $FriendlyNameOfServiceExceptDisabled = ""

        foreach($Service in $Services)
        {
            $flag = 0
            $ServiceName = $Service.ServicePlanName

            if($Service.ProvisioningStatus -eq "Disabled")
            {
                $DisabledServiceCount++
            }
            else
            {
                $EnabledServiceCount++
                if($EnabledServiceCount -ne 1)
                {
                    $serviceExceptDisabled += ","
                }
                $serviceExceptDisabled += $ServiceName
                $flag = 1
            }

            $ServiceFriendlyName = $ServiceArray | Where-Object { $_.Service_Plan_Name -eq $ServiceName }
            if($ServiceFriendlyName -ne $Null)
            {
                $ServiceFriendlyName = $ServiceFriendlyName[0].ServiceFriendlyNames
            }
            else
            {
                $ServiceFriendlyName = $ServiceName
            }

            if($flag -eq 1)
            {
                if($EnabledServiceCount -ne 1)
                {
                    $FriendlyNameOfServiceExceptDisabled += ","
                }
                $FriendlyNameOfServiceExceptDisabled += $ServiceFriendlyName
            }

            $Result = [PSCustomObject]@{
                'DisplayName'=$_.Displayname
                'UserPrincipalName'=$UPN
                'LicensePlan'=$Sku.SkuPartNumber
                'FriendlyNameofLicensePlan'=$NamePrint
                'ServiceName'=$ServiceName
                'FriendlyNameofServiceName'=$ServiceFriendlyName
                'ProvisioningStatus'=$Service.ProvisioningStatus
            }

            $Result | Export-Csv -Path $ExportCSV -NoTypeInformation -Append
        }

        if($DisabledServiceCount -eq 0)
        {
            $serviceExceptDisabled = "All services"
            $FriendlyNameOfServiceExceptDisabled = "All services"
        }

        $LicensePlanWithEnabledService += $Sku.SkuPartNumber + "[" + $serviceExceptDisabled + "]"
        $FriendlyNameOfLicensePlanWithService += $NamePrint + "[" + $FriendlyNameOfServiceExceptDisabled + "]"

        $count++
     }

     $Output=[PSCustomObject]@{
        'Displayname'=$_.Displayname
        'UserPrincipalName'=$UPN
        'Country'=$Country
        'LicensePlanWithEnabledService'=$LicensePlanWithEnabledService
        'FriendlyNameOfLicensePlanAndEnabledService'=$FriendlyNameOfLicensePlanWithService
     }

     $Output | Export-Csv -Path $ExportSimpleCSV -NoTypeInformation -Append
}

Function CloseConnection
{
    Disconnect-MgGraph | Out-Null
    Exit
}

Function main()
{
    ConnectMgGraphModule

    Write-Host "`nNote: If you encounter module related conflicts, run the script in a fresh PowerShell window." -ForegroundColor Yellow

    $ExportCSV = ".\DetailedM365UserLicenseReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"
    $ExportSimpleCSV = ".\SimpleM365UserLicenseReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"

    try{
        $FriendlyNameHash = Get-Content -Raw -Path .\LicenseFriendlyName.txt -ErrorAction SilentlyContinue -ErrorVariable ERR | ConvertFrom-StringData
        if($ERR -ne $null)
        {
            Write-Host $ERR -ForegroundColor Red
            CloseConnection
        }

        $ServiceArray = Import-Csv -Path .\ServiceFriendlyName.csv 
    }
    catch
    {
        Write-Host $_.Exception.Message -ForegroundColor Red
        CloseConnection
    }

    $LicensedUserCount = 0

    if($UserNamesFile -ne "")
    {
        $UserNames = Import-Csv -Header "UserPrincipalName" $UserNamesFile
        foreach($item in $UserNames)
        {
            Get-MgBetaUser -UserId $item.UserPrincipalName -ErrorAction SilentlyContinue |
            Where-Object { $_.AssignedLicenses -ne $null } |
            ForEach-Object {
                Get_UsersLicenseInfo
                $LicensedUserCount++
            }
        }
    }
    else
    {
        Get-MgBetaUser -All |
        Where-Object { $_.AssignedLicenses -ne $null } |
        ForEach-Object {
            Get_UsersLicenseInfo
            $LicensedUserCount++
        }
    }

    if((Test-Path -Path $ExportCSV) -eq "True") 
    {   
        Write-Host "`nDetailed report available in:" -NoNewline -ForegroundColor Yellow
        Write-Host "$ExportCSV" 
        Write-Host "`nSimple report available in:" -NoNewline -ForegroundColor Yellow
        Write-Host "$ExportSimpleCSV`n"

        $Prompt = New-Object -ComObject wscript.shell
        $UserInput = $Prompt.popup("Do you want to open output files?",0,"Open Files",4)
        if($UserInput -eq 6)
        {
            Invoke-Item $ExportCSV
            Invoke-Item $ExportSimpleCSV
        }
    }
    else
    {
        Write-Host "No data found" 
    }

    Write-Host "`n~~ Script prepared by Ryan Adams ~~`n" -ForegroundColor Green
    Write-Host "Website: https://www.governmentcontrol.net/" -ForegroundColor Yellow
    Write-Host "GitHub: https://github.com/Ryan-Adams57" -ForegroundColor Yellow
    Write-Host "GitLab: https://gitlab.com/Ryan-Adams57" -ForegroundColor Yellow
    Write-Host "PasteBin: https://pastebin.com/u/Removed_Content`n" -ForegroundColor Yellow

    CloseConnection
}

. main
