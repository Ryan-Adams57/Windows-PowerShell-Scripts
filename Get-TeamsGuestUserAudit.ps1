Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'Group.Read.All', 'User.Read.All' }
    $Teams = Get-MgGroup -Filter "resourceProvisioningOptions/any(x:x eq 'Team')" -All
    $Results = foreach ($T in $Teams) {
        $Guests = Get-MgGroupMember -GroupId $T.Id -All | Get-MgUser | Where-Object { $_.UserType -eq 'Guest' }
        foreach ($G in $Guests) { [PSCustomObject]@{ Team = $T.DisplayName; Guest = $G.UserPrincipalName } }
    }
    $Results | Export-Csv -Path '.\TeamsGuestAudit.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
