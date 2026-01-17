Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'Application.Read.All' }
    $SP = Get-MgServicePrincipal -All
    $Results = foreach ($S in $SP) {
        $Grants = Get-MgOAuth2PermissionGrant -Filter "clientId eq '$($S.Id)'"
        [PSCustomObject]@{ DisplayName = $S.DisplayName; AppId = $S.AppId; Scopes = ($Grants.Scope -join ', ') }
    }
    $Results | Export-Csv -Path '.\ServicePrincipalPermissions.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
