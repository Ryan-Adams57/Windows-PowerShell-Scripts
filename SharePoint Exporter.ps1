#Created by Kyle Ericson
#Date 8-7-2019
#This will take a .iqy file and convert it to a csv file with only two pop-up boxes to pick the file and save location
#Requires a Windows PC  with Excel installed to run this script on
#I created a .exe with a ps1 to exe application and host it on a Remote App server like Parallels Ras or Citrix


Function Get-FileName($initialDirectory)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
	$OpenFileDialog.Title = "Pick your Microsoft Excel Web Query File from SharePoint(.iqy)"
    $OpenFileDialog.filter = "IQY *.iqy|*.iqy"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
    
    }
    
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$inputfile = Get-FileName $DesktopPath

if ($inputfile -eq "") 
{

Exit}


Function Get-Folder($initialDirectory)

{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")|Out-Null

    $foldername = New-Object System.Windows.Forms.FolderBrowserDialog
    $foldername.Description = "Select a folder"
    $foldername.rootfolder = "MyComputer"

    if($foldername.ShowDialog() -eq "OK")
    {
        $folder += $foldername.SelectedPath
    }
    return $folder
}


$folder = Get-Folder



$workingDir = $folder

$iqyFilePath = $inputfile



$excel = New-Object -ComObject Excel.Application

$workbook = $excel.Workbooks.Open( $iqyFilePath )

$workbook.Worksheets | % {

    $csvPath = $workingDir + "\$($_.name)" + ".csv" 

    $_.saveas( $csvPath, 6 ) 

}

$workbook.close($false)

$excel.quit()
