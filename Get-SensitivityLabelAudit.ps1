Try {
    # Compliance Module Required
    Get-Label | Select-Object Name, DisplayName, Priority | Export-Csv -Path '.\Labels.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
