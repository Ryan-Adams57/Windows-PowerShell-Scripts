Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'Group.Read.All' }
    Get-MgGroup -All | Select-Object DisplayName, Visibility, GroupTypes | Export-Csv -Path '.\GroupVisibility.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
