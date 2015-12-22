<#
.SYNOPSIS
	Looks for IIS registry key noting log path (if it exists), then parses the IIS logs and returns each line in a custom object.
	WARNING - This module will continue parsing through IIS logs until all are parsed. It can take a long time to complete, and utilize a lot of processing on the target system.

.NOTES
	Author: David Howell
	Last Modified: 12/22/2015
	

OUTPUT csv
#>

# Look for the W3 Service registry entry to determine if IIS is installed
if ((Get-ItemProperty HKLM:\Software\Microsoft\Inetstp\Components -ErrorAction SilentlyContinue).W3SVC) {
	Try {
	# Try to Import the WebAdministration Module and use it to find the IIS Log Paths
		Import-Module WebAdministration -ErrorAction Stop
		
		# List the Sites in IIS, and get the log path for each
		Get-ChildItem -Path IIS:\\Sites -ErrorAction Stop | ForEach-Object {
			# If the Log Path has %SystemDrive% in it, rename it to $Env:SystemDrive to work with PowerShell
			if ($_.logFile.Directory -like "%SystemDrive%*") {
				$TempLocation = $_.logFile.Directory -replace "%SystemDrive%", "$Env:SystemDrive"
			} else {
				$TempLocation = $_.logFile.Directory
			}
			Get-ChildItem -Path $TempLocation -Recurse -Filter *.log -Force | Select-Object -ExpandProperty FullName | ForEach-Object {
				$Fields = Get-Content -Path $_ -TotalCount 10 | Select-String -Pattern "^#Fields" | ForEach-Object { $_ -split " " } | Where-Object { $_ -ne "#Fields:"}
				
				# Now lets read the log line by line, split the string by the spaces, and add the data to a custom object
				Get-Content -Path $_ -ReadCount 1 | Select-String -Pattern "^#" -NotMatch | ForEach-Object {
					$TempObject = New-Object PSObject
					$LogEntry = $_ -split " "
					
					for ($i = 0; $i -lt $Fields.Count; $i++) {
						$TempObject | Add-Member -MemberType NoteProperty -Name $Fields[$i] -Value $LogEntry[$i]
					}
					$TempObject
				}
			}
		}
	} Catch {
	}
} else {
	# IIS doesn't appear to be installed on $Env:COMPUTERNAME.
}