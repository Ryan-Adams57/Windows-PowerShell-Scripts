<#
    .SYNOPSIS
    PreProvision-OneDrive.ps1

    .DESCRIPTION
    The script will pre-provision OneDrive for Microsoft 365 users. It will check if the user already has a personal site.
    If not, it will add the user to the list and request the personal site for the user.

    .LINK
    https://www.governmentcontrol.net/

    .NOTES
    Written by: Ryan Adams
    Website:    https://www.governmentcontrol.net/
    LinkedIn:   www.linkedin.com/in/ryan-adamsz7157

    .CHANGELOG
    V1.00, 02/20/2025 - Initial version
#>

Param(
    [Parameter(Mandatory = $True)]
    [String]
    $SharepointURL
)

Connect-MgGraph -Scopes "User.Read.All" -NoWelcome
Connect-SPOService -Url $SharepointURL

$list = [System.Collections.Generic.List[Object]]::new()
$Totalusers = 0

# Get properties
$Properties = @(
    "UserPrincipalName",
    "DisplayName",
    "AssignedLicenses"
)

# Get licensed users
$users = Get-MgUser -Filter "assignedLicenses/`$count ne 0 and userType eq 'Member' and accountEnabled eq true" -ConsistencyLevel eventual -CountVariable licensedUserCount -Property $Properties -All | Select-Object $Properties | Sort-Object UserPrincipalName

foreach ($user in $users) {
    $Totalusers++
    Write-Host "$Totalusers/$($users.Count) - $($user.UserPrincipalName)" -ForegroundColor Green

    # Check if the user already has a personal site
    $existingSite = Get-SPOSite -IncludePersonalSite $true -Filter "Owner -eq '$($user.UserPrincipalName)'" | Select-Object -ExpandProperty Url

    if ($existingSite) {
        Write-Host "Personal site already exists for $($user.UserPrincipalName): $existingSite" -ForegroundColor Yellow
    }
    else {
        $list.Add($user.UserPrincipalName)

        if ($list.Count -eq 199) {
            # We reached the limit
            Write-Host "Batch limit reached, requesting provision for the current batch"
            Request-SPOPersonalSite -UserEmails $list -NoWait
            Start-Sleep -Milliseconds 655
            $list = [System.Collections.Generic.List[Object]]::new()
        }
    }
}

if ($list.Count -gt 0) {
    Request-SPOPersonalSite -UserEmails $list -NoWait
}

Write-Host "Completed OneDrive Pre-Provisioning." -ForegroundColor Cyan

#Disconnect-SPOService
#Disconnect-MgGraph
