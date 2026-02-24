# ---------- SERVER LIST ----------
$servers = @(
    @{Server=""; Database=""; User=""; Password=""}, 
	@{Server=""; Database=""; User=""; Password=""}
	
)

# ---------- OUTPUT FILE ----------
$outputFile = "C:\Script\Error_Log_Summary.csv"

# ---------- INITIALIZE RESULT ARRAY (IMPORTANT) ----------
$allResults = @()

# ---------- QUERY ----------
$query = "
SELECT ErrorMessage, ErrorProcedure, ErrorTime 
FROM ErrorLog 
WHERE ErrorTime >= DATEADD(DAY, 1, EOMONTH(GETDATE(), -1))  
ORDER BY ErrorTime
"

foreach ($s in $servers) {

    try {
        $data = Invoke-Sqlcmd `
            -ServerInstance $s.Server `
            -Database $s.Database `
            -Username $s.User `
            -Password $s.Password `
            -Query $query `
            -ErrorAction Stop

        if ($data) {
            foreach ($row in $data) {
                $allResults += [PSCustomObject]@{
                    Server       = $s.Server
                    Database     = $s.Database
                    ErrorMessage   = $row.ErrorMessage
                    ErrorProcedure   = $row.ErrorProcedure
                    ErrorTime= $row.ErrorTime
                }
            }
        }
    }
    catch {
        # Capture connection failure into CSV
        $allResults += [PSCustomObject]@{
            Server        = $s.Server
            Database      = $s.Database
            ErrorMessage    = "CONNECTION FAILED"
            ErrorProcedure    = ""
            ErrorTime = ""
        }
    }
}

# ---------- EXPORT CSV (SAFE) ----------
if ($allResults.Count -gt 0) {
    $allResults | Export-Csv $outputFile -NoTypeInformation
    Write-Host "CSV created: $outputFile"
} else {
    Write-Host "No data found. CSV not created."
}

# ---------- OPEN CSV ----------
if (Test-Path $outputFile) {
    Start-Process $outputFile
}
