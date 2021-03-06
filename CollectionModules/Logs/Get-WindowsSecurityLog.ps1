<#
.SYNOPSIS
	Uses Get-EventLog to return Security logs. Can accept a max event count.

.NOTES
    Author: David Howell
    Last Modified: 12/23/2015
    
OUTPUT csv
INPUT MaxCount
#>
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$False)][UInt32]$MaxCount
)
if ($MaxCount) {
	Get-EventLog -LogName Security -Newest $MaxCount -ErrorAction SilentlyContinue | Select-Object MachineName, UserName, TimeGenerated, EventID, Source, EntryType, Message
} else {
	Get-EventLog -LogName Security -ErrorAction SilentlyContinue | Select-Object MachineName, UserName, TimeGenerated, EventID, Source, EntryType, Message
}