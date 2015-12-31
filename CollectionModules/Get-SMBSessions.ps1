<#
.SYNOPSIS
	Uses Get-SmbSession or net session to return current SMB sessions

.NOTES
	Author: David Howell
	Last Modified: 12/11/2015

OUTPUT csv
#>

if (Get-Command Get-SmbSession -ErrorAction SilentlyContinue) {
	Try {
		Get-SmbSession -ErrorAction Stop | Select-Object ClientComputerName, ClientUserName, SessionID, NumOpens, SecondsExists, SecondsIdle
	} Catch {
	}
} else {
	# Create an array for our custom objects
	$SessionsArray = @()
	# Get a list of sessions
	$Sessions = net session | Select-String -Pattern "^\\.+"
	
	# Split up the string and parse the information to place into a custom object
	ForEach ($Session in $Sessions) {
		$Metadata = $Session -split " " | Where-Object { $_ }
		
		$CustomObject = New-Object PSObject
		$CustomObject | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value $Metadata[0]
		$CustomObject | Add-Member -MemberType NoteProperty -Name "Username" -Value $Metadata[1]
		
		# The Client Type field tends to be blank (at least on my computer)
		if ($Metadata.Count -eq 5) {
			$CustomObject | Add-Member -MemberType NoteProperty -Name "ClientType" -Value $Metadata[2]
			$CustomObject | Add-Member -MemberType NoteProperty -Name "Opens" -Value $Metadata[3]
			$CustomObject | Add-Member -MemberType NoteProperty -Name "IdleTime" -Value $Metadata[4]
		} elseif ($Metadata.Count -lt 5) {
			for ($i = 2; $i -lt $Metadata.Count; $i++) {
				switch -regex ($Metadata[$i]) {
					"^[0-9][0-9]:[0-9][0-9]:[0-9][0-9]$" {
						# This should catch the Idle Time entry
						$CustomObject | Add-Member -MemberType NoteProperty -Name "IdleTime" -Value $Metadata[$i]
					}
					
					"^[0-9]+$" {
						# This should catch the file opens entry
						$CustomObject | Add-Member -MemberType NoteProperty -Name "Opens" -Value $Metadata[$i]
					}
					
					Default {
						# This is a catchall to catch the Client Type, since I'm unsure all the possible values to create a good regex
						$CustomObject | Add-Member -MemberType NoteProperty -Name "ClientType" -Value $Metadata[$i]
					}
				
				}
			}
		}
		$SessionsArray += $CustomObject
	}
	
	return $SessionsArray
}