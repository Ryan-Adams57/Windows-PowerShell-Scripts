Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'User.Read.All', 'Group.Read.All' }
    [PSCustomObject]@{ Users = (Get-MgUser -All).Count; Groups = (Get-MgGroup -All).Count; Date = Get-Date } | 
    Export-Csv -Path '.\TenantSummary.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
