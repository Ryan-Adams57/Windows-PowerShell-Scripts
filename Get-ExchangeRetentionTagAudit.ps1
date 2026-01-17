Try {
    Connect-ExchangeOnline
    Get-RetentionPolicyTag | Select-Object Name, Type, RetentionAction | 
    Export-Csv -Path '.\RetentionTags.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
