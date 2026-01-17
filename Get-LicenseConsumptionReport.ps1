Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'Organization.Read.All' }
    Get-MgSubscribedSku | Select-Object SkuPartNumber, ConsumedUnits, @{N='Total';E={$_.PrepaidUnits.Enabled}} | 
    Export-Csv -Path '.\LicenseConsumption.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
