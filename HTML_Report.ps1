# Example: Generate a simple HTML report with styling
$ReportData = @(
    [PSCustomObject]@{Name="Server1"; Status="Online"}
    [PSCustomObject]@{Name="Server2"; Status="Offline"}
)

$Header = @"
<style>
TABLE {border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse;}
TH {border-width: 1px; padding: 3px; border-style: solid; border-color: black; background-color: #6495ED;}
TD {border-width: 1px; padding: 3px; border-style: solid; border-color: black;}
tr:nth-child(even) {background-color: #b5b3a8;}
</style>
"@

$ReportData | ConvertTo-Html -Head $Header -Property Name,Status | Out-File C:\Folder\Report.html
Write-Host "Report generated at C:\Folder\Report.html"
