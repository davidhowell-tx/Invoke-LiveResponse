<#
.SYNOPSIS
	Checks for Sysmon logs and returns logs if available. Optionally accepts a max event count.

.NOTES
	Author: David Howell
	Last Modified: 02/01/2016

OUTPUT csv
INPUT MaxCount
#>

[CmdletBinding()]
Param(
	[Parameter(Mandatory=$False)][Int]$MaxCount
)

if ($MaxCount) {
	$Command = "Get-WinEvent -LogName `"Microsoft-Windows-Sysmon/Operational`" -MaxEvents $MaxCount"
} else {
	$Command = "Get-WinEvent -LogName `"Microsoft-Windows-Sysmon/Operational`""
}

if (Get-WinEvent -ListLog "Microsoft-Windows-Sysmon/Operational") {
	Invoke-Expression -Command $Command | ForEach-Object {
		$TempObject = New-Object PSObject
		Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "EventID" -Value $_.Id
		Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "TaskCategory" -Value $_.TaskDisplayName
		Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "LogTime" -Value $_.TimeCreated.ToString("s")
		
		if ($_.Id -eq 1) {
			# Process Create Event Type
			if ($_.Properties.Count -eq 16) {
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "EventTime" -Value ([DateTime]$_.Properties[0].Value).ToString("s")
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "ProcessGUID" -Value $_.Properties[1].Value.Guid
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "ProcessID" -Value $_.Properties[2].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "ProcessName" -Value $_.Properties[3].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "CommandLine"  -Value $_.Properties[4].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "CurrentDirectory" -Value $_.Properties[5].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "Username" -Value $_.Properties[6].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "LogonGUID" -Value $_.Properties[7].Value.Guid
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "LogonID" -Value $_.Properties[8].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "TerminalSessionID" -Value $_.Properties[9].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "IntegrityLevel" -Value $_.Properties[10].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "Hashes" -Value $_.Properties[11].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "ParentProcessGuid" -Value $_.Properties[12].Value.Guid
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "ParentProcessId" -Value $_.Properties[13].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "ParentImage" -Value $_.Properties[14].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "ParentCommandLine" -Value $_.Properties[15].Value
			} else {
				$PropertyArray = @()
				for ($i=0; $i -lt $_.Properties.Count; $i++) {
					if ($_.Properties[$i].Value.Guid) {
						$PropertyArray += $_.Properties[$i].Value.Guid
					} else {
						$PropertyArray += $_.Properties[$i].Value
					}
				}
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "RawProperties" -Value ($PropertyArray -join ", ")
			}
		} elseif ($_.Id -eq 2) {
			# File Creation Time Changed Event Type
			if ($_.Properties.Count -eq 7) {
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "EventTime" -Value ([DateTime]$_.Properties[0].Value).ToString("s")
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "ProcessGUID" -Value $_.Properties[1].Value.Guid
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "ProcessID" -Value $_.Properties[2].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "ProcessName" -Value $_.Properties[3].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "FileName"  -Value $_.Properties[4].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "NewCreationTime" -Value ([DateTime]$_.Properties[5].Value).ToString("s")
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "OldCreationTime" -Value ([DateTime]$_.Properties[6].Value).ToString("s")
			} else {
				$PropertyArray = @()
				for ($i=0; $i -lt $_.Properties.Count; $i++) {
					if ($_.Properties[$i].Value.Guid) {
						$PropertyArray += $_.Properties[$i].Value.Guid
					} else {
						$PropertyArray += $_.Properties[$i].Value
					}
				}
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "RawProperties" -Value ($PropertyArray -join ", ")
			}
		} elseif ($_.Id -eq 3) {
			# Network Connection Detected Event Type
			if ($_.Properties.Count -eq 17) {
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "EventTime" -Value ([DateTime]$_.Properties[0].Value).ToString("s")
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "ProcessGUID" -Value $_.Properties[1].Value.Guid
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "ProcessID" -Value $_.Properties[2].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "ProcessName" -Value $_.Properties[3].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "User"  -Value $_.Properties[4].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "Protocol" -Value $_.Properties[5].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "Initiated" -Value $_.Properties[6].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "SourceIsIPv6" -Value $_.Properties[7].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "SourceIP" -Value $_.Properties[8].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "SourceHostname" -Value $_.Properties[9].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "SourcePort" -Value $_.Properties[10].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "SourcePortName" -Value $_.Properties[11].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "DestinationIsIPv6" -Value $_.Properties[12].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "DestinationIP" -Value $_.Properties[13].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "DestinationHostname" -Value $_.Properties[14].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "DestinationPort" -Value $_.Properties[15].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "DestinationPortName" -Value $_.Properties[16].Value
			} else {
				$PropertyArray = @()
				for ($i=0; $i -lt $_.Properties.Count; $i++) {
					if ($_.Properties[$i].Value.Guid) {
						$PropertyArray += $_.Properties[$i].Value.Guid
					} else {
						$PropertyArray += $_.Properties[$i].Value
					}
				}
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "RawProperties" -Value ($PropertyArray -join ", ")
			}
		} elseif ($_.Id -eq 4) {
			# Sysmon Service State Changed Event Type
			if ($_.Properties.Count -eq 2) {
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "EventTime" -Value ([DateTime]$_.Properties[0].Value).ToString("s")
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "State" -Value $_.Properties[1].Value
			} else {
				$PropertyArray = @()
				for ($i=0; $i -lt $_.Properties.Count; $i++) {
					if ($_.Properties[$i].Value.Guid) {
						$PropertyArray += $_.Properties[$i].Value.Guid
					} else {
						$PropertyArray += $_.Properties[$i].Value
					}
				}
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "RawProperties" -Value ($PropertyArray -join ", ")
			}
		} elseif ($_.Id -eq 5) {
			# Process Terminated Event Type
			if ($_.Properties.Count -eq 4) {
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "EventTime" -Value ([DateTime]$_.Properties[0].Value).ToString("s")
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "ProcessGUID" -Value $_.Properties[1].Value.Guid
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "ProcessID" -Value $_.Properties[2].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "ProcessName" -Value $_.Properties[3].Value
			} else {
				$PropertyArray = @()
				for ($i=0; $i -lt $_.Properties.Count; $i++) {
					if ($_.Properties[$i].Value.Guid) {
						$PropertyArray += $_.Properties[$i].Value.Guid
					} else {
						$PropertyArray += $_.Properties[$i].Value
					}
				}
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "RawProperties" -Value ($PropertyArray -join ", ")
			}
		} elseif ($_.Id -eq 6) {
			# Driver LoadedEvent Type
			if ($_.Properties.Count -eq 5) {
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "EventTime" -Value ([DateTime]$_.Properties[0].Value).ToString("s")
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "FileName" -Value $_.Properties[1].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "Hashes" -Value $_.Properties[2].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "Signed" -Value $_.Properties[3].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "Signature"  -Value $_.Properties[4].Value
			} else {
				$PropertyArray = @()
				for ($i=0; $i -lt $_.Properties.Count; $i++) {
					if ($_.Properties[$i].Value.Guid) {
						$PropertyArray += $_.Properties[$i].Value.Guid
					} else {
						$PropertyArray += $_.Properties[$i].Value
					}
				}
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "RawProperties" -Value ($PropertyArray -join ", ")
			}
		} elseif ($_.Id -eq 7) {
			# Image Loaded Event Type
			if ($_.Properties.Count -eq 8) {
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "EventTime" -Value ([DateTime]$_.Properties[0].Value).ToString("s")
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "ProcessGUID" -Value $_.Properties[1].Value.Guid
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "ProcessID" -Value $_.Properties[2].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "ProcessName" -Value $_.Properties[3].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "ImageLoaded"  -Value $_.Properties[4].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "Hashes" -Value $_.Properties[5].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "Signed" -Value $_.Properties[6].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "Signature" -Value $_.Properties[7].Value
			} else {
				$PropertyArray = @()
				for ($i=0; $i -lt $_.Properties.Count; $i++) {
					if ($_.Properties[$i].Value.Guid) {
						$PropertyArray += $_.Properties[$i].Value.Guid
					} else {
						$PropertyArray += $_.Properties[$i].Value
					}
				}
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "RawProperties" -Value ($PropertyArray -join ", ")
			}
		} elseif ($_.Id -eq 8) {
			# CreateRemoteThread Detected
			if ($_.Properties.Count -eq 11) {
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "EventTime" -Value ([DateTime]$_.Properties[0].Value).ToString("s")
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "SourceProcessGUID" -Value $_.Properties[1].Value.Guid
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "SourceProcessID" -Value $_.Properties[2].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "SourceProcessName" -Value $_.Properties[3].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "TargetProcessGUID"  -Value $_.Properties[4].Value.Guid
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "TargetProcessID" -Value $_.Properties[5].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "TargetProcessName" -Value $_.Properties[6].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "NewThreadID" -Value $_.Properties[7].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "StartAddress"  -Value $_.Properties[8].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "ModuleName" -Value $_.Properties[9].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "StartFunction" -Value $_.Properties[10].Value
			} else {
				$PropertyArray = @()
				for ($i=0; $i -lt $_.Properties.Count; $i++) {
					if ($_.Properties[$i].Value.Guid) {
						$PropertyArray += $_.Properties[$i].Value.Guid
					} else {
						$PropertyArray += $_.Properties[$i].Value
					}
				}
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "RawProperties" -Value ($PropertyArray -join ", ")
			}
		} elseif ($_.Id -eq 9) {
			# RawAccessRead Detected
			if ($_.Properties.Count -eq 11) {
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "EventTime" -Value ([DateTime]$_.Properties[0].Value).ToString("s")
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "ProcessGUID" -Value $_.Properties[1].Value.Guid
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "ProcessID" -Value $_.Properties[2].Value
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "DeviceAccessed" -Value $_.Properties[3].Value
			} else {
				$PropertyArray = @()
				for ($i=0; $i -lt $_.Properties.Count; $i++) {
					if ($_.Properties[$i].Value.Guid) {
						$PropertyArray += $_.Properties[$i].Value.Guid
					} else {
						$PropertyArray += $_.Properties[$i].Value
					}
				}
				Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "RawProperties" -Value ($PropertyArray -join ", ")
			}
		}
		
		# Break up the Hash array and add as individual properties
		if ($TempObject.Hashes) {
			[String[]]$Hashes = $TempObject.Hashes -split ","
			ForEach ($Hash in $Hashes) {
				switch -regex ($Hash) {
					"^SHA1=(.+)" {
						Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "SHA1" -Value $matches[1]
					}
					
					"^SHA256=(.+)" {
						Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "SHA256" -Value $matches[1]
					}
					
					"^MD5=(.+)" {
						Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "MD5" -Value $matches[1]
					}
					
					"^IMPHASH=(.+)" {
						Add-Member -InputObject $TempObject -MemberType NoteProperty -Name "IMPHASH" -Value $matches[1]
					}
				}
			}
			$TempObject.PSObject.Properties.Remove("Hashes")
		}
		
		$TempObject | Select-Object -Property *
	}
}