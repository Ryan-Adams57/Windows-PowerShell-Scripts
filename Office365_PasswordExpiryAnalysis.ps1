<#
=============================================================================================
Name:           Microsoft 365 Password Expiry Analysis
Description:    Export Office 365 Users’ Last Password Change Date and expiry date using MS Graph
Website:        https://www.governmentcontrol.net/
Version:        5.1
Script by:      Ryan Adams

Script Highlights: 
~~~~~~~~~~~~~~~~~
1. A single script allows you to generate multiple password reports:
   - Export all users and their last password change and expiry date
   - List users with password never expiring
   - Export password expired users
   - Track soon-to-expire password users
   - Track recent password changes
2. Generates password reports for all or licensed users only
3. Generates password reports for all or sign-in enabled users only
4. The script uses MS Graph PowerShell and installs MS Graph PowerShell SDK if not already installed
5. Can be executed with certificate-based authentication (CBA)
6. Supports MFA-enabled accounts
7. Exports output to CSV
8. Supports certificate-based authentication

For detailed script execution: GitHub - https://github.com/Ryan-Adams57
============================================================================================
#>

Param 
( 
    [Parameter(Mandatory = $false)] 
    [switch]$PwdNeverExpires, 
    [switch]$PwdExpired, 
    [switch]$LicensedUserOnly, 
    [int]$SoonToExpire, 
    [int]$RecentPwdChanges,
    [switch]$EnabledUsersOnly,
    [string]$TenantId,
    [string]$ClientId,
    [string]$CertificateThumbprint
) 

$MsGraphBetaModule = Get-Module Microsoft.Graph.Beta -ListAvailable
if($MsGraphBetaModule -eq $null)
{ 
    Write-Host "Microsoft Graph Beta module is unavailable. Installing is required to run this script." 
    $confirm = Read-Host "Do you want to install Microsoft Graph Beta module? [Y] Yes [N] No"
    if($confirm -match "[yY]") 
    { 
        Write-Host "Installing Microsoft Graph Beta module..."
        Install-Module Microsoft.Graph.Beta -Scope CurrentUser -AllowClobber
        Write-Host "Microsoft Graph Beta module installed successfully." -ForegroundColor Magenta 
    } 
    else
    { 
        Write-Host "Exiting. Microsoft Graph Beta module is required." -ForegroundColor Red
        Exit 
    } 
}

Write-Host "Connecting to MS Graph PowerShell..."
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
        Write-Host "$ConnectionError" -ForegroundColor Red
        Exit
    }
}

$UserCount = 0 
$PrintedUser = 0 
$Result = ""
$PwdPolicy = @{}
$Location = Get-Location
$ExportCSV = "$Location\PasswordExpiryReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm-ss` tt).ToString()).csv" 

# Getting Password policy for the domain
$Domains = Get-MgBetaDomain
foreach($Domain in $Domains)
{ 
    if($Domain.AuthenticationType -eq "Federated")
    {
        $PwdValidity = 0
    }
    else
    {
        $PwdValidity = $Domain.PasswordValidityPeriodInDays
        if($PwdValidity -eq $null)
        {
            $PwdValidity = 90
        }
    }
    $PwdPolicy.Add($Domain.Id, $PwdValidity)
}

Write-Host "Generating Microsoft 365 users' password expiry report..." -ForegroundColor Magenta

# Loop through each user
Get-MgBetaUser -All -Property DisplayName,UserPrincipalName,LastPasswordChangeDateTime,PasswordPolicies,AssignedLicenses,AccountEnabled,SigninActivity | ForEach-Object { 
    $UPN = $_.UserPrincipalName
    $DisplayName = $_.DisplayName
    [boolean]$Federated = $false
    $UserCount++
    Write-Progress -Activity "`n     Processed user count: $UserCount "`n"  Currently Processing: $DisplayName"

    if($UPN -like "*#EXT#*") { return }

    $PwdLastChange = $_.LastPasswordChangeDateTime
    $PwdPolicies = $_.PasswordPolicies
    $LicenseStatus = $_.AssignedLicenses
    $LastSignInDate = $_.SignInActivity.LastSignInDateTime

    if($LastSignInDate -eq $null)
    { 
        $LastSignInDate = "Never Logged-in"
        $InactiveDays = "-"
    }
    else
    {
        $InactiveDays = (New-TimeSpan -Start $LastSignInDate).Days
    }

    $LicenseStatus = if($LicenseStatus -ne $null) { "Licensed" } else { "Unlicensed" }
    $AccountStatus = if($_.AccountEnabled) { "Enabled" } else { "Disabled" }

    $UserDomain = $UPN -Split "@" | Select-Object -Last 1
    $PwdValidityPeriod = $PwdPolicy[$UserDomain]

    if([int]$PwdValidityPeriod -eq 2147483647)
    {
        $PwdNeverExpire = $true
        $PwdExpireIn = "Never Expires"
        $PwdExpiryDate = "-"
        $PwdExpiresIn = "-"
    }
    elseif($PwdValidityPeriod -eq 0)
    {
        $Federated = $true
        $PwdExpireIn = "Insufficient data in O365"
        $PwdExpiryDate = "-"
        $PwdExpiresIn = "-"
    }
    elseif($PwdPolicies -eq "none" -or $PwdPolicies -eq "DisableStrongPassword")
    {
        $PwdExpiryDate = $PwdLastChange.AddDays($PwdValidityPeriod)
        $PwdExpiresIn = (New-TimeSpan -Start (Get-Date) -End $PwdExpiryDate).Days
        if($PwdExpiresIn -gt 0)
        {
            $PwdExpireIn = "Will expire in $PwdExpiresIn days"
        }
        elseif($PwdExpiresIn -lt 0)
        {
            $PwdExpireIn = "Expired $($PwdExpiresIn * -1) days ago"
        }
        else
        {
            $PwdExpireIn = "Today"
        }
    }
    else
    {
        $PwdExpireIn = "Never Expires"
        $PwdExpiryDate = "-"
        $PwdExpiresIn = "-"
    }

    $PwdSinceLastSet = (New-TimeSpan -Start $PwdLastChange).Days

    if(($EnabledUsersOnly.IsPresent) -and ($_.AccountEnabled -eq $false)) { return }
    if(($PwdNeverExpires.IsPresent) -and ($PwdExpireIn -ne "Never Expires")) { return }
    if(($PwdExpired.IsPresent) -and (($PwdExpiresIn -ge 0) -or ($PwdExpiresIn -eq "-"))) { return }
    if(($LicensedUserOnly.IsPresent) -and ($LicenseStatus -eq "Unlicensed")) { return }
    if(($SoonToExpire -ne "") -and (($PwdExpiryDate -eq "-") -or ($SoonToExpire -lt $PwdExpiresIn) -or ($PwdExpiresIn -lt 0))) { return }
    if(($RecentPwdChanges -ne "") -and ($PwdSinceLastSet -gt $RecentPwdChanges)) { return }

    if($Federated) {
        $PwdExpiryDate = "Insufficient data in O365"
        $PwdExpiresIn = "Insufficient data in O365"
    }

    $PrintedUser++

    $Result = [PSCustomObject]@{
        'Display Name' = $_.DisplayName
        'User Principal Name' = $UPN
        'Pwd Last Change Date' = $PwdLastChange
        'Days since Pwd Last Set' = $PwdSinceLastSet
        'Pwd Expiry Date' = $PwdExpiryDate
        'Friendly Expiry Time' = $PwdExpireIn
        'Days since Expiry(-) / Days to Expiry(+)' = $PwdExpiresIn
        'License Status' = $LicenseStatus
        'Account Status' = $AccountStatus
        'Last Sign-in Date' = $LastSignInDate
        'Inactive Days' = $InactiveDays
    }

    $Result | Export-Csv -Path $ExportCSV -NoTypeInformation -Append
}

if($UserCount -eq 0)
{
    Write-Host "No records found"
}
else
{
    Write-Host "`nThe output file contains $PrintedUser users." -ForegroundColor Green
    Write-Host "`n~~ Script prepared by Ryan Adams ~~`n" -ForegroundColor Green
    Write-Host "~~ Check out " -NoNewline -ForegroundColor Green
    Write-Host "GitHub - https://github.com/Ryan-Adams57" -ForegroundColor Yellow -NoNewline
    Write-Host " for more reporting scripts. ~~" -ForegroundColor Green

    if(Test-Path $ExportCSV) 
    {
        Write-Host "`nThe output file available in:" -NoNewline -ForegroundColor Yellow
        Write-Host " $ExportCSV `n"
        $Prompt = New-Object -ComObject wscript.shell
        $UserInput = $Prompt.popup("Do you want to open output file?", 0, "Open Output File", 4)
        if ($UserInput -eq 6) { Invoke-Item "$ExportCSV" }
    }
}

Disconnect-MgGraph | Out-Null
