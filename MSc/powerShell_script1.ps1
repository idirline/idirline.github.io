#
# Variables
#

$disk = Get-Disk
$disknum = $disk.Number
$volNumber = Get-Volume


#
# Troubleshooting output lines
#
#$disk 
#Write-Host "Disk number: " $disknum

#$volNumber
#Write-Host $volNumber.count " Volumes"


#
# Functions
#

# https://blogs.msdn.microsoft.com/jasonn/2008/06/13/downloading-files-from-the-internet-in-powershell-with-progress/
function downloadFile($url, $targetFile)
{ 
    "Downloading $url" 
    $uri = New-Object "System.Uri" "$url" 
    $request = [System.Net.HttpWebRequest]::Create($uri) 
    $request.set_Timeout(15000) #15 second timeout 
    $response = $request.GetResponse() 
    $totalLength = [System.Math]::Floor($response.get_ContentLength()/1024) 
    $responseStream = $response.GetResponseStream() 
    $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $targetFile, Create 
    $buffer = new-object byte[] 10KB 
    $count = $responseStream.Read($buffer,0,$buffer.length) 
    $downloadedBytes = $count 
    while ($count -gt 0) 
    { 
        [System.Console]::CursorLeft = 0 
        [System.Console]::Write("Downloaded {0}K of {1}K", [System.Math]::Floor($downloadedBytes/1024), $totalLength) 
        $targetStream.Write($buffer, 0, $count) 
        $count = $responseStream.Read($buffer,0,$buffer.length) 
        $downloadedBytes = $downloadedBytes + $count 
    } 
    "`nFinished Download" 
    $targetStream.Flush()
    $targetStream.Close() 
    $targetStream.Dispose() 
    $responseStream.Dispose() 
}


# 
# Code Execution
#

if($volNumber.count -gt 0)
{
	#Write-host 'Volume count greater than 0'
	Clear-Disk -Number $disknum -RemoveData -Confirm:$false
	Initialize-Disk -Number $disknum -PartitionStyle MBR -Confirm:$false
	New-Partition -DiskNumber $disknum -Size 10Gb -DriveLetter T | Out-Null
	Format-Volume -DriveLetter T -NewFileSystemLabel "ImageStore" -FileSystem NTFS | Out-Null
}

if($volNumber.count -eq 0)
{
	Write-host 'Volume count equal to 0'
	New-Partition -DiskNumber $disknum -Size 10Gb -DriveLetter T | Out-Null
	Format-Volume -DriveLetter T -NewFileSystemLabel "ImageStore" -FileSystem NTFS | Out-Null
}

if ((Test-Path T:))
{
	# Download with System.Net.WebClient
	# https://blog.jourdant.me/post/3-ways-to-download-files-with-powershell
	# $url = "http://10.9.21.15/MSc/Win10_1803_Image.wim"
  $url = "ftp://mdt-iso:UIL3E5Rlg63OzEr@ftp.pace.com/Win10_1803_Image.wim"
	$output = "T:\Win10_1803_Image.wim"
	#	(New-Object System.Net.WebClient).DownloadFile($url, $output)
	Write-Host 'Downloading Windows 1803 Image file. Please let the download complete'
  downloadFile "$url" "$output"
}

Write-Host ' '
Write-Host 'Create C: Partition'
New-Partition -DiskNumber $disknum -UseMaximumsize -DriveLetter C | Out-Null
Write-Host 'Format C: Partition'
Format-Volume -DriveLetter C -NewFileSystemLabel "ImageStore" -FileSystem NTFS | Out-Null

Write-Host ' '
Write-Host 'Apply LiteTouchMedia-jh.wim Image to C:'
Dism /apply-image /imagefile:T:\Win10_1803_Image.wim /index:1 /ApplyDir:C:\

Write-Host ''
Write-Host 'Set partition C as active'
Set-Partition -DriveLetter C -IsActive $True

Write-Host ''
Write-Host 'Copy BCDBoot files to C:\Windows'
#Use the BCDboot tool to copy common system partition files and to initialize boot configuration data
#https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/apply-images-using-dism
X:\Windows\System32\bcdboot C:\Windows

sleep 20

#powershell -noprofile -executionpolicy bypass -file powerShell_script1.ps1