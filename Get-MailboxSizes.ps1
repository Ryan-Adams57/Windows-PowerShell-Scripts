You can get a report of all mailboxes, including their size and status.

Example: Get Mailbox Sizes:

Get-Mailbox -ResultSize Unlimited | Select-Object DisplayName, TotalItemSize, ItemCount

This script returns the DisplayName, TotalItemSize (size of the mailbox), and ItemCount (number of items in the mailbox) for all mailboxes in your environment.
