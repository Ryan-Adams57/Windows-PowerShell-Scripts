Import-Module ActiveDirectory
cd "C:\Get-Account-Expiration-Report.ps1"

#Deleting Any existent AD Expiration File
Remove-Item -Force AD_Expire_date.csv -Confirm:$false -Recurse

#Generating AD Expiration File
#Get-ADUser -Identity wellington.cesar.adm –Properties Name,SamAccountName,GivenName,EmailAddress,AccountExpirationDate | Select-Object Name,SamAccountName,GivenName,EmailAddress,@{Name="ExpiryDate";Expression={$_.AccountExpirationDate}} | Export-Csv AD_Expire_date.csv -NoTypeInformation -Encoding UTF8
Get-ADUser -filter {Enabled -eq $True} –Properties Name,SamAccountName,GivenName,EmailAddress,AccountExpirationDate -Server wegdadc17 | Where-Object{$_.AccountExpirationDate -ne $null} | Select-Object Name,SamAccountName,GivenName,EmailAddress,@{Name="ExpiryDate";Expression={$_.AccountExpirationDate}} | Export-Csv AD_Expire_date.csv -NoTypeInformation -Encoding UTF8
#Get-ADUser -filter {Enabled -eq $True} –Properties Name,SamAccountName,GivenName,EmailAddress,AccountExpirationDate -Server wegdadc17  | Select-Object Name,SamAccountName,GivenName,EmailAddress,@{Name="ExpiryDate";Expression={$_.AccountExpirationDate}} | Export-Csv WE_AD_Expire_date.csv -NoTypeInformation -Encoding UTF8

#Import CSV AD Expiration File
$path     = Split-Path -parent $MyInvocation.MyCommand.Definition 
$newpath  = $path + "\AD_Expire_date.csv"
$csv      = @()
$csv      = Import-Csv -Path $newpath

#Setting up SMTP Server and User mailbox.
$smtpServer="smtp-relay.we.interbrew.net"
#$from = "IT Support Team <no-reply.acct.expiration@ab-inbev.com>"
$from = "No-Reply DEX <no-reply-DEX@ab-inbev.com>"

#Getting actual date.
#$date = Get-Date -format ddMMyyyy
#$date.Month
#$date.Day
#$date.Year

#Loop through all items in the CSV
ForEach ($user In $csv){
  
  #Variables required for date counting.
  $maxdays = 0
  $lastset=Get-Date ($user.ExpiryDate)
  $expires=$lastset.AddDays($maxdays)#.ToShortDateString()
  $daystoexpire=[math]::round((New-TimeSpan -Start $(Get-Date) -End $expires).TotalDays)
  $domain = get-addomain
  $domain = $domain.NetBIOSName

  #Variables for user's mail
  $SAM=$user.SamAccountName
  $Gname=$user.GivenName

  $emailaddress = $user.EmailAddress
  #$emailaddress = "vascari.backhage@ab-inbev.com"
  #Write-Host $daystoexpire

    if (($daystoexpire -eq 1))
        {
	$day = "day"
        }else{
        	$day = "days"
        }
     if ($daystoexpire -eq 0) 
        {
          # CONFIG: Enter text for subject and body of email notification for zero days remaining. 
          $subject = "Your account has expired!"
          $body = "
           
          Dear $Gname,
          <p> Your user ID is $domain\$SAM has expired and it's now disabled. <br>      
		  Please also consider reviewing your other accounts, if you have any. <br>
		  <p>Contact our DEX Service Desk for help: <br><br>
		  BE&nbsp;&nbsp;&nbsp;&nbsp;+32 25882460 <br>
		  CZ&nbsp;&nbsp;&nbsp;&nbsp;+420 228887779 <br>
		  FR&nbsp;&nbsp;&nbsp;&nbsp;+33 366881793 <br>
		  IT&nbsp;&nbsp;&nbsp;&nbsp;+39 0282954260 <br>
		  DE&nbsp;&nbsp;&nbsp;&nbsp;+49 42136583135 <br>
		  NL&nbsp;&nbsp;&nbsp;&nbsp;+31 70 77 09 637 <br>
		  SP&nbsp;&nbsp;&nbsp;&nbsp;+34 91 05 07 296 <br>
		  LUX&nbsp;&nbsp;&nbsp;&nbsp;+35 227862580<br>
		  Nordics&nbsp;&nbsp;&nbsp;&nbsp;+46 844686753 <br>
		  UK&nbsp;&nbsp;&nbsp;&nbsp;+44 20 3868 4721 <br>

		  <p> Thank you, <br> 
		  Your DEX Team <br>
		  <p> Please do not reply on this email as the mailbox is not monitored.  <br>
		  </P>"
        Send-Mailmessage -SmtpServer $smtpServer -from $from -to $emailaddress -subject $subject -body $body -bodyasHTML -priority High
		}
	 elseif (($daystoexpire -eq 15) -or ($daystoexpire -eq 7) -or ($daystoexpire -eq 3) -or ($daystoexpire -eq 1))
		{
		  # Email Subject Set Here
		  $subject="Your account is about to expire in $daystoexpire $day"
		  # Email Body Set Here, 
		$body ="
		Dear $Gname,
		<p> Your account will expire in $daystoexpire $day. Your user ID is $domain\$SAM  <br>
        <br>
		    Please create (or ask your ABI SPOC to create) a service request in ServiceNow to extend your account <a href='https://abinbevww.service-now.com/abiex?id=sc_cat_item_abi_it&sys_id=3d33a369db835090faa711494b961985&sysparm_category=3f6a43bbdbce985002085bd05b9619e6&catalog_id=2e3a07fbdb8e985002085bd05b961922' target='_blank'>here</a> <br>
		    For 'Action' click, 'Request for an Account Extension' <br> 
            If no action is taken, your account will be automatically disabled. <br> <p> Please also consider reviewing your other accounts, if you have any. <br>
		    <p> For more help, see <a href='https://abinbevww.service-now.com/abiex?sys_kb_id=2a161ab11bb714d44a803150cd4bcb2c&id=kb_article_view&sysparm_rank=1&sysparm_tsqueryId=a9e34f3547051d94e1b33247e26d43fe' target='_blank'>instructions here</a> or contact the DEX Service Desk: <br><br>
		    BE&nbsp;&nbsp;&nbsp;&nbsp;+32 25882460 <br>
		    CZ&nbsp;&nbsp;&nbsp;&nbsp;+420 228887779 <br>
		    FR&nbsp;&nbsp;&nbsp;&nbsp;+33 366881793 <br>
		    IT&nbsp;&nbsp;&nbsp;&nbsp;+39 0282954260 <br>
		    DE&nbsp;&nbsp;&nbsp;&nbsp;+49 42136583135 <br>
		    NL&nbsp;&nbsp;&nbsp;&nbsp;+31 70 77 09 637 <br>
		    SP&nbsp;&nbsp;&nbsp;&nbsp;+34 91 05 07 296 <br>
		    LUX&nbsp;&nbsp;&nbsp;&nbsp;+35 227862580<br>
		    Nordics&nbsp;&nbsp;&nbsp;&nbsp;+46 844686753 <br>
		    UK&nbsp;&nbsp;&nbsp;&nbsp;+44 20 3868 4721 <br>

		    <p> Thank you, <br> 
		    Your DEX Team <br>
		    <p> Please do not reply on this email as the mailbox is not monitored.  <br>
		    </P>"
#$emailaddress
		Send-Mailmessage -SmtpServer $smtpServer -from $from -to $emailaddress -subject $subject -body $body -bodyasHTML -priority High
		}	
}
