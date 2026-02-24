# Strict mode enforces stricter error handling and variable/property usage
Set-StrictMode -Version Latest

# Example without strict mode: $NonExistentVar outputs nothing
# Example with strict mode:
try {
    $NonExistentVar.Property
} catch {
    Write-Host "Caught error: $($_.Exception.Message)"
}
