# Get-ADGroupMembers.ps1
# Retrieves members of an Active Directory group
# Requires AD PowerShell module (RSAT)

# --- Configuration ---
$GroupName = "<GroupName>"  # e.g., "IT_Admins"
# ---------------------

Write-Host "--- Members of AD Group: $GroupName ---" -ForegroundColor Cyan
Get-ADGroupMember -Identity $GroupName | Select-Object Name, SamAccountName, ObjectClass | Format-Table -AutoSize
