Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'Group.Read.All', 'TeamsAppInstallation.ReadForTeam' }
    $Teams = Get-MgGroup -Filter "resourceProvisioningOptions/any(x:x eq 'Team')" -All
    foreach ($Team in $Teams) { Get-MgTeamAppInstallation -TeamId $Team.Id -ExpandProperty 'TeamsAppDefinition' | Select-Object @{N='Team';E={$Team.DisplayName}}, @{N='App';E={$_.TeamsAppDefinition.DisplayName}} } | 
    Export-Csv -Path '.\TeamsApps.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
