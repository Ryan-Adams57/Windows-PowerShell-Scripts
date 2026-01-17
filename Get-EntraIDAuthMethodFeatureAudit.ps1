Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'Policy.Read.All' }
    Get-MgPolicyAuthenticationMethodPolicy | Export-Csv -Path '.\AuthMethodFeatures.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
