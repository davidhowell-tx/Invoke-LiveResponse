<#
.SYNOPSIS
	Gets Office MRU entries from the registry

.NOTES
	Author: David Howell
	Last Modified: 01/22/2016

OUTPUT csv
#>

# Setup HKU:\ PSDrive for us to work with
if (!(Get-PSDrive -PSProvider Registry -Name HKU -ErrorAction SilentlyContinue)) {
	New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS -ErrorAction Stop | Out-Null
}

# Get a listing of users in HKEY_USERS
$Users = Get-ChildItem -Path HKU:\ -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
$ErrorActionPreference = "SilentlyContinue"
ForEach ($User in $Users) {
	# Rename the root of the path so we can query with it
	$UserRoot = $User -replace "HKEY_USERS","HKU:"
	# Get some User Information to determine Username
	$UserInfo = Get-ItemProperty -Path "$($UserRoot)\Volatile Environment" -ErrorAction SilentlyContinue
	$UserName = "$($UserInfo.USERDOMAIN)\$($UserInfo.USERNAME)"
	
	$FileMRUs = Get-ChildItem -Path $UserRoot\Software\Microsoft\Office -Recurse | Select-Object -ExpandProperty Name | Select-String "user mru\\[^\\]+\\File MRU"
	ForEach ($FileMRU in $FileMRUs) {
		if ($FileMRU -match "^(([^\\]+)\\){7}") {
			$AppName = $matches[2]
		}
		$FileMRUEntries = $FileMRU -replace "HKEY_USERS","HKU:" | ForEach-Object { Get-ItemProperty -Path $_ } 
		ForEach ($FileMRUEntry in $FileMRUEntries) {
			$FileMRUEntry | Get-Member -Name "Item*" | Select-Object -ExpandProperty Definition | ForEach-Object {
				if ($_ -match "^System\.String\sItem\s[0-9]+=(\[[A-Za-z0-9]+\])+\*(.+)") { 
					[PSCustomObject]@{
						Path = $matches[2]
						Username = $UserName
						Application = $AppName
					}
				}
			}
		}
	}
	$PlaceMRUs = Get-ChildItem -Path $UserRoot\Software\Microsoft\Office -Recurse | Select-Object -ExpandProperty Name | Select-String "user mru\\[^\\]+\\Place MRU"
	ForEach ($PlaceMRU in $PlaceMRUs) {
		if ($PlaceMRU -match "^(([^\\]+)\\){7}") {
			$AppName = $matches[2]
		}
		$PlaceMRUEntries = $PlaceMRU -replace "HKEY_USERS","HKU:" | ForEach-Object { Get-ItemProperty -Path $_ }
		ForEach ($PlaceMRUEntry in $PlaceMRUEntries) {
			$PlaceMRUEntry | Get-Member -Name "Item*" | Select-Object -ExpandProperty Definition | ForEach-Object {
				if ($_ -match "^System\.String\sItem\s[0-9]+=(\[[A-Za-z0-9]+\])+\*(.+)") {
					[PSCustomObject]@{
						Path = $matches[2]
						Username = $UserName
						Application = $AppName
					}
				}
			}
		}
	}
}