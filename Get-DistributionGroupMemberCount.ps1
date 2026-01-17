<#
Name:           Distribution Group Size Audit
Description:    Counts members in all Distribution Groups to identify over-sized lists.
Version:        1.0
#>
Try {
    Connect-ExchangeOnline
    $Groups = Get-DistributionGroup -ResultSize Unlimited
    $Results = foreach ($G in $Groups) {
        $Count = (Get-DistributionGroupMember -Identity $G.Identity -ResultSize Unlimited).Count
        [PSCustomObject]@{ GroupName = $G.DisplayName; MemberCount = $Count; PrimarySmtp = $G.PrimarySmtpAddress }
    }
    $Results | Export-Csv -Path ".\DistroGroupCounts.csv" -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
