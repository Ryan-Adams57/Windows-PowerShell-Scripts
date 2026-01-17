<#
Name:           Shared Mailbox Permission Audit
Description:    Lists users who have Full Access permissions to shared mailboxes.
Version:        1.0
#>
Try {
    Connect-ExchangeOnline
    $Shared = Get-Mailbox -RecipientTypeDetails SharedMailbox
    $Results = foreach ($MB in $Shared) {
        $Perms = Get-MailboxPermission -Identity $MB.UserPrincipalName | Where-Object { $_.User -notlike "NT AUTHORITY*" -and $_.AccessRights -contains "FullAccess" }
        [PSCustomObject]@{ Mailbox = $MB.DisplayName; Members = ($Perms.User -join "; ") }
    }
    $Results | Export-Csv -Path ".\SharedMailboxAudit.csv" -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
