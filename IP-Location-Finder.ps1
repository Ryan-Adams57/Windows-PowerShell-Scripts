try {
    $IPaddress = Read-Host "Enter IP address to locate"

    $result = Invoke-RestMethod -Method Get -Uri "http://ip-api.com/json/$IPaddress"
    Write-Output $result
} catch {
    "⚠️ Error in line $($_.InvocationInfo.ScriptLineNumber): $($Error[0])"
    exit 1
}
