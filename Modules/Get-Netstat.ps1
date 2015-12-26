<#
.SYNOPSIS
    Uses Netstat.exe to get a list of network connections on the computer, and the process ID for what created the connection.

.NOTES
    Author: David Howell
    Last Modified: 04/02/2015

OUTPUT csv
#>

# Initialize Array to store our formatted Objects
$NetworkStatistics=@()

# Get a Netstat Listing with Process IDs. Ignore certain entries that are difficult to format
$Stats= & netstat.exe -aon | Select-String -Pattern "(TCP|UDP)(.(?!\[::\]|\*:\*))*$"
# For Each Entry in the Network Statistics, perform the following

ForEach($Stat in $Stats) {
    # Split the row at the spaces, then at the colons. This places the data on a new line.  Only return lines that actually have a value (not blank lines)
    $Stat = $Stat -Split " " | Where-Object -FilterScript { $_ } | ForEach-Object {$_ -Split ":"}
	$TempObject=New-Object -TypeName PSObject
	$TempObject | Add-Member -MemberType NoteProperty -Name "protocol" -Value $Stat[0]
	$TempObject | Add-Member -MemberType NoteProperty -Name "src_ip" -Value $Stat[1]
	$TempObject | Add-Member -MemberType NoteProperty -Name "src_port" -Value $Stat[2]
	$TempObject | Add-Member -MemberType NoteProperty -Name "dst_ip" -Value $Stat[3]
	$TempObject | Add-Member -MemberType NoteProperty -Name "dst_port" -Value $Stat[4]
	$TempObject | Add-Member -MemberType NoteProperty -Name "status" -Value $Stat[5]
	$TempObject | Add-Member -MemberType NoteProperty -Name "process_id" -Value $Stat[6]
    $NetworkStatistics+=$TempObject
}
$NetworkStatistics