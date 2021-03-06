<#
.SYNOPSIS
	Gathers SCEP logs, uses regex to parse into a custom object, and returns log entries.

.NOTES
    Author: David Howell
    Last Modified: 01/08/2016
   
OUTPUT csv
#>

# Initialize empty array for results
$ResultsArray=@()

# This array is meant to store a list of Possible Locations for SCEP logs.
# The script looks for each of these locations when it's looking for the logs.
$LogPaths=@()
$LogPaths+="$Env:ProgramData\Microsoft\Microsoft Forefront\Client Security\Client\Antimalware\Support"
$LogPaths+="$Env:ProgramData\Microsoft\Microsoft Antimalware\Support"

# Check the Log Paths for MPDetection Logs
$DetectionLogs = Get-ChildItem -Path $LogPaths -Filter "MPDetection*.log" -ErrorAction SilentlyContinue -Force

# Get the content of the logs and filter to only DETECTION events
$Detections = $DetectionLogs | Get-Content -ErrorAction Stop -Force | Select-String -Pattern "DETECTION"

# Parse the detection entries, which are in this format:  EventDateTime "DETECTION" MalwareCategory FilePathOfMalware
ForEach ($Detection in $Detections) {
	$TempObject = New-Object PSObject
	if ($Detection -match "([0-9T:\-Z\.]+) ([A-Z]+) ([A-Za-z:/]+) (.+)") {
		Add-Member -InputObject $TempObject -MemberType NoteProperty -Name EventDateTime -Value $matches[1]
		Add-Member -InputObject $TempObject -MemberType NoteProperty -Name AlertType -Value $matches[2]
		Add-Member -InputObject $TempObject -MemberType NoteProperty -Name Category -Value $matches[3]
		Add-Member -InputObject $TempObject -MemberType NoteProperty -Name FilePath -Value $matches[4]
		$ResultsArray += $TempObject
	}
}
$ResultsArray