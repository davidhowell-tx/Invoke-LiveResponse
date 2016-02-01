<#
.SYNOPSIS
	Uses WMI Win32_StartupCommand class to list persistence keys

.NOTES
	Author: David Howell
	Last Modified: 01/22/2016

OUTPUT csv
#>
Get-WmiObject -Class Win32_StartupCommand | Select-Object -Property Name, Command, Location, User, UserSID