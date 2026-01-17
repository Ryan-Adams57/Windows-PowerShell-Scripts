<#
Name:           Exchange Forwarding Audit
Description:    Detects mailboxes forwarding to external or internal addresses.
Version:        1.0
#>
Try {
    Connect-ExchangeOnline
    $Mailboxes = Get-Mailbox -ResultSize Unlimited | Where-Object { $_.ForwardingAddress -ne $null -or $_.ForwardingSmtpAddress -ne $null }
    $Results = $Mailboxes | Select-Object DisplayName, PrimarySmtpAddress, ForwardingAddress, ForwardingSmtpAddress, DeliverToMailboxAndForward
    $Results | Export-Csv -Path ".\ForwardingAudit.csv" -NoTypeInformation
    Write-Host "Forwarding report complete." -ForegroundColor Green
} Catch { Write-Error $_.Exception.Message }
