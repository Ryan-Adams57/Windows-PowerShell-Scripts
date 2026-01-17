Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'User.Read.All' }
    Get-MgUser -All -Property 'DisplayName', 'Department', 'JobTitle' | Export-Csv -Path '.\Departments.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
