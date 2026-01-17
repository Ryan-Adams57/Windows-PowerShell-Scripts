Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'Directory.Read.All' }
    $AUs = Get-MgDirectoryAdministrativeUnit
    foreach ($AU in $AUs) { Get-MgDirectoryAdministrativeUnitMember -AdministrativeUnitId $AU.Id | Select-Object @{N='AU';E={$AU.DisplayName}}, Id } | 
    Export-Csv -Path '.\AdminUnits.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
