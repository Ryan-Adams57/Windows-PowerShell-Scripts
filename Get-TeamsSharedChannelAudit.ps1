Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'Group.Read.All' }
    foreach ($T in (Get-MgGroup -Filter "resourceProvisioningOptions/any(x:x eq 'Team')" -All)) {
        Get-MgTeamChannel -TeamId $T.Id | Where-Object { $_.MembershipType -eq 'shared' } | 
        Select-Object @{N='Team';E={$T.DisplayName}}, DisplayName
    } | Export-Csv -Path '.\SharedChannels.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
