<#
Name:           User-Manager Hierarchy Audit
Description:    Lists all users and their assigned managers in Entra ID.
Version:        1.0
#>
Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes "User.Read.All" }
    $Users = Get-MgUser -All -ExpandProperty Manager
    $Results = foreach ($U in $Users) {
        [PSCustomObject]@{
            User    = $U.DisplayName
            UPN     = $U.UserPrincipalName
            Manager = $U.Manager.AdditionalProperties.displayName
        }
    }
    $Results | Export-Csv -Path ".\UserManagerAudit.csv" -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
