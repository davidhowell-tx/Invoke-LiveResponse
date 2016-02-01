<#
.SYNOPSIS
	Returns information about certificates installed on the system.
.NOTES
	Author: David Howell
	Last Modified: 01/22/2016
	
OUTPUT csv
#>

Get-ChildItem -Path Cert:\ -Recurse | Select-Object -Property PSParentPath, FriendlyName, NotBefore, NotAfter, SerialNumber, ThumbPrint, Issuer, Subject, Version