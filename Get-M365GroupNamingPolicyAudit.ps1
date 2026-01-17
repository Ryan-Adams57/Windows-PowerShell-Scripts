Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'Group.Read.All' }
    Get-MgGroup -All | Where-Object { $_.DisplayName -notlike 'GRP_*' } | 
    Select-Object DisplayName, Mail | Export-Csv -Path '.\GroupNamingAudit.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
