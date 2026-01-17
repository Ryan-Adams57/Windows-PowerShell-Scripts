Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'User.Read.All' }
    Get-MgUser -All -Property 'DisplayName', 'OnPremisesExtensionAttributes' | 
    Select-Object DisplayName, @{N='Attr1';E={$_.OnPremisesExtensionAttributes.ExtensionAttribute1}} | 
    Export-Csv -Path '.\ExtensionAttrs.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
