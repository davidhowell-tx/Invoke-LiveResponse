<#
.SYNOPSIS
	Parses the TypedURLs registry key from each user hive.
	
.NOTES
	Author: David Howell
	Last Modified: 01/05/2016

OUTPUT csv
#>


# Setup HKU:\ PSDrive for us to work with
if (!(Get-PSDrive -PSProvider Registry -Name HKU -ErrorAction SilentlyContinue)) {
	New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS -ErrorAction Stop | Out-Null
}

$TypedURLArray = @()

Get-ChildItem -Path HKU:\ | Select-Object -ExpandProperty Name | Where-Object { $_ -notlike "*_Classes" } | ForEach-Object {
	$UserRoot = $_ -replace "HKEY_USERS","HKU:"
	# Get some User Information to determine Username
	$UserInfo = Get-ItemProperty -Path "$UserRoot\Volatile Environment" -ErrorAction SilentlyContinue
	$UserName = "$($UserInfo.USERDOMAIN)\$($UserInfo.USERNAME)"
	
	if (Test-Path -Path "$UserRoot\Software\Microsoft\Internet Explorer\TypedURLs") {
		$TypedURLEntryNames = Get-Item "$UserRoot\Software\Microsoft\Internet Explorer\TypedURLs" | Select-Object -ExpandProperty Property
		
		ForEach ($TypedURLEntryName in $TypedURLEntryNames) {
			$TempObject = New-Object PSObject
			Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "Username" -Value $UserName
			$URL = Get-ItemProperty -Path "$UserRoot\Software\Microsoft\Internet Explorer\TypedURLs" -Name $TypedURLEntryName | Select-Object -ExpandProperty $TypedURLEntryName
			Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "URL" -Value $URL
			if (Test-Path -Path "$UserRoot\Software\Microsoft\Internet Explorer\TypedURLsTime") {
				$URLDateTimeBinary = Get-ItemProperty -Path "$UserRoot\Software\Microsoft\Internet Explorer\TypedURLsTime" -Name $TypedURLEntryName | Select-Object -ExpandProperty $TypedURLEntryName
				if ([System.BitConverter]::ToUInt64($URLDateTimeBinary,0) -eq 0) {
								Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "Time_Entered" -Value ""
				} else {
					$URLDateTime = [DateTime]::FromFileTime([System.BitConverter]::ToUInt64($URLDateTimeBinary,0).ToString("G"))
					Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "Time_Entered" -Value $URLDateTime
				}
			}
			$TypedURLArray += $TempObject
			Remove-Variable -Name URL -ErrorAction SilentlyContinue
			Remove-Variable -Name URLDateTimeBinary -ErrorAction SilentlyContinue
			Remove-Variable -Name URLDateTIme -ErrorAction SilentlyContinue
		}
	}
	Remove-Variable -Name UserInfo -ErrorAction SilentlyContinue
	Remove-Variable -Name UserName -ErrorAction SilentlyContinue
}
$TypedURLArray