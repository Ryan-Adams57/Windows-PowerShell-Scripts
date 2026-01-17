Try {
    # Requires Compliance PowerShell
    Get-DlpCompliancePolicy | Select-Object Name, State, Mode | Export-Csv -Path '.\DLPPolicies.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
