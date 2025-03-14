You can use PowerShell to pull audit logs for activities such as login attempts, document sharing, and more.

Example: Search Unified Audit Logs:

# Connect to Security & Compliance Center
Connect-ComplianceCenterPowerShell -UserPrincipalName your-admin@domain.com

# Search Audit Logs
Search-UnifiedAuditLog -StartDate "2025-01-01" -EndDate "2025-01-31" -Operations FileAccessed | Export-Csv "C:\Reports\AuditLogReport.csv" -NoTypeInformation

This script searches the unified audit logs for the operation FileAccessed between two dates and exports the results to a CSV.
