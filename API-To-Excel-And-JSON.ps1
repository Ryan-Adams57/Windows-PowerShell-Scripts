# Import the module
Import-Module ImportExcel

# Ask the user for the API endpoint
$apiEndpoint = Read-Host "Enter the API endpoint"

# Make the GET request
$response = Invoke-RestMethod $apiEndpoint

# Ask the user for the export path of the Excel file
$exportPath = Read-Host "Enter the path to export the Excel file"

# Export the data to an Excel file
$response | Export-Excel -Path $exportPath -AutoSize -Show

# Ask the user for the export path of the JSON file
$jsonExportPath = Read-Host "Enter the path to export the JSON file"

# Save the data as a JSON file
$response | ConvertTo-Json -Depth 100 | Out-File $jsonExportPath

Write-Host "Data exported to $exportPath (Excel) and $jsonExportPath (JSON)."
