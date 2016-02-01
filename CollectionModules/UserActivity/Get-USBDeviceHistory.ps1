<#
.SYNOPSIS
	Gets USB Device information out of each user's registry hive.
	This module needs some additional work, but gets the job done.
	
.NOTES
	Author: David Howell
	Last Modified: 02/01/2016

OUTPUT csv
#>

# Setup HKU:\ PSDrive for us to work with
if (!(Get-PSDrive -PSProvider Registry -Name HKU -ErrorAction SilentlyContinue)) {
	New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS -ErrorAction Stop | Out-Null
}

$UnicodeEncoding = New-Object System.Text.UnicodeEncoding

# USB Vendor Information Array
$USBDeviceArray = @()
Get-ChildItem HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR | Select-Object -ExpandProperty PSChildName | ForEach-Object {
	if ($_ -match "Disk&Ven_([^&]+)?&Prod_([^&]+)?&Rev_([^&]+)?") {
		$USBDeviceArray += [PSCustomObject]@{
			Vendor = $matches[1]
			Product = $matches[2]
			Version = $matches[3]
			USBSTOR_FullName = $matches[0]
		}
	}
}

ForEach ($USBDevice in $USBDeviceArray) {
	Get-ChildItem -Path "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR\$($USBDevice.USBSTOR_FullName)" | Select-Object -ExpandProperty PSChildName | ForEach-Object {
		Add-Member -InputObject $USBDevice -MemberType NoteProperty -Name "Serial" -Value ($_ -replace "&0","")
	}
	
	Get-ChildItem -Path "HKLM:\SYSTEM\CurrentControlSet\Enum\USB" | ForEach-Object {
		if ((Get-ChildItem -Path ($_.Name -replace "HKEY_LOCAL_MACHINE","HKLM:") | Select-Object -ExpandProperty PSChildName) -eq $USBDevice.Serial) {
			if ($_.PSChildName -match "VID_([^&]+)?&PID_([^&]+)?") {
				Add-Member -InputObject $USBDevice -MemberType NoteProperty -Name "VendorID" -Value $matches[1]
				Add-Member -InputObject $USBDevice -MemberType NoteProperty -Name "ProductID" -Value $matches[2]
			}
		}
	}
	
	Get-Item -Path HKLM:\SYSTEM\MountedDevices | Select-Object -ExpandProperty Property | ForEach-Object {
		$Data = Get-ItemProperty -Path HKLM:\SYSTEM\MountedDevices -Name $_ | Select-Object -ExpandProperty $_
		$MountedDeviceString = $UnicodeEncoding.GetString($Data)
		if ($MountedDeviceString -match ".?USBSTOR#Disk&Ven_(.+)?&Prod_(.+)?&Rev_(.+)?#(.+)?&0#{.+}") {
			if ($matches[1] -eq $USBDevice.Vendor -and $matches[2] -eq $USBDevice.Product -and $matches[3] -eq $USBDevice.Version -and $matches[4] -eq $USBDevice.Serial) {
				if ($_ -match "(\\\?\?\\Volume)?({.+})") {
					Add-Member -InputObject $USBDevice -MemberType NoteProperty -Name "VolumeGUID" -Value $matches[2]
				}
			}
		}
	}
	Add-Member -InputObject $USBDevice -MemberType NoteProperty -Name "User" -Value ""
}

Get-ChildItem -Path HKU:\ | Select-Object -ExpandProperty Name | Where-Object { $_ -notlike "*_Classes" } | ForEach-Object {
	$UserRoot = $_ -replace "HKEY_USERS","HKU:"
	# Get some User Information to determine Username
	$UserInfo = Get-ItemProperty -Path "$UserRoot\Volatile Environment" -ErrorAction SilentlyContinue
	$UserName = "$($UserInfo.USERDOMAIN)\$($UserInfo.USERNAME)"
	$MountPoints = Get-ChildItem -Path "$UserRoot\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty PSChildName
	ForEach ($USBDevice in $USBDeviceArray) {
		if ($MountPoints -contains $USBDevice.VolumeGUID) {
			$USBDevice.User = $UserName
		}
	}
}

ForEach ($USBDevice in $USBDeviceArray) {
	$SetupLog = Select-String -Path C:\Windows\Inf\setupapi.dev.log -Pattern $($USBDevice.Serial), "Boot Session"
	$ConnectionTime = @()
	for ($i=0; $i -lt $SetupLog.Count; $i++) {
		if ($SetupLog[$i] -like "*$($USBDevice.Serial)*") {
			if ($SetupLog[$i-1] -match ".+\[Boot Session: ([0-9/\s:]+)\.[0-9]+\]") {
				$ConnectionTime += $matches[1]
			}
		}
	}
	Add-Member -InputObject $USBDevice -MemberType NoteProperty -Name "ConnectionTime" -Value $ConnectionTime
}

return $USBDeviceArray