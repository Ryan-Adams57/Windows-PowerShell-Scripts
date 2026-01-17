Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'Policy.Read.All' }
    Get-MgIdentityConditionalAccessNamedLocation | Select-Object DisplayName, IsTrusted | 
    Export-Csv -Path '.\CANamedLocations.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
