<#
.SYNOPSIS
	Uses Get-SMBShare or net share to return information about SMB shares

.NOTES
	Author: David Howell
	Last Modified: 01/22/2016

OUTPUT csv
#>

if (Get-Command Get-SmbShare -ErrorAction SilentlyContinue) {
	Get-SmbShare | Select-Object -Property  Name, Description, ShareState, Path, Volume, CurrentUsers, Temporary
} else {
	net share | Select-Object -Skip 4 | Select-String -Pattern "^.+\`$?\s+[A-Za-z]:" | ForEach-Object {
		[String[]]$Array = $_ -split " " | Where-Object { $_ }
		[PSCustomObject]@{
			ShareName = $Array[0]
			Resource = $Array[1]
			Remark = $Array[2]
		}
	}
}