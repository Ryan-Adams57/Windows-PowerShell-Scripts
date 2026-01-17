Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'Policy.Read.All' }
    Get-MgPolicyB2BFlowPolicy | Export-Csv -Path '.\B2BSettings.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
