<#
.SYNOPSIS
	Checks for entries in the hosts file, parses them and returns a custom object.

.NOTES
    Author: David Howell
    Last Modified: 12/25/2015
    
OUTPUT csv
#>

if (Test-Path -Path $Env:windir\System32\drivers\etc\hosts) {
	$HostsArray = @()
	# Get the Content of the Hosts file, but ignore all the Comment lines and Blank lines
	Get-Content -Path $Env:windir\System32\drivers\etc\hosts | Select-String -Pattern "^(?!(#)).+" | ForEach-Object {
		# Use regex to parse the 2, or possibly 3 groups of information in a line:
		#  IP Address - Host Name - Comments
		if ($_ -match "([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})\s+([^\s]+)\s+(#.+)?") {
			$TempObject = New-Object PSObject
			$TempObject | Add-Member -MemberType NoteProperty -Name "IPAddress" -Value $Matches[1]
			$TempObject | Add-Member -MemberType NoteProperty -Name "Hostname" -Value $Matches[2]
			if ($Matches[3]) {
				$TempObject | Add-Member -MemberType NoteProperty -Name "Comments" -Value $Matches[3]
			}
			$HostsArray += $TempObject
		}
		return $HostsArray
	}
}