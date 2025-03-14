You might need to report on mailbox permissions, such as who has full access to certain mailboxes.

Example: Get Mailbox Permissions:

Get-Mailbox -ResultSize Unlimited | Get-MailboxPermission | Select-Object Identity, User, AccessRights

This script will report all users who have permissions on mailboxes, including full access rights.
