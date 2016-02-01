<#
.SYNOPSIS
	Parses the TypedURLs registry key from each user hive.
	
.NOTES
	Author: David Howell
	Last Modified: 02/01/2016

OUTPUT csv
#>


# Setup HKU:\ PSDrive for us to work with
if (!(Get-PSDrive -PSProvider Registry -Name HKU -ErrorAction SilentlyContinue)) {
	New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS -ErrorAction Stop | Out-Null
}

Get-ChildItem -Path HKU:\ | Select-Object -ExpandProperty Name | Where-Object { $_ -notlike "*_Classes" } | ForEach-Object {
	$UserRoot = $_ -replace "HKEY_USERS","HKU:"
	# Get some User Information to determine Username
	$UserInfo = Get-ItemProperty -Path "$UserRoot\Volatile Environment" -ErrorAction SilentlyContinue
	$UserName = "$($UserInfo.USERDOMAIN)\$($UserInfo.USERNAME)"
	
	if (Test-Path -Path "$UserRoot\Software\Microsoft\Internet Explorer\TypedURLs") {
		$TypedURLEntryNames = Get-Item "$UserRoot\Software\Microsoft\Internet Explorer\TypedURLs" | Select-Object -ExpandProperty Property
		
		ForEach ($TypedURLEntryName in $TypedURLEntryNames) {
			# Check for a corresponding entry in TypedURLsTime
			if (Test-Path -Path "$UserRoot\Software\Microsoft\Internet Explorer\TypedURLsTime") {
				$URLDateTimeBinary = Get-ItemProperty -Path "$UserRoot\Software\Microsoft\Internet Explorer\TypedURLsTime" -Name $TypedURLEntryName | Select-Object -ExpandProperty $TypedURLEntryName
				$URLDateTimeConverted = [System.BitConverter]::ToUInt64($URLDateTimeBinary,0)
			}
			[PSCustomObject]@{
				Username = $UserName
				URL = Get-ItemProperty -Path "$UserRoot\Software\Microsoft\Internet Explorer\TypedURLs" -Name $TypedURLEntryName | Select-Object -ExpandProperty $TypedURLEntryName
				URLTime = if ($URLDateTimeConverted -eq 0) { "" } else { [DateTime]::FromFileTime($URLDateTimeConverted).ToString("G") }
			}
		}
	}
}