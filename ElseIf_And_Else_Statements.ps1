# if / else example
if (3 -gt 5) {
    Write-Host "Three is greater than Five"
} else {
    Write-Host "Three is less than Five"
}

# if / elseif / else example
if (3 -gt 5) {
    Write-Host "Three is greater than Five"
} elseif (3 -gt 1) {
    Write-Host "Three is greater than One"
} else {
    Write-Host "I don't get printed"
}

# Another variation
if (3 -gt 5) {
    Write-Host "Three is greater than Five"
} elseif (3 -gt 4) {
    Write-Host "Three is greater than Four"
} else {
    Write-Host "This time I get printed"
}
