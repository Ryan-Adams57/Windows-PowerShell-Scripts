<#
Name:           Send-As Permission Audit
Description:    Identifies who has permission to send emails as another user.
Version:        1.0
#>
Try {
    Connect-ExchangeOnline
    $Mailboxes = Get-Mailbox -ResultSize Unlimited
    $Results = foreach ($M in $Mailboxes) {
        Get-RecipientPermission -Identity $M.UserPrincipalName | 
        Where-Object { $_.Trustee -notlike "NT AUTHORITY*" } |
        Select-Object @{N='Mailbox';E={$M.DisplayName}}, Trustee, AccessRights
    }
    $Results | Export-Csv -Path ".\SendAsPermissions.csv" -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
