<#
.SYNOPSIS
    Uses Netstat.exe to get a list of network connections on the computer, and the process ID for what created the connection.

.NOTES
    Author: David Howell
    Last Modified: 02/01/2016

OUTPUT csv
#>

# Get a Netstat Listing with Process IDs. Ignore certain entries that are difficult to format
$Stats= & netstat.exe -aon | Select-String -Pattern "(TCP|UDP)(.(?!\[::\]|\*:\*))*$"
# For Each Entry in the Network Statistics, perform the following

ForEach($Stat in $Stats) {
    # Split the row at the spaces, then at the colons. This places the data on a new line.  Only return lines that actually have a value (not blank lines)
    $Stat = $Stat -Split " " | Where-Object -FilterScript { $_ } | ForEach-Object {$_ -Split ":"}
	[PSCustomObject]@{
		protocol = $Stat[0]
		src_ip = $Stat[1]
		src_port = $Stat[2]
		dst_ip = $Stat[3]
		dst_port = $Stat[4]
		status = $Stat[5]
		process_id = $Stat[6]
	}
}