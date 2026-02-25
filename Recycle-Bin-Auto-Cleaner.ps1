try {
    $recycleBinPath = [System.IO.Path]::Combine($env:SystemRoot, 'Recycle Bin')
    $recycleBinSize = (Get-ChildItem $recycleBinPath -Recurse | Measure-Object -Property Length -Sum).Sum / 1GB

    if ($recycleBinSize -gt 30) {     #change threshold as needed
        Clear-RecycleBin -Confirm:$false
        if ($lastExitCode -ne "0") {
            throw "'Clear-RecycleBin' failed"
        }
    } else {
        Write-Output "Recycle bin size is less than or equal to 30GB. No action taken."
        exit 0 # success
    }
} catch {
    "⚠️ Error in line $($_.InvocationInfo.ScriptLineNumber): $($Error[0])"
    exit 1
}
