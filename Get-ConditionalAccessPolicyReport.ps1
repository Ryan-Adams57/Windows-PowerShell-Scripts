<#
Name:           Conditional Access Policy Summary
Description:    Exports all CA policies and their current state (Enabled/Disabled/Report-Only).
Version:        1.0
#>
Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes "Policy.Read.All" }
    Get-MgIdentityConditionalAccessPolicy | 
    Select-Object DisplayName, State, @{N='GrantControls';E={$_.GrantControls.BuiltInControls -join ","}} | 
    Export-Csv -Path ".\CAPolicyReport.csv" -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
