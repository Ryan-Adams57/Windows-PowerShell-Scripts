Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'Group.Read.All', 'ChannelMember.Read.All' }
    foreach ($Team in (Get-MgGroup -Filter "resourceProvisioningOptions/any(x:x eq 'Team')" -All)) {
        Get-MgTeamChannel -TeamId $Team.Id | Where-Object { $_.MembershipType -eq 'private' } | ForEach-Object {
            $Chan = $_; Get-MgTeamChannelMember -TeamId $Team.Id -ChannelId $Chan.Id | Where-Object { $_.Roles -contains 'owner' } |
            Select-Object @{N='Team';E={$Team.DisplayName}}, @{N='Channel';E={$Chan.DisplayName}}, DisplayName
        }
    } | Export-Csv -Path '.\PrivateChannelOwners.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
