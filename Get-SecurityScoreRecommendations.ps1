Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'SecurityEvents.Read.All' }
    Get-MgSecuritySecureScoreControlProfile | Select-Object Title, UserImpact, ImplementationStatus | 
    Export-Csv -Path '.\SecureScoreActions.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
