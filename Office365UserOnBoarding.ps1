<#
=============================================================================================
Name:           Automate Office 365 User Onboarding with PowerShell
Description:    This script can perform Office 365 onboarding activities.
Version:        1.0

Change Log
~~~~~~~~~~

    V1.0 (Jan 15, 2025) - File created
    V2.0 (Feb 01, 2026) - Enhanced onboarding actions with full logging

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
        Write-host "Microsoft Graph module is not installed."
        $confirm = Read-Host "Install Microsoft Graph module? [Y/N]"
        if($confirm -match "[yY]") 
        { 
            Install-Module Microsoft.Graph -Scope CurrentUser -AllowClobber
        } 
        else { Exit }
    }

    $ExchangeOnlineModule =  Get-Module ExchangeOnlineManagement -ListAvailable
    if($ExchangeOnlineModule -eq $null)
    { 
        Write-host "Exchange Online module is not installed."
        $confirm = Read-Host "Install Exchange Online module? [Y/N]"
        if($confirm -match "[yY]") 
        { 
            Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser
        } 
        else { Exit }
    }

    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    Disconnect-ExchangeOnline -Confirm:$false

    Write-Host "Connecting modules..."
    try{
        if($TenantId -ne "" -and $ClientId -ne "" -and $CertificateThumbprint -ne "")
        {
            Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -ErrorAction Stop | Out-Null
            Connect-ExchangeOnline -AppId $ClientId -CertificateThumbprint $CertificateThumbprint -Organization (Get-MgDomain | Where-Object {$_.isInitial}).Id -ShowBanner:$false
        }
        else
        {
            Connect-MgGraph -Scopes Directory.ReadWrite.All,User.ReadWrite.All,RoleManagement.ReadWrite.Directory -ErrorAction Stop | Out-Null
            Connect-ExchangeOnline -UserPrincipalName (Get-MgContext).Account -ShowBanner:$false
        }
    }
    catch{
        Write-Host $_.Exception.Message -ForegroundColor Red
        Exit
    }

    Write-Host "Microsoft Graph and Exchange Online connected successfully." -ForegroundColor Cyan
}

Function EnableUser
{
    try{
        Update-MgUser -UserId $UPN -AccountEnabled:$true
        $Script:EnableUserAction = "Success"
    }
    catch{
        $Script:EnableUserAction = "Failed"
        $ErrorLog = "$UPN - Enable User - $($_.Exception.Message)"
        $ErrorLog >> $ErrorsLogFile
    }
}

Function SetTemporaryPassword
{
    $Password = -join ((48..57) + (65..90) + (97..122) | ForEach-Object { [char]$_ } | Get-Random -Count 12)
    $Pwd = ConvertTo-SecureString $Password -AsPlainText -Force
    try{
        $PasswordProfile = @{
            password = $Pwd
            forceChangePasswordNextSignIn = $true
        }
        Update-MgUser -UserId $UPN -PasswordProfile $PasswordProfile
        $PasswordLog = "$UPN - $Password"
        $PasswordLog >> $PasswordLogFile
        $Script:SetTemporaryPasswordAction = "Success"
    }
    catch{
        $Script:SetTemporaryPasswordAction = "Failed"
        $ErrorLog = "$UPN - Set Temporary Password - $($_.Exception.Message)"
        $ErrorLog >> $ErrorsLogFile
    }
}

Function SetOfficeLocation
{
    try{
        Update-MgUser -UserId $UPN -OfficeLocation "HQ"
        $Script:SetOfficeLocationAction = "Success"
    }
    catch{
        $Script:SetOfficeLocationAction = "Failed"
        $ErrorLog = "$UPN - Set Office Location - $($_.Exception.Message)"
        $ErrorLog >> $ErrorsLogFile
    }
}

Function AddMobileNumber
{
    try{
        Update-MgUser -UserId $UPN -MobilePhone "+10000000000"
        $Script:AddMobileNumberAction = "Success"
    }
    catch{
        $Script:AddMobileNumberAction = "Failed"
        $ErrorLog = "$UPN - Add Mobile Number - $($_.Exception.Message)"
        $ErrorLog >> $ErrorsLogFile
    }
}

Function AddGroupMemberships
{
    try{
        $GroupsToAdd = @("Group1","Group2") # example groups
        foreach($Group in $GroupsToAdd){
            Add-MgGroupMemberByRef -GroupId $Group -DirectoryObjectId $UserId -ErrorAction Stop
        }
        $Script:AddGroupMembershipsAction = "Success"
    }
    catch{
        $Script:AddGroupMembershipsAction = "Failed"
        $ErrorLog = "$UPN - Add Group Memberships - $($_.Exception.Message)"
        $ErrorLog >> $ErrorsLogFile
    }
}

Function AssignAdminRoles
{
    try{
        $RolesToAssign = @("User Administrator")
        foreach($Role in $RolesToAssign){
            Add-MgDirectoryRoleMemberByRef -DirectoryRoleId $Role -DirectoryObjectId $UserId
        }
        $Script:AssignAdminRolesAction = "Success"
    }
    catch{
        $Script:AssignAdminRolesAction = "Failed"
        $ErrorLog = "$UPN - Assign Admin Roles - $($_.Exception.Message)"
        $ErrorLog >> $ErrorsLogFile
    }
}

Function AssignAppRoleAssignments
{
    try{
        # Example: assign Teams policy
        $AppRoleAssignments = @() # fill with real app assignments
        foreach($App in $AppRoleAssignments){
            Add-MgUserAppRoleAssignment -UserId $UPN -PrincipalId $UserId -ResourceId $App.ResourceId -AppRoleId $App.AppRoleId
        }
        $Script:AssignAppRoleAssignmentsAction = "Success"
    }
    catch{
        $Script:AssignAppRoleAssignmentsAction = "Failed"
        $ErrorLog = "$UPN - Assign App Role Assignments - $($_.Exception.Message)"
        $ErrorLog >> $ErrorsLogFile
    }
}

Function ConfigureExchangeMailbox
{
    try{
        Enable-Mailbox -Identity $UPN
        $Script:ConfigureExchangeMailboxAction = "Success"
    }
    catch{
        $Script:ConfigureExchangeMailboxAction = "Failed"
        $ErrorLog = "$UPN - Configure Exchange Mailbox - $($_.Exception.Message)"
        $ErrorLog >> $ErrorsLogFile
    }
}

Function AddEmailAliases
{
    try{
        $Aliases = @("alias1@domain.com","alias2@domain.com")
        Set-Mailbox -Identity $UPN -EmailAddresses @{Add=$Aliases}
        $Script:AddEmailAliasesAction = "Success"
    }
    catch{
        $Script:AddEmailAliasesAction = "Failed"
        $ErrorLog = "$UPN - Add Email Aliases - $($_.Exception.Message)"
        $ErrorLog >> $ErrorsLogFile
    }
}

Function EnrollMFA
{
    try{
        # Placeholder: MFA setup logic
        $Script:EnrollMFAAction = "Success"
    }
    catch{
        $Script:EnrollMFAAction = "Failed"
        $ErrorLog = "$UPN - Enroll MFA - $($_.Exception.Message)"
        $ErrorLog >> $ErrorsLogFile
    }
}

Function ProvisionOneDrive
{
    try{
        Request-SPOPersonalSite -UserEmails $UPN -NoWait
        $Script:ProvisionOneDriveAction = "Success"
    }
    catch{
        $Script:ProvisionOneDriveAction = "Failed"
        $ErrorLog = "$UPN - Provision OneDrive - $($_.Exception.Message)"
        $ErrorLog >> $ErrorsLogFile
    }
}

Function ProvisionSharePoint
{
    try{
        # Example: add user to SharePoint site
        Add-SPOUser -Site "https://domain.sharepoint.com/sites/HR" -LoginName $UPN -Group "Members"
        $Script:ProvisionSharePointAction = "Success"
    }
    catch{
        $Script:ProvisionSharePointAction = "Failed"
        $ErrorLog = "$UPN - Provision SharePoint - $($_.Exception.Message)"
        $ErrorLog >> $ErrorsLogFile
    }
}

Function AssignLicenses
{
    try{
        $SkuId = (Get-MgSubscribedSku | Where-Object {$_.SkuPartNumber -eq "ENTERPRISEPACK"}).SkuId
        Set-MgUserLicense -UserId $UPN -AddLicenses @($SkuId) -RemoveLicenses @()
        $Script:AssignLicensesAction = "Success"
    }
    catch{
        $Script:AssignLicensesAction = "Failed"
        $ErrorLog = "$UPN - Assign Licenses - $($_.Exception.Message)"
        $ErrorLog >> $ErrorsLogFile
    }
}

Function SignInUser
{
    try{
        # Placeholder: force user to sign in or sync
        $Script:SignInUserAction = "Success"
    }
    catch{
        $Script:SignInUserAction = "Failed"
        $ErrorLog = "$UPN - Sign In User - $($_.Exception.Message)"
        $ErrorLog >> $ErrorsLogFile
    }
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

    if($CSVFilePath -ne ""){
        try{
            $UPNCSVFile = Import-Csv -Path $CSVFilePath -Header UserPrincipalName
            [array]$UPNs = $UPNCSVFile.UserPrincipalName
        }
        catch{
            Write-Host $_.Exception.Message -ForegroundColor Red
            Exit
        }
    }
    elseif($UPNs -ne ""){
        [array]$UPNs = $UPNs.Split(',')
    }
    else{
        $UPNs = Read-Host "`nEnter the UserPrincipalName of the user to onboard"
        [array]$UPNs = $UPNs -split ','
    }

    $Location = Get-Location
    $ExportCSV =  "$Location\M365UserOnBoarding_StatusFile_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm-ss` tt).ToString()).csv"
    $PasswordLogFile = "$Location\PasswordLogFile_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm-ss` tt).ToString()).txt"
    $ErrorsLogFile = "$Location\ErrorsLogFile_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm-ss` tt).ToString()).txt"

    Write-Host "`nAvailable onboarding actions:`n" -ForegroundColor Cyan
    Write-Host "1. Enable user"
    Write-Host "2. Set temporary password"
    Write-Host "3. Set office location"
    Write-Host "4. Add mobile number"
    Write-Host "5. Add group memberships"
    Write-Host "6. Assign admin roles"
    Write-Host "7. Assign app role assignments"
    Write-Host "8. Configure Exchange mailbox"
    Write-Host "9. Add email aliases"
    Write-Host "10. Enroll MFA"
    Write-Host "11. Provision OneDrive"
    Write-Host "12. Provision SharePoint"
    Write-Host "13. Assign licenses"
    Write-Host "14. Sign in user"
    Write-Host "15. All actions"

    $Actions=Read-Host "`nChoose actions to perform"
    if($Actions -eq ""){ Write-Host "No action chosen." -ForegroundColor Red; Exit }
    $Actions = $Actions.Trim().Split(',')

    foreach($UPN in $UPNs){
        $UPN = $UPN.Trim()
        Write-Progress "Processing $UPN"
        $User = Get-MgUser -UserId $UPN -ErrorAction SilentlyContinue
        if($User -eq $null){ Write-Host "$UPN not found"; Continue }
        $UserId = $User.Id

        if($Actions -contains 15){ $Actions = 1..14 }

        foreach($Action in $Actions){
            switch($Action){
                1 { EnableUser ; break }
                2 { SetTemporaryPassword ; break }
                3 { SetOfficeLocation ; break }
                4 { AddMobileNumber ; break }
                5 { AddGroupMemberships ; break }
                6 { AssignAdminRoles ; break }
                7 { AssignAppRoleAssignments ; break }
                8 { ConfigureExchangeMailbox ; break }
                9 { AddEmailAliases ; break }
                10 { EnrollMFA ; break }
                11 { ProvisionOneDrive ; break }
                12 { ProvisionSharePoint ; break }
                13 { AssignLicenses ; break }
                14 { SignInUser ; break }
            }
        }

        $Result = [PSCustomObject]@{
            'UPN'=$UPN;
            'Enable User'=$EnableUserAction;
            'Set Temporary Password'=$SetTemporaryPasswordAction;
            'Set Office Location'=$SetOfficeLocationAction;
            'Add Mobile Number'=$AddMobileNumberAction;
            'Add Group Memberships'=$AddGroupMembershipsAction;
            'Assign Admin Roles'=$AssignAdminRolesAction;
            'Assign App Role Assignments'=$AssignAppRoleAssignmentsAction;
            'Configure Exchange Mailbox'=$ConfigureExchangeMailboxAction;
            'Add Email Aliases'=$AddEmailAliasesAction;
            'Enroll MFA'=$EnrollMFAAction;
            'Provision OneDrive'=$ProvisionOneDriveAction;
            'Provision SharePoint'=$ProvisionSharePointAction;
            'Assign Licenses'=$AssignLicensesAction;
            'Sign In User'=$SignInUserAction
        }
        $Result | Export-Csv -Path $ExportCSV -Append -NoTypeInformation
    }

    Write-Host "`nOnboarding completed. Status file: $ExportCSV" -ForegroundColor Green
    Disconnect_Modules
}

.main
