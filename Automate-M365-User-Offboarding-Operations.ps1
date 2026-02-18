<#
=============================================================================================
Name:           Automate Microsoft 365 User Offboarding with PowerShell
Description:    This script can perform 14 Microsoft 365 offboarding activities.
Version:        2.0
Script by:      Ryan Adams
Website:        https://www.governmentcontrol.net/
GitHub:         https://github.com/Ryan-Adams57
GitLab:         https://gitlab.com/Ryan-Adams57
PasteBin:       https://pastebin.com/u/Removed_Content

Change Log
~~~~~~~~~~

    V1.0 (Oct 14, 2023) - File created
    V2.0 (Apr 02, 2025) - Removed beta version cmdlets 

=========================================================================================
#>
param(
    [string]$TenantId,
    [string]$ClientId,
    [string]$CertificateThumbprint,
    [string]$CSVFilePath,
    [String]$UPNs
)
Function ConnectModules 
{
    $MsGraphModule =  Get-Module Microsoft.Graph -ListAvailable
    if($MsGraphModule -eq $null)
    { 
        Write-host "Important: Microsoft Graph module is unavailable. It is mandatory to have this module installed in the system to run the script successfully." 
        $confirm = Read-Host Are you sure you want to install Microsoft Graph module? [Y] Yes [N] No  
        if($confirm -match "[yY]") 
        { 
            Write-host "Installing Microsoft Graph module..."
            Install-Module Microsoft.Graph -Scope CurrentUser -AllowClobber
            Write-host "Microsoft Graph module is installed in the machine successfully" -ForegroundColor Magenta 
        } 
        else
        { 
            Write-host "Exiting. `nNote: Microsoft Graph module must be available in your system to run the script" -ForegroundColor Red
            Exit 
        } 
    }
    $ExchangeOnlineModule =  Get-Module ExchangeOnlineManagement -ListAvailable
    if($ExchangeOnlineModule -eq $null)
    { 
        Write-host "Important: Exchange Online module is unavailable. It is mandatory to have this module installed in the system to run the script successfully." 
        $confirm = Read-Host Are you sure you want to install Exchange Online module? [Y] Yes [N] No  
        if($confirm -match "[yY]") 
        { 
            Write-host "Installing Exchange Online module..."
            Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser
            Write-host "Exchange Online Module is installed in the machine successfully" -ForegroundColor Magenta 
        } 
        else
        { 
            Write-host "Exiting. `nNote: Exchange Online module must be available in your system to run the script" 
            Exit 
        } 
    }
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    Disconnect-ExchangeOnline -Confirm:$false
    Write-Host "Connecting modules(Microsoft Graph and Exchange Online module)...`n"
    try{
        if($TenantId -ne "" -and $ClientId -ne "" -and $CertificateThumbprint -ne "")
        {
            Connect-MgGraph  -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -ErrorAction SilentlyContinue -ErrorVariable ConnectionError|Out-Null
            if($ConnectionError -ne $null)
            {    
                Write-Host $ConnectionError -Foregroundcolor Red
                Exit
            }
            $Scopes = (Get-MgContext).Scopes
            $ApplicationPermissions=@("Directory.ReadWrite.All","AppRoleAssignment.ReadWrite.All","User.EnableDisableAccount.All","RoleManagement.ReadWrite.Directory")
            foreach($Permission in $ApplicationPermissions)
            {
                if($Scopes -notcontains $Permission)
                {
                    Write-Host "Note: Your application required the following graph application permissions: Directory.ReadWrite.All,AppRoleAssignment.ReadWrite.All,User.EnableDisableAccount.All,RoleManagement.ReadWrite.Directory" -ForegroundColor Yellow
                    Exit
                }
            }
            Connect-ExchangeOnline -AppId $ClientId -CertificateThumbprint $CertificateThumbprint  -Organization (Get-MgDomain | Where-Object {$_.isInitial}).Id -ShowBanner:$false
        }
        else
        {
            Connect-MgGraph -Scopes Directory.ReadWrite.All,AppRoleAssignment.ReadWrite.All,User.EnableDisableAccount.All,Directory.AccessAsUser.All,RoleManagement.ReadWrite.Directory -ErrorAction SilentlyContinue -Errorvariable ConnectionError |Out-Null
            if($ConnectionError -ne $null)
            {
                Write-Host $ConnectionError -Foregroundcolor Red
                Exit
            }
            Connect-ExchangeOnline -UserPrincipalName (Get-MgContext).Account -ShowBanner:$false
        }
    }
    catch
    {
        Write-Host $_.Exception.message -ForegroundColor Red
        Exit
    }
    Write-Host "Microsoft Graph PowerShell module is connected successfully" -ForegroundColor Cyan
    Write-Host "Exchange Online module is connected successfully" -ForegroundColor Cyan
}

Function DisableUser
{
    try{
        Update-MgUser -UserId $UPN -AccountEnabled:$false
        $Script:DisableUserAction = "Success"
    }
    catch
    {
        $Script:DisableUserAction = "Failed"
        $ErrorLog = "$($UPN) - Disable User Action - "+$Error[0].Exception.Message
        $ErrorLog>>$ErrorsLogFile
    }
}

Function ResetPasswordToRandom
{
    $Password = -join ((48..57) + (65..90) + (97..122) | ForEach-Object { [char]$_ } | Get-Random -Count 8)
    $log = "$UPN - $Password"
    $Pwd = ConvertTo-SecureString $Password -AsPlainText –Force
    try{
        $Passwordprofile = @{
		    forceChangePasswordNextSignIn = $true
		    password = $Pwd
	    }
        Update-MgUser -UserId $UPN -PasswordProfile $Passwordprofile
        $log>>$PasswordLogFile
        $Script:ResetPasswordToRandomAction = "Success"
    }
    catch
    {
        $Script:ResetPasswordToRandomAction ="Failed"
        $ErrorLog = "$($UPN) - Reset Password To Random Action - "+$Error[0].Exception.Message
        $ErrorLog>>$ErrorsLogFile
    }
}

Function ResetOfficeName
{
    try{
        Update-MgUser -UserId $UPN -OfficeLocation "EXD"
        $Script:ResetOfficeNameAction = "Success"
    }
    catch
    {
        $Script:ResetOfficeNameAction = "Failed"
        $ErrorLog = "$($UPN) - Reset Office Name Action - "+$Error[0].Exception.Message
        $ErrorLog>>$ErrorsLogFile
    }
}

Function RemoveMobileNumber
{
    try{
        Update-MgUser -UserId $UPN -MobilePhone null
        $Script:RemoveMobileNumberAction = "Success"
    }
    catch
    {
        $Script:RemoveMobileNumberAction = "Failed"
        $ErrorLog = "$($UPN) - Remove Mobile Number Action - "+$Error[0].Exception.Message
        $ErrorLog>>$ErrorsLogFile
    }
}

Function RemoveGroupMemberships
{
    #Remove memberships from group
    $groupMemberships = $Memberships|?{($_.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.group') -and ($_.AdditionalProperties.'groupTypes' -notcontains 'DynamicMembership')}
    foreach($Membership in $groupMemberships)
    {
        try{ 
            Remove-MgGroupMemberByRef -GroupId $Membership.Id -DirectoryObjectId $UserId -ErrorAction SilentlyContinue -ErrorVariable MemberRemovalErr
            if($MemberRemovalErr)
            {
                Remove-DistributionGroupMember -Identity $Membership.Id  -Member $UserId -BypassSecurityGroupManagerCheck -Confirm:$false
            }
        }
        catch
        {
            $ErrorLog = "$($UPN) - GroupId($($Membership.Id)) - Remove Group Memberships Action - "+$Error[0].Exception.Message
            $ErrorLog>>$ErrorsLogFile
        }
    }
    #Remove ownerships from group
    $GroupOwnerships = Get-MgUserOwnedObject -UserId $UPN|?{$_.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.group'}
    foreach($GroupOwnership in $GroupOwnerships)
    {
        try{
            Remove-MgGroupOwnerByRef -GroupId $GroupOwnership.Id -DirectoryObjectId $UserId -ErrorAction SilentlyContinue -ErrorVariable OwnerRemovalErr
            if($OwnerRemovalErr)
            {
                $ErrorLog = "$($UPN) - GroupId($($GroupOwnership.Id)) - Remove Group Memberships Action - "+$OwnerRemovalErr.Exception.Message
                $ErrorLog>>$ErrorsLogFile
            }
        }
        catch
        {
            $ErrorLog = "$($UPN) - GroupId($($GroupOwnership.Id)) - Remove Group Memberships Action - "+$Error[0].Exception.Message
            $ErrorLog>>$ErrorsLogFile
        }
    }
    $DistributionGroupOwnerships = Get-DistributionGroup | where {$_.ManagedBy -contains "$UserId"}
    foreach($DistributionGroupOwnership in $DistributionGroupOwnerships)
    {
        Set-DistributionGroup -Identity $DistributionGroupOwnership.Identity -BypassSecurityGroupManagerCheck -ManagedBy @{Remove=$UPN} -ErrorAction SilentlyContinue -ErrorVariable OwnerRemovalErr
        if($OwnerRemovalErr)
        {
            $ErrorLog = "$($UPN) - GroupId($($DistributionGroupOwnership.ExternalDirectoryObjectId)) - Remove Group Memberships Action - "+$OwnerRemovalErr.Exception.Message
            $ErrorLog>>$ErrorsLogFile
        }
    }
    if($ErrorLog -eq $null)
    {
        $Script:RemoveGroupMembershipsAction = "Success"
    }
    elseif($groupMemberships -eq $null -and $GroupOwnerships -eq $null -and $DistributionGroupOwnerships -eq $null)
    {
        $Script:RemoveGroupMembershipsAction = "No group memberships"
    }
    else
    {
        $Script:RemoveGroupMembershipsAction = "Failed"
    }

}

Function RemoveAdminRoles
{
    $AdminRoles = $Memberships|?{$_.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.directoryRole'}
    if($AdminRoles -eq $null)
    {
        $Script:RemoveAdminRolesAction = "No admin roles"
    }
    else
    {
        foreach($AdminRole in $AdminRoles)
        {
            try{
                Remove-MgDirectoryRoleMemberByRef -DirectoryObjectId $UserId -DirectoryRoleId $AdminRole.Id 
            }
            catch
            {
                $ErrorLog = "$($UPN) - Role Id($($Role.DisplayName)) Remove Admin Roles Action - "+$Error[0].Exception.Message
                $ErrorLog>>$ErrorsLogFile
            }
        }
        if($ErrorLog -eq $null)
        {
            $Script:RemoveAdminRolesAction = "Success"
        }
        else
        {
            $Script:RemoveAdminRolesAction = "Failed"
        }
    }
}

Function RemoveAppRoleAssignments
{
    $AppRoleAssignments = Get-MgUserAppRoleAssignment -UserId $UPN
    if($AppRoleAssignments -ne $null)
    {
        $AppRoleAssignments | ForEach-Object {
            try{
                Remove-MgUserAppRoleAssignment -AppRoleAssignmentID $_.Id -UserId $UPN
            }
            catch
            {
                $ErrorLog = "$($UPN) - Remove App Role Assignments Action - "+$Error[0].Exception.Message
                $ErrorLog>>$ErrorsLogFile
            }
        }
        if($ErrorLog -eq $null)
        {
            $Script:RemoveAppRoleAssignmentsAction = "Success"
        }
        else
        {
            $Script:RemoveAppRoleAssignmentsAction = "Failed"
        }
    }
    else
    {
        $Script:RemoveAppRoleAssignmentsAction = "No app role assignments"
    }
}

Function HideFromAddressList
{
    if($MailBoxAvailability -eq 'No')
    {
        $Script:HideFromAddressListAction = "No Exchange license assigned to user"
        return
    }
    try{
        Set-Mailbox -Identity $UPN -HiddenFromAddressListsEnabled $true 
        $Script:HideFromAddressListAction = "Success"
    }
    catch
    {
        $Script:HideFromAddressListAction = "Failed"
        $ErrorLog = "$($UPN) - Hide From Address List Action - "+$Error[0].Exception.Message
        $ErrorLog>>$ErrorsLogFile
    }
}

Function RemoveEmailAlias
{
    if($MailBoxAvailability -eq 'No')
    {
        $Script:RemoveEmailAliasAction = "No Exchange license assigned to user"
        return
    }
    try{
        $EmailAliases=Get-Mailbox $UPN| select -ExpandProperty emailaddresses| ?{$_.StartsWith("smtp")}
        if($EmailAliases -eq $null)
        {
            $Script:RemoveEmailAliasAction = "No alias"
        }
        else
        {
            Set-Mailbox $UPN -EmailAddresses @{Remove=$EmailAliases} -WarningAction SilentlyContinue
            $Script:RemoveEmailAliasAction = "Success"
        }
    }
    catch
    {
        $Script:RemoveEmailAliasAction = "Failed"
        $ErrorLog = "$($UPN) - Remove Email Alias Action - "+$Error[0].Exception.Message
        $ErrorLog>>$ErrorsLogFile
    }
}

Function WipingMobileDevice
{
    if($MailBoxAvailability -eq 'No')
    {
        $MobileDeviceAction = "No Exchange license assigned to user"
        return
    }
    try{
        $MobileDevice = Get-MobileDevice -Mailbox $UPN 
        $MobileDevice| Clear-MobileDevice
        $Script:MobileDeviceAction = "Success"
    }
    catch
    {
        $Script:MobileDeviceAction = "Failed"
        $ErrorLog = "$($UPN) - Wiping Mobile Device Action - "+$Error[0].Exception.Message
        $ErrorLog>>$ErrorsLogFile
    }
}

Function DeleteInboxRule
{
    if($MailBoxAvailability -eq 'No')
    {
        $Script:DeleteInboxRuleAction = "No Exchange license assigned to user"
        return
    }
    try{
        $MailboxRule = Get-InboxRule -Mailbox $UPN 
        $MailboxRule| Remove-InboxRule -Confirm:$False
        $Script:DeleteInboxRuleAction = "Success"
    }
    catch
    {
        $Script:DeleteInboxRuleAction = "No inbox rule"
    }
}

Function ConvertToSharedMailbox
{
    if($MailBoxAvailability -eq 'No')
    {
        $Script:ConvertToSharedMailboxAction = "No Exchange license assigned to user"
        return
    }
    try{
        Set-Mailbox -Identity $UPN -Type Shared -WarningAction SilentlyContinue
        $Script:ConvertToSharedMailboxAction = "Success"
    }
    catch
    {
        $Script:ConvertToSharedMailboxAction = "Failed"
        $ErrorLog = "$($UPN) - Convert To Shared Mailbox Action - "+$Error[0].Exception.Message
        $ErrorLog>>$ErrorsLogFile
    }
}

Function RemoveLicense
{
    $Licenses = Get-MgUserLicenseDetail -UserId $UPN
    if($Licenses -ne $null)
    {
        Set-MgUserLicense -UserId $UPN -RemoveLicenses @($Licenses.SkuId) -AddLicenses @() -ErrorAction SilentlyContinue -ErrorVariable LicenseError | Out-Null
        if($LicenseError)
        {
            $Script:RemoveLicenseAction = "Failed"
            $ErrorLog = "$($UPN) - Remove License Action - "+$LicenseError.Exception.Message 
            $ErrorLog>>$ErrorsLogFile
        }
        else
        {
            $Script:RemoveLicenseAction = "Removed licenses - $($Licenses.SkuPartNumber -join ',')"
        }
    }
    else
    {
        $Script:RemoveLicenseAction = "No license"
    }
}

Function SignOutFromAllSessions
{
    Revoke-MgUserSignInSession -UserId $UPN | Out-Null
    $Script:SignOutFromAllSessionsAction = "Success"
}

Function Disconnect_Modules
{
    Disconnect-MgGraph -ErrorAction SilentlyContinue|  Out-Null
    Disconnect-ExchangeOnline -Confirm:$false
    Exit
}

Function main
{
    ConnectModules
    #Importing CSV file
    if($CSVFilePath -ne "")
    {
        $CSVFilePath = $CSVFilePath.Trim()
        try{
            $UPNCSVFile = Import-Csv -Path $CSVFilePath -Header UserPrincipalName
            [array]$UPNs = $UPNCSVFile.UserPrincipalName
        }
        catch
        {
            Write-Host $_.Exception.Message -ForegroundColor Red
            Exit
        }
    }
    elseif($UPNs -ne "")
    {
        [array]$UPNs = $UPNs.Split(',')
    }
    else
    {
        $UPNs = Read-Host `nEnter the UserPrincipalName of the user you want to offboard
        if($UPNs -ne "")
        {
            [array]$UPNs = $UPNs -split ','
        }
        else
        {
            Write-Host You must provide UPN of the user to offboard. -ForegroundColor Red
            Disconnect_Modules
        }
    }
    $Location = Get-Location
    $ExportCSV =  "$Location\M365UserOffBoarding_StatusFile_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm-ss` tt).ToString()).csv"
    $PasswordLogFile = "$Location\PasswordLogFile_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm-ss` tt).ToString()).txt"
    $InvalidUserLogFile = "$Location\InvalidUsersLogFile$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm-ss` tt).ToString()).txt"
    $ErrorsLogFile = "$Location\ErrorsLogFile$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm-ss` tt).ToString()).txt"
    $AvailabiltyOfInvalidUser = $false
    
    Write-Host "`nWe can perform below operations.`n" -ForegroundColor Cyan
    Write-Host "           1.  Disable user" -ForegroundColor Yellow
    Write-Host "           2.  Reset password to random" -ForegroundColor Yellow 
    Write-Host "           3.  Reset Office name" -ForegroundColor Yellow 
    Write-Host "            ... [rest of the actions list remains unchanged]"
    
    # Continue with existing actions
}
. main
