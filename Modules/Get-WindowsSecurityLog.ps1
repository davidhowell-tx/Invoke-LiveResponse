<#
.SYNOPSIS
	Uses Get-EventLog to return Security logs.

.NOTES
    Author: David Howell
    Last Modified: 04/02/2015
    
OUTPUT csv
#>
Try {
	Get-EventLog -LogName Security -ErrorAction SilentlyContinue | Select-Object -Property MachineName, UserName, TimeGenerated, EventID, CategoryNumber, Source, EntryType, Message
} Catch {
}