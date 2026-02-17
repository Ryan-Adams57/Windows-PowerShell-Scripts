<#
=============================================================================================
Name:           Assign Manager to Microsoft 365 Users Based on User Properties
Description:    This script assigns managers to Microsoft 365 users based on selected user properties
Version:        1.0
Website:        https://www.governmentcontrol.net/

Author:         Ryan Adams
GitHub:         https://github.com/Ryan-Adams57
GitLab:         https://gitlab.com/Ryan-Adams57
PasteBin:       https://pastebin.com/u/Removed_Content

Script Highlights:
1. Uses Microsoft Graph PowerShell and installs Microsoft Graph Beta SDK if not installed.
2. Supports certificate-based authentication (CBA).
3. Assigns Manager using multiple user properties such as Department, Job Title, City, etc.
4. Supports:
     -ExistingManager – Overrides users under a specific existing manager.
     -ImportUsersFromCsvPath – Bulk assignment via CSV input file.
     -ProcessOnlyUnmanagedUsers – Assign manager only to unmanaged users.
     -GetAllUnmanagedUsers – Assign manager to all unmanaged users.
5. Automatically exports matched users to CSV.
6. Credentials supported through parameters.
7. Generates a log file with assignment results.

For detailed script execution: https://www.governmentcontrol.net/
=============================================================================================
#>

param (
    [string] $TenantId,
    [string] $ClientId,
    [string] $CertificateThumbprint,
    [string] $Properties =$null,
    [string] $ExistingManager=$null,
    [switch] $ProcessOnlyUnmanagedUsers,
    [string] $ImportUsersFromCsvPath=$null,
    [switch] $GetAllUnmanagedUsers,
    [string] $ManagerId=""
)

Function ConnectMgGraphModule
{
    $MsGraphBetaModule =  Get-Module Microsoft.Graph.Beta -ListAvailable
    if($MsGraphBetaModule -eq $null)
    { 
        Write-host "Microsoft Graph Beta module is required to run this script." 
        $confirm = Read-Host "Install Microsoft Graph Beta module? [Y] Yes [N] No"  
        if($confirm -match "[yY]") 
        { 
            Write-host "Installing Microsoft Graph Beta module..."
            Install-Module Microsoft.Graph.Beta -Scope CurrentUser -AllowClobber
            Write-host "Microsoft Graph Beta module installed successfully." -ForegroundColor Magenta 
        } 
        else
        { 
            Write-host "Exiting. Microsoft Graph Beta module must be installed." -ForegroundColor Red
            Exit 
        } 
    }

    try{
        if(($TenantId -ne "") -and ($ClientId -ne "") -and ($CertificateThumbprint -ne ""))  
        {  
            Connect-MgGraph -TenantId $TenantId -AppId $ClientId -CertificateThumbprint $CertificateThumbprint -ErrorAction SilentlyContinue -ErrorVariable ConnectionError | Out-Null
            if($ConnectionError -ne $null)
            {    
                Write-Host $ConnectionError -Foregroundcolor Red
                Exit
            }
        }
        else
        {
            Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
            Connect-MgGraph -Scopes "Directory.ReadWrite.All" -ErrorAction SilentlyContinue -Errorvariable ConnectionError | Out-Null
            if($ConnectionError -ne $null)
            {
                Write-Host "$ConnectionError" -Foregroundcolor Red
                Exit
            }
        }
    }
    catch
    {
        Write-Host $_.Exception.Message -ForegroundColor Red
        Exit
    }

    Write-Host "Microsoft Graph Beta PowerShell module connected successfully.`n" -ForegroundColor Green
}

Function RemoveManagedUsers {
    $Users1 = $Users
    $Global:Users = @()
    Foreach ($User in $Users1) {
        $CheckManager = $User.Manager.AdditionalProperties.displayName
        $Percent = $Count / $Users1.length * 100
        $Count++
        Write-Progress -Activity "Checking users with existing manager" -PercentComplete $Percent 
        if($CheckManager.length -eq 0){
             $Global:Users += $User
        }
    }
    Write-Progress -Activity "Users" -Status "Ready" -Completed
}

Function AssignManager {

    if($ProcessOnlyUnmanagedUsers.IsPresent){
        RemoveManagedUsers
    }

    if(($global:Users).length -eq 0) {
        Write-Warning "No users found for this filter criteria."
        CloseConnection
    }

    if($global:AlreadyFromCSV -eq $false){
        ExportUsers
    }

    While ($true) {
        if($ManagerId -eq  ""){
            $ManagerId = Read-Host "Enter manager's UserPrincipalName or ObjectId"
        }

        $Manager = $UsersList | Where-Object {
            $_.UserPrincipalName -eq $ManagerId -or $_.Id -eq $ManagerId
        }

        if($Manager.length -eq 0){
            Write-Warning "Enter a valid UserPrincipalName or ObjectId."
            $ManagerId = ""
            continue
        }
        else {
            break
        }
    }

    $ErrorCount = 0

    Foreach ($User in $global:Users) {

        $log = "Assigning $($Manager.DisplayName) to $($User.DisplayName)"
        $log >> $logfile

        $Percentage = $Count/$global:Users.length * 100

        Write-Progress "Assigning manager ($($Manager.DisplayName)) to user: $($User.UserPrincipalName). Processed: $Count" -PercentComplete $Percentage

        $Param = @{"@odata.id" = "https://graph.microsoft.com/v1.0/users/$($Manager.Id)"}

        Set-MgBetaUserManagerByRef -UserId $User.Id -BodyParameter $Param -ErrorAction SilentlyContinue -ErrorVariable Err 

        if($Err -ne $null)
        {
            "Manager assignment failed" >> $logfile
            $ErrorCount++
            continue
        }

        "Manager assigned successfully" >> $logfile
        $Count++
    }

    if($ErrorCount -ne $Users.Count)
    {
        Write-Host "Manager ($($Manager.DisplayName)) assigned successfully." -ForegroundColor Green
    }

    Write-Host "Log file location: $logfile"

    $prompt = New-Object -ComObject wscript.shell    
    $UserInput = $prompt.popup("Do you want to open the log file?", 0, "Open Log File", 4)    

    if ($UserInput -eq 6) {    
        Invoke-Item "$logfile"
    } 

    CloseConnection
}

Function ExportUsers {
    $Holders = @()
    $HeadName = 'UserName'

    Foreach($User in $global:Users){
        $Obj = New-Object PSObject
        $Obj | Add-Member -MemberType NoteProperty -Name $HeadName -Value $User.UserPrincipalName
        $Holders += $Obj
    }

    $File = "ManagerAssignedUser"+$ReportTime+".csv"
    $Holders | Export-csv $File -NoTypeinformation

    Write-Host "Exported users file location: $Path\$File" -ForegroundColor Green
}

Function GetFilteredUsers{
    Foreach($Property in $FilteredProperties.Keys){
        $FilterProperty = $Property
        $FilterValue = "$($FilteredProperties[$Property])"
        $UsersList = $UsersList | Where-Object { $_.$FilterProperty -eq $FilterValue }
    }
    $global:Users = $UsersList
}

Function ExistingManager {
    $TargetManagerDetails = $UsersList | Where-Object {
        $_.UserPrincipalName -eq $ExistingManager -or $_.Id -eq $ExistingManager
    }

    $UsersList | Foreach {
        $Name = $_.Manager.AdditionalProperties.userPrincipalName
        if ($Name.length -ne 0) {
            Write-Progress -Activity "Checking users with manager $($TargetManagerDetails.DisplayName)" -Status "Processing: $Count - $($_.DisplayName)"   
            if(($Name).compareto($TargetManagerDetails.UserPrincipalName) -eq 0){
                $global:Users += $_
            }
            $Count++
        }
    }
}

Function ImportUsers {
    $UserNames = @()
    $global:AlreadyFromCSV = $true

    try {
        (Import-CSV -path $ImportUsersFromCsvPath) |
        ForEach-Object {
            $UserNames += $_.Username
        }
    }
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        CloseConnection
    }

    if($UserNames.length -eq 0) {
        Write-Warning "No usernames found in the CSV file."
        CloseConnection
    }

    Foreach ($UserName in $UserNames) {
        $Global:Users += $UsersList | Where-Object {
            $_.UserPrincipalName -eq $UserName -or $_.Id -eq $UserName
        }

        Write-Progress "Retrieving users from CSV. Count: $Count" -Activity "Users" -PercentComplete $Count
        $Count++
    }

    Write-Progress -Activity "Users" -Status "Ready" -Completed
}

Function AllUnManagedUsers {
    foreach($User in $UsersList){
        $GetManager = $User.Manager.AdditionalProperties

        Write-Progress "Retrieving unmanaged users. Count: $Count" -Activity "Users" -PercentComplete $Count

        $Count++

        if($GetManager.Count -eq 0)
        {
            $Global:Users += $User
        }
    }

    Write-Progress -Activity "Users" -Status "Ready" -Completed
}

Function GetFilterProperties {

    $FilteredProperties = @{}

    if($Properties -ne "")
    {
        $Properties = $Properties.Split(",")

        Foreach($Property in $Properties)
        {
            $PropertyExists = $UsersList | Get-Member | Where-Object { $_.Name -contains "$Property" }

            if($PropertyExists -eq $null)
            {
                Write-Host "$Property property is not available." -ForegroundColor Red
                CloseConnection
            }

            while($true)
            {
                $PropertyValue = Read-Host "Enter the $Property value"

                if($PropertyValue.Length -eq 0)
                {
                    Write-Host "Value cannot be null. Please enter again." -ForegroundColor Red
                    continue
                }

                break
            }

            $FilteredProperties.Add($Property,$PropertyValue)
        }
    }
    else
    {
        $UserProperties = @("","Department","JobTitle","CompanyName","City","Country","State","UsageLocation","UserPrincipalName","DisplayName","AgeGroup","UserType")

        for ($index=1;$index -lt $UserProperties.length;$index++) {
            Write-Host("$index) $($UserProperties[$index])") -ForegroundColor Yellow
        }

        Write-Host "`nEnter your choice (comma separated for multiple filters)."
        [string]$Properties = Read-Host("Enter your choice")

        while($Properties -eq "")
        {
            Write-Host "Choice cannot be null." -ForegroundColor Red
            [string]$Properties = Read-Host "`nEnter your choice"
        }

        try{
            [int[]]$choice = $Properties.split(',')

            for($i=0;$i -lt $choice.Length;$i++){

                [int]$index = $choice[$i]

                $propertyValue = Read-Host "Enter $($UserProperties[$index]) value"

                if(($propertyValue.length -eq 0)){
                    Write-Host "Value cannot be null. Please enter again." -ForegroundColor Red
                    $i--
                    continue
                }

                $FilteredProperties.Add($UserProperties[$index],$propertyValue)
            }
        }
        catch{
            Write-Host $_.Exception.Message -ForegroundColor Red
            CloseConnection
        }
    }

    GetFilteredUsers
}

Function CloseConnection
{
    Disconnect-MgGraph | Out-Null
    Write-Host "Session disconnected successfully."
    Exit
}

ConnectMgGraphModule

Write-Host "`nIf you encounter module conflicts, run the script in a fresh PowerShell window." -ForegroundColor Yellow

$UsersList = Get-MgBetaUser -All -ExpandProperty Manager
$Global:Users = @()
$Count = 1
$ReportTime = ((Get-Date -format "MMM-dd hh-mm-ss tt").ToString())
$LogFileName = "LOGfileForManagerAssignedUser"+$ReportTime+".txt"
$path = (Get-Location).path
$logfile = "$path\$LogFileName"
$global:AlreadyFromCSV = $false

if($ExistingManager.Length -ne 0){
    ExistingManager
    AssignManager
}

if($ImportUsersFromCsvPath.Length -ne 0){
    ImportUsers
    AssignManager
}

if($GetAllUnmanagedUsers.IsPresent){
    AllUnManagedUsers
    AssignManager
}

GetFilterProperties
AssignManager

Write-Host "`n~~ Script maintained by Ryan Adams ~~`n" -ForegroundColor Green
