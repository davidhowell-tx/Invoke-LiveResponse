<#
.SYNOPSIS
	Uses winpmem to mount and access memory, and uses Rekall to dump a process listing with the PSScan` command.
	Written for WinPMem version 1.6.0 and Rekall version 1.4.0 (Etzel). Place the entire Rekall directory under the .\Binaries directory, with winpmem inside.

.NOTES
    Author: David Howell
    Last Modified: 12/31/2015

OUTPUT csv
BINARY rekall
#>
Begin {
	# Load the winpmem driver
	& "$($Env:SystemRoot)\rekall\winpmem_1.6.0.exe" -l | Out-Null
} Process {
	$PSScan = & "$($Env:SystemRoot)\rekall\rekal.exe" --output_style full -q -f \\.\pmem -plugin psscan -F data | ConvertFrom-Json
	
	$Processes = @()
		
	for ($i=0; $i -lt $PSScan.Count; $i++) {
		if ($PSScan[$i] -ne "p" -and $PSScan[$i] -ne "x" -and $PSScan[$i] -notlike "*Merging Address Ranges*") {
			$TempObject = New-Object PSObject

			# Parse Process Creation Time
			if ($PSScan[$i][1].process_create_time.string_value) {
				if ($PSScan[$i][1].process_create_time.string_value -eq "-") {
					$TempObject | Add-Member -MemberType NoteProperty -Name "Process_Start_Time" -Value "-"
				} else {
					$TempObject | Add-Member -MemberType NoteProperty -Name "Process_Start_Time" -Value (Get-Date ($PSScan[$i][1].process_create_time.string_value)).ToString("s")
				}
			}
			
			# Parse Process Exit Time
			if ($PSScan[$i][1].process_exit_time.string_value) {
				if ($PSScan[$i][1].process_exit_time.string_value -eq "-") {
					$TempObject | Add-Member -MemberType NoteProperty -Name "Process_End_Time" -Value "-"
				} else {
					$TempObject | Add-Member -MemberType NoteProperty -Name "Process_End_Time" -Value (Get-Date ($PSScan[$i][1].process_exit_time.string_value)).ToString("s")
				}
			}
			
			# Parse Handle Count
			if ($PSScan[$i][1].handle_count.reason -notlike "*invalid*" -and $PSScan[$i][1].handle_count.reason -notlike "Cannot find*" -and $PSScan[$i][1].handle_count.reason -notlike "*has no member HandleCount*") {
				$TempObject | Add-Member -MemberType NoteProperty -Name "Handle_Count" -Value $PSScan[$i][1].handle_count
			}
			
			# Parse Thread Count
			if ($PSScan[$i][1].thread_count.reason -notlike "*invalid*" -and $PSScan[$i][1].thread_count.reason -notlike "Cannot find*") {
				$TempObject | Add-Member -MemberType NoteProperty -Name "Thread_Count" -Value $PSScan[$i][1].thread_count
			}
			
			# Parse Session ID
			if ($PSScan[$i][1].session_id.reason -notlike "*invalid*" -and $PSScan[$i][1].session_id.reason -notlike "Cannot find*") {
				$TempObject | Add-Member -MemberType NoteProperty -Name "Session_ID" -Value $PSScan[$i][1].session_id
			}
			
			# Parse Wow64 Value
			if ($PSScan[$i][1].wow64.reason -notlike "*invalid*" -and $PSScan[$i][1].wow64.reason -notlike "Cannot find*") {
				$TempObject | Add-Member -MemberType NoteProperty -Name "Wow64" -Value $PSScan[$i][1].wow64
			}
			
			##############################
			# Parse _EPROCESS Information#
			##############################
			
			# Parse Parent PID
			if ($PSScan[$i][1].offset_p.Cybox.Parent_PID.reason -notlike "*invalid*" -and $PSScan[$i][1].offset_p.Cybox.Parent_PID.reason -notlike "Cannot find*") {
				$TempObject | Add-Member -MemberType NoteProperty -Name "Parent_Process_ID" -Value $PSScan[$i][1].offset_p.Cybox.Parent_PID
			}
			
			# Parse Process Name
			if ($PSScan[$i][1].offset_p.Cybox.Name.reason -notlike "*invalid*" -and $PSScan[$i][1].offset_p.Cybox.Name.reason -notlike "Cannot find*") {
				$TempObject | Add-Member -MemberType NoteProperty -Name "Process_File_Name" -Value $PSScan[$i][1].offset_p.Cybox.Name
			}
			
			# Parse Process ID
			if ($PSScan[$i][1].offset_p.Cybox.PID.reason -notlike "*invalid*" -and $PSScan[$i][1].offset_p.Cybox.PID.reason -notlike "Cannot find*") {
				$TempObject | Add-Member -MemberType NoteProperty -Name "Process_ID" -Value $PSScan[$i][1].offset_p.Cybox.PID
			}
			
			# Parse Process Full Path
			if ($PSScan[$i][1].offset_p.Cybox.Image_Info.File_Name.reason -notlike "*invalid*" -and $PSScan[$i][1].offset_p.Cybox.Image_Info.File_Name.reason -notlike "Cannot find*") {
				$TempObject | Add-Member -MemberType NoteProperty -Name "Process_File_Path" -Value $PSScan[$i][1].offset_p.Cybox.Image_Info.File_Name
			}
			
			# Parse Process Command Line Arguments
			if ($PSScan[$i][1].offset_p.Cybox.Image_Info.Command_Line.reason -notlike "*invalid*" -and $PSScan[$i][1].offset_p.Cybox.Image_Info.Command_Line.reason -notlike "Cannot find*") {
				$TempObject | Add-Member -MemberType NoteProperty -Name "Command_Line" -Value $PSScan[$i][1].offset_p.Cybox.Image_Info.Command_Line
			}
			
			# Parse Path from Image Info
			if ($PSScan[$i][1].offset_p.Cybox.Image_Info.Path.reason -notlike "*invalid*" -and $PSScan[$i][1].offset_p.Cybox.Image_Info.Path.reason -notlike "cannot find*") {
				$TempObject | Add-Member -MemberType NoteProperty -Name "Path" -Value $PSScan[$i][1].offset_p.Cybox.Image_Info.Path
			}
			
			$Processes += $TempObject
			Remove-Variable TempObject -ErrorAction SilentlyContinue
		}
	}
	return $Processes
} End {
	# Unload the winpmem driver
	& "C:\Windows\System32\winpmem_1.6.0.exe" -u | Out-Null
}