Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'Reports.Read.All' }
    Get-MgReportOnenoteOperationUserDetail -Period 'D90' -OutFile '.\OneNoteUsage.csv'
} Catch { Write-Error $_.Exception.Message }
