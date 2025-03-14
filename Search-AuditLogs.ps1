# Connect to Security & Compliance Center
Connect-ComplianceCenterPowerShell -UserPrincipalName your-admin@domain.com

# Search Audit Logs
Search-UnifiedAuditLog -StartDate "2025-01-01" -EndDate "2025-01-31" -Operations FileAccessed | Export-Csv "C:\Reports\AuditLogReport.csv" -NoTypeInformation
