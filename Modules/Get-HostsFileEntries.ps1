<#
.SYNOPSIS
	Checks for entries in the hosts file.

.NOTES
    Author: David Howell
    Last Modified: 12/11/2015
    
OUTPUT txt
#>

if (Test-Path -Path $Env:windir\System32\drivers\etc\hosts) {
	# Get the Content of the Hosts file, but ignore all the Comment lines and Blank lines
	$Hosts = Get-Content -Path $Env:windir\System32\drivers\etc\hosts | Select-String -Pattern "^(?!(#)).+"
	return $Hosts
}