<#
.SYNOPSIS
	Uses Get-EventLog to return System logs. Can accept a max event count.

.NOTES
    Author: David Howell
    Last Modified: 02/01/2016
    
OUTPUT csv
INPUT MaxCount
#>
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$False)][UInt32]$MaxCount
)
if ($MaxCount) {
	Get-EventLog -LogName System -Newest $MaxCount -ErrorAction SilentlyContinue | Select-Object MachineName, UserName, TimeGenerated, EventID, Source, EntryType, Message
} else {
	Get-EventLog -LogName System -ErrorAction SilentlyContinue | Select-Object MachineName, UserName, TimeGenerated, EventID, Source, EntryType, Message
}