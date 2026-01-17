<#
Name:           Global Admin Audit
Description:    Retrieves all users assigned the Global Administrator role.
Version:        1.0
#>
Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes "RoleManagement.Read.Directory", "User.Read.All" }
    $Role = Get-MgDirectoryRole | Where-Object { $_.DisplayName -eq "Global Administrator" }
    $Admins = Get-MgDirectoryRoleMember -DirectoryRoleId $Role.Id -All
    $Results = foreach ($Admin in $Admins) {
        $User = Get-MgUser -UserId $Admin.Id -Property "DisplayName", "UserPrincipalName", "AccountEnabled"
        [PSCustomObject]@{ DisplayName = $User.DisplayName; UPN = $User.UserPrincipalName; Enabled = $User.AccountEnabled }
    }
    $Results | Export-Csv -Path ".\GlobalAdmins.csv" -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
