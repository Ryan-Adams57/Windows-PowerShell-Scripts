$A = 0
do {
    try {
        $Services = Get-Service -name SentinelAgent
    }
    catch {
        $Services = $null
    }
    start-sleep -Seconds 30
    $A = $A + 30
} until (($null -ne $Services) -or ($A -ge 300))
if ($null -ne $Services) { Write-Host "Installed" } else { exit }