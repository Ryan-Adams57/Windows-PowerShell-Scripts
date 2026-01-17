Try {
    Connect-ExchangeOnline
    Get-QuarantinePolicy | Select-Object Name, EndUserQuarantinePermissionsValue | 
    Export-Csv -Path '.\QuarantinePolicies.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
