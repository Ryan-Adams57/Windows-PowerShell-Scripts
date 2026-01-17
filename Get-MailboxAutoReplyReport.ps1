<#
Name:           Active Out-of-Office Report
Description:    Lists all users currently having an active Auto-Reply (OOF).
Version:        1.0
#>
Try {
    Connect-ExchangeOnline
    $Mailboxes = Get-Mailbox -ResultSize Unlimited
    $Results = foreach ($M in $Mailboxes) {
        $Oof = Get-MailboxAutoReplyConfiguration -Identity $M.UserPrincipalName
        if ($Oof.AutoReplyState -ne "Disabled") {
            [PSCustomObject]@{ User = $M.DisplayName; Status = $Oof.AutoReplyState; EndTime = $Oof.EndTime }
        }
    }
    $Results | Export-Csv -Path ".\ActiveOOFReport.csv" -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
