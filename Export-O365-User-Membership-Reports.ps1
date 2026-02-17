<#
=============================================================================================
Name:           Office365 User Membership Report Using PowerShell
Description:    This script exports Office 365 user's group details to CSV
Version:        3.0
Website:        https://www.governmentcontrol.net/

Script Highlights :
~~~~~~~~~~~~~~~~~

1. Generates 12 different user membership reports.
2. The script uses MS Graph PowerShell and installs MS Graph PowerShell SDK (if not installed already) upon your confirmation. 
3. It can be executed with certificate-based authentication (CBA) too.
4. Supports both MFA and Non-MFA accounts.  
5. Allow to use filter to get guest users and their membership alone. 
6. Allow to use filter to get disabled users’ membership. 
7. Helps to identify users who are not members of any groups. 
8. Exports report result to CSV.
9. The script is scheduler-friendly. 

For detailed script execution: https://www.governmentcontrol.net/
============================================================================================
#>

param
(
    [String] $UsersIdentityFile,
    [Switch] $GuestUsersOnly,
    [Switch] $DisabledUsersOnly,
    [Switch] $UsersNotinAnyGroup,
    [string] $TenantId,
    [string] $ClientId,
    [string] $CertificateThumbprint
)

# Check for MS Graph PowerShell module
$MsGraphBetaModule = Get-Module Microsoft.Graph.Beta -ListAvailable
if($MsGraphBetaModule -eq $null)
{
    Write-host "Important: Microsoft Graph Beta module is unavailable. It is mandatory to have this module installed in the system to run the script successfully."
    $confirm = Read-Host "Are you sure you want to install Microsoft Graph Beta module? [Y] Yes [N] No"
    if($confirm -match "[yY]")
    {
        Write-host "Installing Microsoft Graph Beta module..."
        Install-Module Microsoft.Graph.Beta -Scope CurrentUser -AllowClobber
        Write-host "Microsoft Graph Beta module is installed successfully" -ForegroundColor Magenta
    }
    else
    {
        Write-host "Exiting. Microsoft Graph Beta module must be available in your system to run the script." -ForegroundColor Red
        Exit
    }
}

# Connect to Microsoft Graph with certificate-based or interactive authentication
if(($TenantId -ne "") -and ($ClientId -ne "") -and ($CertificateThumbprint -ne ""))
{
    Connect-MgGraph -TenantId $TenantId -AppId $ClientId -CertificateThumbprint $CertificateThumbprint -ErrorAction SilentlyContinue -ErrorVariable ConnectionError | Out-Null
    if($ConnectionError -ne $null)
    {
        Write-Host $ConnectionError -Foregroundcolor Red
        Exit
    }
}
else
{
    Connect-MgGraph -Scopes "Directory.Read.All" -ErrorAction SilentlyContinue -ErrorVariable ConnectionError | Out-Null
    if($ConnectionError -ne $null)
    {
        Write-Host "$ConnectionError" -Foregroundcolor Red
        Exit
    }
}

Write-Host "Microsoft Graph Beta PowerShell module is connected successfully" -ForegroundColor Green
Write-Host "`nNote: If you encounter module related conflicts, run the script in a fresh PowerShell window."

# Function to process user membership data
Function UserDetails {
    if ([string]$UsersIdentityFile -ne "")
    {
        $IdentityList = Import-Csv -Header "UserIdentityValue" $UsersIdentityFile
        foreach ($IdentityValue in $IdentityList)
        {
            $CurIdentity = $IdentityValue.UserIdentityValue
            try
            {
                $LiveUser = Get-MgBetaUser -UserId "$CurIdentity" -ExpandProperty MemberOf -ErrorAction SilentlyContinue
                if($GuestUsersOnly.IsPresent -and $LiveUser.UserType -ne "Guest")
                {
                    continue
                }
                if($DisabledUsersOnly.IsPresent -and $LiveUser.AccountEnabled -eq $true)
                {
                    continue
                }
                ProcessUser
            }
            catch
            {
                Write-Host "Given UserIdentity: $CurIdentity is not valid/found."
            }
        }
    }
    else
    {
        if ($GuestUsersOnly.IsPresent -and $DisabledUsersOnly.IsPresent)
        {
            Get-MgBetaUser -Filter "UserType eq 'Guest'" -ExpandProperty MemberOf -All | Where-Object { $_.AccountEnabled -eq $false } | ForEach-Object {
                $LiveUser = $_
                ProcessUser
            }
        }
        elseif ($DisabledUsersOnly.IsPresent)
        {
            Get-MgBetaUser -ExpandProperty MemberOf -All | Where-Object { $_.AccountEnabled -eq $false } | ForEach-Object {
                $LiveUser = $_
                ProcessUser
            }
        }
        elseif ($GuestUsersOnly.IsPresent)
        {
            Get-MgBetaUser -Filter "UserType eq 'Guest'" -ExpandProperty MemberOf -All | ForEach-Object {
                $LiveUser = $_
                ProcessUser
            }
        }
        else
        {
            Get-MgBetaUser -ExpandProperty MemberOf -All | ForEach-Object {
                $LiveUser = $_
                ProcessUser
            }
        }
    }
}

# Function to process each user and retrieve group membership
Function ProcessUser {
    $GroupList = @()
    $RolesList = @()
    $Script:ProcessedUsers += 1
    $Name = $LiveUser.DisplayName
    Write-Progress -Activity "Processing $Name" -Status "Processed Users Count: $Script:ProcessedUsers"
    $UserMembership = Get-MgBetaUserTransitiveMemberOf -UserId $LiveUser.UserPrincipalName | Select-Object -ExpandProperty AdditionalProperties
    $AllGroupData = $UserMembership | Where-object { $_.'@odata.type' -eq "#microsoft.graph.group" }
    if ($AllGroupData -eq $null)
    {
        $GroupName = " - "
    }
    else
    {
        if ($UsersNotinAnyGroup.IsPresent)
        {
            return
        }
        $GroupName = (@($AllGroupData.displayName) -join ',')
    }

    $AllRoles = $UserMembership | Where-object { $_.'@odata.type' -eq "#microsoft.graph.directoryRole" }
    if ($AllRoles -eq $null)
    {
        $RolesList = " - "
    }
    else
    {
        $RolesList = @($AllRoles.displayName) -join ','
    }

    $AccountStatus = if ($LiveUser.AccountEnabled -eq $True) { "Enabled" } else { "Disabled" }
    $Department = if ($LiveUser.Department -eq $null) { " - " } else { $LiveUser.Department }
    $LicenseStatus = if ($LiveUser.AssignedLicenses -ne "") { "Licensed" } else { "Unlicensed" }

    ExportResults
}

# Function to export the user data to CSV
Function ExportResults {
    $Script:ExportedUsers += 1
    $ExportResult = [PSCustomObject]@{
        'Display Name'     = $Name
        'Email Address'    = $LiveUser.UserPrincipalName
        'Group Name(s)'    = $GroupName
        'License Status'   = $LicenseStatus
        'Account Status'   = $AccountStatus
        'Department'       = $Department
        'Admin Roles'      = $RolesList
    }
    $ExportResult | Export-csv -path $ExportCSVFileName -NoType -Append
}

# Initialize counters and define the output file
$ProcessedUsers = 0
$ExportedUsers = 0
$ExportCSVFileName = ".\UserMembershipReport_$((Get-Date -format MMM-dd` hh-mm-ss` tt).ToString()).csv"
UserDetails

# Open the output file after execution
if ((Test-Path -Path $ExportCSVFileName) -eq "True")
{
    Write-Progress -Activity "--" -Completed
    Write-Host "`nThe Output result has " -NoNewline
    Write-Host $Script:ExportedUsers Users -ForegroundColor Magenta -NoNewline
    Write-Host " details"
    Write-Host "`nThe Output file available in -NoNewline -Foregroundcolor Yellow; Write-Host $ExportCSVFileName
    $prompt = New-Object -ComObject wscript.shell
    $userInput = $prompt.popup("Do you want to open the output file?", 0, "Open Output File", 4)
    if ($userInput -eq 6)
    {
        Invoke-Item "$ExportCSVFileName"
    }
}
else
{
    Write-Host "`nNo data/user found with the specified criteria."
}

Write-Host "`n~~ Script prepared by Ryan Adams ~~" -ForegroundColor Green
Write-Host "~~ Check out " -NoNewline -ForegroundColor Green; Write-Host "GitHub - https://github.com/Ryan-Adams57" -ForegroundColor Yellow -NoNewline;
Write-Host " for more PowerShell scripts. ~~" -ForegroundColor Green `n`n
