$intuneUtilPath = "C:\IntuneWinAppUtil.exe"
if (!(Test-Path $intuneUtilPath)) {
    Write-Host "IntuneWinAppUtil.exe not found, downloading from GitHub..."
    $downloadUrl = "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/archive/refs/tags/v1.8.4.zip"
    $zipPath = "$env:TEMP\IntuneWinAppUtil.zip"
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath
    Expand-Archive -Path $zipPath -DestinationPath $env:TEMP
    Copy-Item "$env:TEMP\Microsoft-Win32-Content-Prep-Tool-1.8.4\IntuneWinAppUtil.exe" $intuneUtilPath
    Remove-Item "$env:TEMP\IntuneWinAppUtil.zip" -Force
    Remove-Item "$env:TEMP\Microsoft-Win32-Content-Prep-Tool-1.8.4" -Recurse -Force
}

Remove-Item $env:TEMP -Force -Recurse -ErrorAction SilentlyContinue

Function Get-FileName($initialDirectory)
{
    Add-Type -AssemblyName System.Windows.Forms
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.Title = "Please Select File"
    $OpenFileDialog.InitialDirectory = $initialDirectory
    $OpenFileDialog.filter = "All files (*.*)| *.*"
    # Out-Null supresses the "OK" after selecting the file.
    $OpenFileDialog.ShowDialog() | Out-Null
    $Global:SelectedFile = $OpenFileDialog.FileName
    $Global:SelectedFilePath = split-path -path $SelectedFile
    $Global:SelectedFileName = [System.IO.Path]::GetFileName("$SelectedFile")
}

Get-FileName
echo "`"$SelectedFile`""
echo "`"$SelectedFilePath`""
echo "`"$SelectedFileName`""

Start-Process "`"$intuneUtilPath`"" "-c `"$SelectedFilePath`" -s `"$SelectedFileName`" -o `"$SelectedFilePath`"" -Wait 
