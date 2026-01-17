Try {
    Connect-ExchangeOnline
    $Results = foreach ($Mbx in (Get-Mailbox -ResultSize Unlimited)) {
        Get-MailboxPermission -Identity $Mbx.UserPrincipalName | Where-Object { $_.AccessRights -eq 'FullAccess' -and $_.AutoMapping -eq $false }
    }
    $Results | Export-Csv -Path '.\MailboxAutoMapping.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
