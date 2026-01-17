Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'User.Read.All' }
    Get-MgUser -All -Property 'Id', 'UserPrincipalName', 'Manager' -ExpandProperty 'Manager' | 
    Where-Object { $_.Id -eq $_.Manager.Id } | Export-Csv -Path '.\CircularManagerRef.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
