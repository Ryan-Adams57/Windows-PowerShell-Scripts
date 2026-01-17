<#
Name:           Inbox Rule Forwarding Audit
Description:    Scans all mailboxes for user-created inbox rules that forward mail externally.
Version:        1.0
#>
Try {
    Connect-ExchangeOnline
    $Mailboxes = Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox
    $Results = foreach ($Mbx in $Mailboxes) {
        $Rules = Get-InboxRule -Mailbox $Mbx.UserPrincipalName | Where-Object { $_.ForwardTo -or $_.ForwardAsAttachmentTo }
        foreach ($Rule in $Rules) {
            [PSCustomObject]@{
                Mailbox    = $Mbx.UserPrincipalName
                RuleName   = $Rule.Name
                ForwardTo  = ($Rule.ForwardTo -join "; ")
                Enabled    = $Rule.Enabled
            }
        }
    }
    $Results | Export-Csv -Path ".\InboxForwardingRules.csv" -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
