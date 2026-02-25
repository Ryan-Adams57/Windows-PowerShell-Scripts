# Prompt the user for PDF folder and password input
$pdfFolder = Read-Host -Prompt 'Enter the path to the folder containing PDF files'
$password = Read-Host -Prompt 'Enter the password to be applied to the PDF files'

# Get all PDF files in the folder
$pdfFiles = Get-ChildItem -Path $pdfFolder -Filter *.pdf

# Loop through each PDF file and password-protect it
foreach ($pdfFile in $pdfFiles) {
    # Define the output file with the same name as the original file
    $outputFile = $pdfFile.FullName

    # Temporary filename for the original file
    $tempFile = "$($pdfFile.FullName).temp"

    # Rename the original file
    Rename-Item -Path $pdfFile.FullName -NewName $tempFile

    # Password-protect the PDF file using QPDF
    & qpdf --encrypt $password $password 256 -- "$tempFile" "$outputFile"

    # Remove the temporary file
    Remove-Item -Path $tempFile -Force

    Write-Host "Password protection completed for: $($pdfFile.FullName)"
}

Write-Host "Password protection completed for all PDF files in $pdfFolder."
