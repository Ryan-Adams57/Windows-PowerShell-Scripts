# Example 1: Catching errors
try {
    Get-Process -Name FakeProcess -ErrorAction Stop
} catch {
    Write-Output "Error: $($_.Exception.Message)"
}

# Example 2: Try/Catch/Finally
try {
    Get-Process -Name spoolsv -ErrorAction Stop
} catch {
    Write-Output "Error: $($_.Exception.Message)"
} finally {
    Write-Output "This block always executes"
}
