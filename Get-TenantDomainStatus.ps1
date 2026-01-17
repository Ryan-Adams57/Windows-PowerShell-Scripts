<#
Name:           Domain Health Report
Description:    Lists all domains and their verification/DNS status.
Version:        1.0
#>
Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes "Organization.Read.All" }
    Get-MgDomain | Select-Object Id, IsVerified, IsDefault, AuthenticationType | 
    Export-Csv -Path ".\DomainStatus.csv" -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
