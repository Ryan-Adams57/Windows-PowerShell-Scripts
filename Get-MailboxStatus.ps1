Example: Get Mailbox Status:

Get-Mailbox -ResultSize Unlimited | Select-Object DisplayName, ArchiveStatus

This will show you the DisplayName and ArchiveStatus (whether a mailbox has an archive enabled).
