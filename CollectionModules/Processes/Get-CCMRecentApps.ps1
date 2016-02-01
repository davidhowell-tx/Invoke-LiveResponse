<#
.SYNOPSIS
	Use CCM WMI Class to list recently used apps.

.NOTES
	Author: David Howell
	Last Modified: 01/22/2016

OUTPUT csv
#>
if (-not(Get-Command Get-FileHash)) {
	function Get-FileHash {
		<#
		.SYNOPSIS 
			Get-FileHash calculates the hash value of the supplied file.

		.PARAMETER Path
			Path of the file to compute a hash.

		.PARAMETER Algorithm
			Type of hash to calculate (MD5, SHA1, SHA256)

		.NOTES
			Copied from Kansa module on 01/21/2015 and cleaned up by David Howell.
		#>
		[CmdletBinding()]Param(
			[Parameter(Mandatory=$True)]
			[String]$Path,
		
			[Parameter(Mandatory=$True)]
			[ValidateSet("MD5","SHA1","SHA256")]
			[String]$Algorithm
		)

		# Switch to set which Cryptography Class is needed for computation
		Switch ($HashType) {
			"MD5" { $Hash = [System.Security.Cryptography.MD5]::Create() }
			"SHA1" { $Hash = [System.Security.Cryptography.SHA1]::Create() }
			"SHA256" { $Hash = [System.Security.Cryptography.SHA256]::Create() }
		}

		# Test if the provided FilePath exists
		if (Test-Path $FilePath -ErrorAction SilentlyContinue) {
			[PSCustomObject]@{
				Algorithm = $HashType
				Hash = [System.BitConverter]::ToString($Hash.ComputeHash([System.IO.File]::ReadAllBytes($FilePath))) -replace "-",""
				Path = $Path
			}
		}
	}
}

Get-WmiObject -Namespace root\CCM\SoftwareMeteringAgent -Class CCM_RecentlyUsedApps | ForEach-Object {
	if (Test-Path "$($_.FolderPath)\$($_.ExplorerFileName)") { 
		$MD5 = Get-FileHash -Path ("$($_.FolderPath)\$($_.ExplorerFileName)") -Algorithm MD5 | Select-Object -ExpandProperty Hash
		$SHA1 = Get-FileHash -Path ("$($_.FolderPath)\$($_.ExplorerFileName)") -Algorithm SHA1 | Select-Object -ExpandProperty Hash
		$SHA256 = Get-FileHash -Path ("$($_.FolderPath)\$($_.ExplorerFileName)") -Algorithm SHA256 | Select-Object -ExpandProperty Hash
	}
	[PSCustomObject]@{
		ExplorerFileName = $_.ExplorerFileName
		FolderPath = $_.FolderPath
		LastUsedTime = $_.LastUsedTime
		LastUserName = $_.LastUserName
		LaunchCount = $_.LaunchCount
		FileSize = $_.FileSize
		MD5 = $MD5
		SHA1 = $SHA1
		SHA256 = $SHA256
		FileVersion = $_.FileVersion
		msiDisplayName = $_.msiDisplayName
		msiPublisher = $_.msiPublisher
		msiVersion = $_.msiVersion
		OriginalFileName = $_.OriginalFileName
		ProductCode = $_.ProductCode
		ProductName = $_.ProductName
		ProductVersion = $_.ProductVersion
	}
}