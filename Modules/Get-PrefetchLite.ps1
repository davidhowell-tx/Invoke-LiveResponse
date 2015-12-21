<#
.SYNOPSIS
	Parses a small amount of data from prefetch files.

.DESCRIPTION
	This script intentionally parses only the execution count and last execution time(s) from a prefetch file to have a quick processing time.

.NOTES
	Author: David Howell
	Last Modified: 12/20/2015
	For a script that parses more information from the Prefetch, please see the following link:
	https://github.com/davidhowell-tx/PS-WindowsForensics/blob/master/Prefetch/Invoke-PrefetchParser.ps1
	
OUTPUT csv
#>

$ASCIIEncoding = New-Object System.Text.ASCIIEncoding
$UnicodeEncoding = New-Object System.Text.UnicodeEncoding

$PrefetchArray = @()

Get-ChildItem -Path "$($Env:windir)\Prefetch" -Filter *.pf -Force | Select-Object -ExpandProperty FullName | ForEach-Object {
	# Open a FileStream to read the file, and a BinaryReader so we can read chunks and parse the data
	$FileStream = New-Object System.IO.FileStream -ArgumentList ($_, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
	$BinReader = New-Object System.IO.BinaryReader $FileStream
	
	# Create a Custom Object to store prefetch info
	$TempObject = "" | Select-Object -Property Name, Hash, LastExecutionTime, NumberOfExecutions
	
	##################################
	# Parse File Information Section #
	##################################
	
	# First 4 Bytes - Version Indicator
	$Version = [System.BitConverter]::ToString($BinReader.ReadBytes(4)) -replace "-",""
	# Next 4 Bytes are "SCCA" Signature
	$ASCIIEncoding.GetString($BinReader.ReadBytes(4)) | Out-Null
	# Next 4 Bytes are of unknown purpose
	# Value is 0x0F000000 for WinXP or 0x11000000 for Win7/8
	[System.BitConverter]::ToString($BinReader.ReadBytes(4)) -replace "-","" | Out-Null
	# 4 Bytes - size of the Prefetch file
	$TempObject | Add-Member -MemberType NoteProperty -Name "PrefetchSize" -Value ([System.BitConverter]::ToUInt32($BinReader.ReadBytes(4),0))
	# 60 bytes - Unicode encoded executable name
	$TempObject.Name = $UnicodeEncoding.GetString($BinReader.ReadBytes(60))
	# 4 bytes - the prefetch hash
	$TempObject.Hash = [System.BitConverter]::ToString($BinReader.ReadBytes(4)) -replace "-",""
	# 4 bytes - unknown purpose
	$BinReader.ReadBytes(4) | Out-Null
	
	# Use Version Indicator to determine prefetch structure type and switch to the appropriate processing
	switch ($Version) {
		# Windows XP Structure
		"11000000" {
			$BinReader.ReadBytes(36) | Out-Null
			# 8 bytes - Last Execution Time
			$TempObject.LastExecutionTime = [DateTime]::FromFileTime([System.BitConverter]::ToUInt64($BinReader.ReadBytes(8),0)).ToString("G")
			# 16 bytes - Unknown
			$BinReader.ReadBytes(16) | Out-Null
			# 4 bytes - Execution Count
			$TempObject.NumberOfExecutions = [System.BitConverter]::ToUInt32($BinReader.ReadBytes(4),0)
		}
		
		# Windows 7 Structure
		"17000000" {
			$BinReader.ReadBytes(44) | Out-Null
			# 8 bytes - Last Execution Time
			$TempObject.LastExecutionTime = [DateTime]::FromFileTime([System.BitConverter]::ToUInt64($BinReader.ReadBytes(8),0)).ToString("G")
			# 16 bytes - Unknown
			$BinReader.ReadBytes(16) | Out-Null
			# 4 bytes - Execution Count
			$TempObject.NumberOfExecutions = [System.BitConverter]::ToUInt32($BinReader.ReadBytes(4),0)
		}
		
		# Windows 8 Structure
		"1A000000" {
			# Remove LastExecutionTime since there are 8 instead of 1
			$TempObject.PSObject.Properties.Remove("LastExecutionTime")
			$BinReader.ReadBytes(44) | Out-Null
			# 8 bytes - 1st Last Execution Time
			$TempObject | Add-Member -MemberType NoteProperty -Name "LastExecutionTime_1" -Value ([DateTime]::FromFileTime([System.BitConverter]::ToUInt64($BinReader.ReadBytes(8),0)).ToString("G"))
			# 8 bytes - 2nd Last Execution Time
			$TempObject | Add-Member -MemberType NoteProperty -Name "LastExecutionTime_2" -Value ([DateTime]::FromFileTime([System.BitConverter]::ToUInt64($BinReader.ReadBytes(8),0)).ToString("G"))
			# 8 bytes - 3rd Last Execution Time
			$TempObject | Add-Member -MemberType NoteProperty -Name "LastExecutionTime_3" -Value ([DateTime]::FromFileTime([System.BitConverter]::ToUInt64($BinReader.ReadBytes(8),0)).ToString("G"))
			# 8 bytes - 4th Last Execution Time
			$TempObject | Add-Member -MemberType NoteProperty -Name "LastExecutionTime_4" -Value ([DateTime]::FromFileTime([System.BitConverter]::ToUInt64($BinReader.ReadBytes(8),0)).ToString("G"))
			# 8 bytes - 5th Last Execution Time
			$TempObject | Add-Member -MemberType NoteProperty -Name "LastExecutionTime_5" -Value ([DateTime]::FromFileTime([System.BitConverter]::ToUInt64($BinReader.ReadBytes(8),0)).ToString("G"))
			# 8 bytes - 6th Last Execution Time
			$TempObject | Add-Member -MemberType NoteProperty -Name "LastExecutionTime_6" -Value ([DateTime]::FromFileTime([System.BitConverter]::ToUInt64($BinReader.ReadBytes(8),0)).ToString("G"))
			# 8 bytes - 7th Last Execution Time
			$TempObject | Add-Member -MemberType NoteProperty -Name "LastExecutionTime_7" -Value ([DateTime]::FromFileTime([System.BitConverter]::ToUInt64($BinReader.ReadBytes(8),0)).ToString("G"))
			# 8 bytes - 8th Last Execution Time
			$TempObject | Add-Member -MemberType NoteProperty -Name "LastExecutionTime_8" -Value ([DateTime]::FromFileTime([System.BitConverter]::ToUInt64($BinReader.ReadBytes(8),0)).ToString("G"))
			# 16 bytes - Unknown
			$BinReader.ReadBytes(16) | Out-Null
			# 4 bytes - Execution Count
			$TempObject.NumberOfExecutions = [System.BitConverter]::ToUInt32($BinReader.ReadBytes(4),0)
		}
		
		# Windows 10 Structure
		"1E000000" {
			# Remove LastExecutionTime since there are 8 instead of 1
			$TempObject.PSObject.Properties.Remove("LastExecutionTime")
			$BinReader.ReadBytes(44) | Out-Null
			# 8 bytes - 1st Last Execution Time
			$TempObject | Add-Member -MemberType NoteProperty -Name "LastExecutionTime_1" -Value ([DateTime]::FromFileTime([System.BitConverter]::ToUInt64($BinReader.ReadBytes(8),0)).ToString("G"))
			# 8 bytes - 2nd Last Execution Time
			$TempObject | Add-Member -MemberType NoteProperty -Name "LastExecutionTime_2" -Value ([DateTime]::FromFileTime([System.BitConverter]::ToUInt64($BinReader.ReadBytes(8),0)).ToString("G"))
			# 8 bytes - 3rd Last Execution Time
			$TempObject | Add-Member -MemberType NoteProperty -Name "LastExecutionTime_3" -Value ([DateTime]::FromFileTime([System.BitConverter]::ToUInt64($BinReader.ReadBytes(8),0)).ToString("G"))
			# 8 bytes - 4th Last Execution Time
			$TempObject | Add-Member -MemberType NoteProperty -Name "LastExecutionTime_4" -Value ([DateTime]::FromFileTime([System.BitConverter]::ToUInt64($BinReader.ReadBytes(8),0)).ToString("G"))
			# 8 bytes - 5th Last Execution Time
			$TempObject | Add-Member -MemberType NoteProperty -Name "LastExecutionTime_5" -Value ([DateTime]::FromFileTime([System.BitConverter]::ToUInt64($BinReader.ReadBytes(8),0)).ToString("G"))
			# 8 bytes - 6th Last Execution Time
			$TempObject | Add-Member -MemberType NoteProperty -Name "LastExecutionTime_6" -Value ([DateTime]::FromFileTime([System.BitConverter]::ToUInt64($BinReader.ReadBytes(8),0)).ToString("G"))
			# 8 bytes - 7th Last Execution Time
			$TempObject | Add-Member -MemberType NoteProperty -Name "LastExecutionTime_7" -Value ([DateTime]::FromFileTime([System.BitConverter]::ToUInt64($BinReader.ReadBytes(8),0)).ToString("G"))
			# 8 bytes - 8th Last Execution Time
			$TempObject | Add-Member -MemberType NoteProperty -Name "LastExecutionTime_8" -Value ([DateTime]::FromFileTime([System.BitConverter]::ToUInt64($BinReader.ReadBytes(8),0)).ToString("G"))
			# 16 bytes - Unknown
			$BinReader.ReadBytes(16) | Out-Null
			# 4 bytes - Execution Count
			$TempObject.NumberOfExecutions = [System.BitConverter]::ToUInt32($BinReader.ReadBytes(4),0)
		}
	}
	$PrefetchArray += $TempObject
}
return $PrefetchArray