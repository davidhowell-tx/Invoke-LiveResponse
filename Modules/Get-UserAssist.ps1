<#
.SYNOPSIS
	Gets User Assist data out of each user's registry hive and parses the data.
	
.NOTES
	Author: David Howell
	Last Modified: 04/04/2015
	Thanks to Harlan Carvey: https://github.com/appliedsec/forensicscanner/blob/master/plugins/userassist.pl
	OUTPUT csv
#>

# Intialize empty array for results
$ResultArray=@()

function ConvertFrom-Rot13 {
	# Code pulled from http://learningpcs.blogspot.com/2012/06/powershell-v2-function-convertfrom.html
	[CmdletBinding()]Param(
	   [Parameter(Mandatory=$True,ValueFromPipeline=$True)][String]$rot13string
	)
	[String]$String=$null
	$rot13string.ToCharArray() | ForEach-Object {
		if((([int] $_ -ge 97) -and ([int] $_ -le 109)) -or (([int] $_ -ge 65) -and ([int] $_ -le 77))) {
			$String += [char] ([int] $_ + 13)
		} elseif((([int] $_ -ge 110) -and ([int] $_ -le 122)) -or (([int] $_ -ge 78) -and ([int] $_ -le 90))) {
			$String += [char] ([int] $_ - 13)
	   } else {
	      $String += $_
	  }
	}
	$String
}

# Setup HKU:\ PSDrive for us to work with
if (!(Get-PSDrive -PSProvider Registry -Name HKU -ErrorAction SilentlyContinue)) {
	New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS -ErrorAction Stop | Out-Null
}

# Get a listing of users in HKEY_USERS, then process for each one
Get-ChildItem -Path HKU:\ -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name | ForEach-Object {
	# Rename the root of the path so we can query with it
	$UserRoot = $_ -replace "HKEY_USERS","HKU:"
	# Get some User Information to determine Username
	$UserInfo = Get-ItemProperty -Path "$($UserRoot)\Volatile Environment" -ErrorAction SilentlyContinue
	$UserName = "$($UserInfo.USERDOMAIN)\$($UserInfo.USERNAME)"
	
	# Query the User Assist key for this user
	$UserAssistEntries = Get-ItemProperty -Path "$($UserRoot)\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist\*\Count" -ErrorAction SilentlyContinue | ForEach-Object { $_.PSObject.Properties }
	
	# Filter out the uneeded values, then process the entries
	# Entry names are ROT13 encoded, and the values are binary and need to be parsed.
	$UserAssistEntries | Where-Object -FilterScript { $_.Name -notlike "PS*" } | ForEach-Object {
		# Quick and Easy way to create a custom object
		$CustomObject = "" | Select-Object -Property Username, FileName, Count, LastExecuted
		
		$CustomObject.Username = $UserName
		# Convert the Rot13 Encoded Name
		$Name = ConvertFrom-Rot13 -rot13string $_.Name
		switch -regex ($Name) {
			# Regexs created based on information found here: http://sploited.blogspot.ch/2012/12/sans-forensic-artifact-6-userassist.html
			"({1AC14E77\-[A-Z0-9\-]+})\\(.+)" {
				$CustomObject.FileName = "C:\Windows\system32\" + $matches[2]
			}
			
			"({6D809377\-[A-Z0-9\-]+})\\(.+)" {
				$CustomObject.FileName = "C:\Program Files\" + $matches[2]
			}
			
			"({7C5A40EF\-[A-Z0-9\-]+})\\(.+)" {
				$CustomObject.FileName = "C:\Program Files (x86)\" + $matches[2]
			}
			"({D65231B0\-[A-Z0-9\-]+})\\(.+)" {
				$CustomObject.FileName = "C:\Windows\System32\" + $matches[2]
			}
			
			"({B4BFCC3A\-[A-Z0-9\-]+})\\(.+)" {
				$CustomObject.FileName = "UsersDesktop\" + $matches[2]
			}
			
			"({FDD39AD0\-[A-Z0-9\-]+})\\(.+)" {
				$CustomObject.FileName = "UsersDocuments\" + $matches[2]
			}
			
			"({374DE290\-[A-Z0-9\-]+})\\(.+)" {
				$CustomObject.FileName = "UsersDownloads\" + $matches[2]
			}
			
			"({0762D272\-[A-Z0-9\-]+})\\(.+)" {
				$CustomObject.FileName = "UsersProfiles\" + $matches[2]
			}
			
			Default {
				$CustomObject.FileName = $Name
			}
		}
		
		if ($_.Value.Length -eq 16) {
			# Windows XP entries have a length of 16
			$CustomObject | Add-Member -Name Session -MemberType NoteProperty -Value [System.BitConverter]::ToUInt32($_.Value[0..3],0)
			$CustomObject.Count = [System.BitConverter]::ToUInt32($_.Value[4..7],0)
			$CustomObject.LastExecuted = [DateTime]::FromFileTime([System.BitConverter]::ToUInt64($_.Value[8..15],0).ToString("G"))
		} elseif ($_.Value.Length -eq 72) {
			# Windows 7 entries have a length of 72
			$CustomObject.Count = [System.BitConverter]::ToUInt32($_.Value[4..7],0)
			$CustomObject.LastExecuted = [DateTime]::FromFileTime([System.BitConverter]::ToUInt64($_.Value[60..67],0).ToString("G"))		
		} else {
			# Ignore other values for now.
		}
		$ResultArray += $CustomObject
	}
}

$ResultArray