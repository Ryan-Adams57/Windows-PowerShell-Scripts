<#
Name:           Mobile Device Inventory
Description:    Lists all mobile devices currently syncing with the tenant.
Version:        1.0
#>
Try {
    Connect-ExchangeOnline
    $Devices = Get-MobileDevice -ResultSize Unlimited
    $Results = foreach ($D in $Devices) {
        $Stat = Get-MobileDeviceStatistics -Identity $D.Guid.ToString()
        [PSCustomObject]@{
            User      = $D.UserDisplayName
            Model     = $D.DeviceModel
            OS        = $D.DeviceOS
            LastSync  = $Stat.LastSuccessSync
        }
    }
    $Results | Export-Csv -Path ".\MobileDevices.csv" -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
