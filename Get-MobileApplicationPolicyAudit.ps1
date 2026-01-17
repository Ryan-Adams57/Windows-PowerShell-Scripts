Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'DeviceManagementManagedDevices.Read.All' }
    Get-MgDeviceAppManagementTargetedManagedAppConfiguration | Select-Object DisplayName, LastModifiedDateTime | 
    Export-Csv -Path '.\MAMPolicyAudit.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
