# Prompt the user for ProviderName input
$providerName = Read-Host -Prompt 'Enter the ProviderName'

# Define the filter criteria with user input
$filterHashtable = @{
    LogName      = 'Application'
    ProviderName = $providerName
}

# Retrieve the latest event that matches the filter criteria
$lastEvent = Get-WinEvent -FilterHashtable $filterHashtable -MaxEvents 1

# Print message if an event is found
if ($lastEvent) {
    $lastEvent.Message
} else {
    Write-Host "No events found for ProviderName: $providerName"
}
