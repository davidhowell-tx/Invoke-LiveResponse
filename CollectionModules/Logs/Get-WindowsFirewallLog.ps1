<#
.SYNOPSIS
	Uses netsh to determine Windows Firewall status. If enabled, it returns the content of the Firewall log.
	
.NOTES
	Author: David Howell
	Last Modified: 12/22/2015

OUTPUT csv
#>


# Verify Windows Firewall is enabled before proceeding
if (netsh advfirewall show allprofiles | Select-String "^State\s+ON") {
	# Use Netsh to get the firewall log path.
	# Since netsh returns a string array we have to do some parsing to return just the unique file paths.
	$LogFilePaths = netsh advfirewall show allprofiles | Select-String "^FileName\s+.+$" | ForEach-Object { $_ -split " " } | Where-Object { $_ } | Where-Object { $_ -ne "FileName" } | Select-Object -Unique
	
	# PowerShell doesn't recognize %systemroot%, so we need to change it to $Env:systemroot
	$LogFilePaths = $LogFilePaths -replace "%systemroot%","$Env:systemroot"
	
	ForEach ($LogFile in $LogFilePaths) {
		# First lets parse the available fields in the log file. I don't embed the fields just in case they are ever different
		$Fields = Get-Content -Path $LogFile -TotalCount 10 | Select-String -Pattern "^#Fields" | ForEach-Object { $_ -split " " } | Where-Object { $_ -ne "#Fields:"}
		
		# Now lets read the log line by line, split the string by the spaces, and add the data to a custom object
		Get-Content -Path $LogFile -ReadCount 1 | Select-String -Pattern "^#" -NotMatch | ForEach-Object {
			$TempObject = New-Object PSObject
			$LogEntry = $_ -split " "
			
			for ($i = 0; $i -lt $Fields.Count; $i++) {
				$TempObject | Add-Member -MemberType NoteProperty -Name $Fields[$i] -Value $LogEntry[$i]
			}
			$TempObject
		}
	
	}
}