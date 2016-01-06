<#
.SYNOPSIS
	Uses strings2.exe to list the strings from the memory of a process.
	For information regarding Strings2.exe, see this link: http://split-code.com/strings2.html

.PARAMETER Process_ID
	The Process ID for the process to perform strings against.

.NOTES	
	Author: David Howell
	Last Modified: 12/30/2015

BINARY strings2.exe
OUTPUT txt
INPUT Process_ID
#>

[CmdletBinding()]
Param(	
	[Parameter(Position=0, Mandatory=$True)]
	[String]
	$Process_ID
)

if ($Process_ID) {
	[System.Diagnostics.Process]$Process = Get-Process -Id $Process_ID
	& "C:\Windows\strings2.exe" -pid $Process.Id
}