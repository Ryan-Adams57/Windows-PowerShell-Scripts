Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'Group.Read.All' }
    $Teams = Get-MgGroup -Filter "resourceProvisioningOptions/any(x:x eq 'Team')" -All
    foreach ($Team in $Teams) { Get-MgTeamChannel -TeamId $Team.Id | Select-Object @{N='Team';E={$Team.DisplayName}}, DisplayName, MembershipType } | 
    Export-Csv -Path '.\TeamsChannels.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
