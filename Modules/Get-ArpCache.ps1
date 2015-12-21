<#
.SYNOPSIS
	Uses arp.exe to get the arp cache from the computer and formats it for output.
	
.NOTES
	Author: David Howell
	Last Modified: 04/02/2015

OUTPUT csv
#>
$ARPCache=@()
# Get ARP Cache
$ARPEntries = & $env:windir\System32\arp.exe -a | Select-String -Pattern "(dynamic|static)" | ForEach-Object { $_ -replace "-" }
# For Each Entry in the ARP Cache, perform the following steps for formatting
ForEach ($ARPEntry in $ARPEntries) {
	# Split to different lines, only return lines with data in them (not blank lines)
	$ARPEntry = $ARPEntry -split " " | Where-Object { $_ }
	# Use the data to create a custom object
	$TempObject=New-Object -TypeName PSObject
	$TempObject | Add-Member -MemberType NoteProperty -Name "IPAddress" -Value $ARPEntry[0]
	$TempObject | Add-Member -MemberType NoteProperty -Name "MACAddress" -Value $ARPEntry[1]
	$TempObject | Add-Member -MemberType NoteProperty -Name "Type" -Value $ARPEntry[2]
	$ARPCache+=$TempObject
}
$ARPCache