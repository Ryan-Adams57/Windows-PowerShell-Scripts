Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'Policy.Read.All' }
    Get-MgIdentityConditionalAccessPolicy | Where-Object { $_.Conditions.Applications.ExcludeApplications } | 
    Select-Object DisplayName, @{N='ExcludedApps';E={$_.Conditions.Applications.ExcludeApplications -join '; '}} | 
    Export-Csv -Path '.\CAPolicyExclusions.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
