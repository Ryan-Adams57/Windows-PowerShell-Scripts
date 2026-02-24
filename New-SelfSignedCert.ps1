# New-SelfSignedCert.ps1
# Creates a new self-signed certificate or clones an existing one
# Must be run as Administrator
# Reference: https://adamtheautomator.com/new-selfsignedcertificate

# --- Configuration ---
$DnsNames    = @("example.com", "sub.example.com", "sub2.example.com")
$YearsValid  = 2   # Certificate validity in years
# ---------------------

Write-Host "--- Creating New Self-Signed Certificate ---" -ForegroundColor Cyan

$cert = New-SelfSignedCertificate `
    -DnsName $DnsNames `
    -NotAfter (Get-Date).AddYears($YearsValid)

$cert | Select-Object Subject, DnsNameList, Thumbprint, NotBefore, NotAfter | Format-List
Write-Host "Certificate created. Thumbprint: $($cert.Thumbprint)" -ForegroundColor Green

# --- Clone an existing certificate ---
# 1. Find the cert to clone:
# Get-ChildItem Cert:\ -Recurse |
#     Where-Object { $_.Subject -like "*example*" } |
#     Select-Object Subject, DnsNameList, Thumbprint, NotBefore, NotAfter
#
# 2. Copy the thumbprint and clone:
# $certToClone = Get-Item Cert:\LocalMachine\My\<ThumbprintHere>
# $clonedCert  = New-SelfSignedCertificate -CloneCert $certToClone -NotAfter (Get-Date).AddYears(2)
# $clonedCert  | Select-Object Subject, DnsNameList, Thumbprint, NotBefore, NotAfter
