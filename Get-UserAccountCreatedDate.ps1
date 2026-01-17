Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'User.Read.All' }
    Get-MgUser -All -Property 'DisplayName', 'CreatedDateTime' | Export-Csv -Path '.\UserCreationDates.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
