Get-Mailbox -ResultSize Unlimited | Get-MailboxPermission | Select-Object Identity, User, AccessRights
