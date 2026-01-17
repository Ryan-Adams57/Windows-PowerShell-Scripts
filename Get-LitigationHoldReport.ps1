<#
Name:           Exchange Litigation Hold Audit
Description:    Lists all mailboxes where Litigation Hold is enabled.
Version:        1.0
#>
Try {
    Connect-ExchangeOnline
    Get-Mailbox -ResultSize Unlimited | Where-Object { $_.LitigationHoldEnabled } | 
    Select-Object DisplayName, PrimarySmtpAddress, LitigationHoldDate | 
    Export-Csv -Path ".\LitigationHolds.csv" -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
