# Define the threshold
$threshold = 30*1GB

# Get the C drive information
$drive = Get-PSDrive -Name C

# Calculate the free space in bytes
$freeSpaceBytes = $drive.Free

# Convert the free space to GB
$freeSpaceGB = [Math]::Round($freeSpaceBytes / 1GB, 2)

# Compare the free space with the threshold
if ($freeSpaceBytes -lt $threshold) {
    Write-Host "Warning: Free space on C drive is below 30GB. Current free space is $freeSpaceGB GB."
} else {
    Write-Host "The free space on C drive is sufficient. Current free space is $freeSpaceGB GB."
}
