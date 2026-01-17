Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'Application.Read.All' }
    Get-MgOAuth2PermissionGrant -All | Export-Csv -Path '.\AppConsents.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
