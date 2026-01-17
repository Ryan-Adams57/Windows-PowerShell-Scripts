Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'RoleManagement.Read.Directory' }
    $Roles = Get-MgDirectoryRole
    foreach ($R in $Roles) { Get-MgDirectoryRoleMember -DirectoryRoleId $R.Id | Select-Object @{N='Role';E={$R.DisplayName}}, Id } | 
    Export-Csv -Path '.\RoleAssignments.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
