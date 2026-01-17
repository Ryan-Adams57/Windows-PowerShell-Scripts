<#
Name:           Mailbox Quota Usage Report
Description:    Reports on current mailbox size vs. warning and shut-off limits.
Version:        1.0
#>
Try {
    Connect-ExchangeOnline
    $Stats = Get-MailboxStatistics -All
    $Results = foreach ($S in $Stats) {
        $Mbx = Get-Mailbox $S.Identity
        [PSCustomObject]@{
            DisplayName = $S.DisplayName
            TotalSize   = $S.TotalItemSize
            ProhibitSend= $Mbx.ProhibitSendQuota
            Status      = $S.StorageLimitStatus
        }
    }
    $Results | Export-Csv -Path ".\MailboxQuotas.csv" -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
