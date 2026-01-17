<#
Name:           Privileged Role Membership Audit
Description:    Identifies users assigned to high-impact directory roles.
Version:        1.0
#>
Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes "RoleManagement.Read.Directory" }
    $Roles = Get-MgDirectoryRole
    $Results = foreach ($Role in $Roles) {
        $Members = Get-MgDirectoryRoleMember -DirectoryRoleId $Role.Id
        foreach ($M in $Members) {
            [PSCustomObject]@{ Role = $Role.DisplayName; User = $M.AdditionalProperties.userPrincipalName }
        }
    }
    $Results | Export-Csv -Path ".\PrivilegedAdmins.csv" -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
