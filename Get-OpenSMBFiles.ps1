# Get-OpenSMBFiles.ps1
# Retrieves open SMB files on a remote server
# Requires admin rights on the target server

# --- Configuration ---
$ServerName = "<PCNAME>"   # e.g., "Win2k12" or "FileServer01"
$PathFilter = ""           # Optional: filter by path substring, e.g., "Reports"
# ---------------------

Write-Host "--- Open SMB Files on $ServerName ---" -ForegroundColor Cyan

if ($PathFilter) {
    Invoke-Command -ComputerName $ServerName -ScriptBlock {
        param($Filter)
        Get-SmbOpenFile | Where-Object -Property Path -Like "*$Filter*"
    } -ArgumentList $PathFilter |
    Format-Table ShareRelativePath, ClientUserName, @{
        N = "Source"
        E = { (Resolve-DnsName $_.ClientComputerName -ErrorAction SilentlyContinue).NameHost }
    } -AutoSize
} else {
    Invoke-Command -ComputerName $ServerName -ScriptBlock {
        Get-SmbOpenFile
    } | Format-Table ShareRelativePath, ClientUserName, ClientComputerName -AutoSize
}
