<#
.SYNOPSIS
	Checks the results files for entries with timestamps and combines the events into a single csv file in chronological order.

.DESCRIPTION
	Loops through the results returned from Invoke-LiveResponse and combines entries with times into a single Timeline spreadsheet.
	Uses a table that contains a list of information about compatible modules and field mappings.

.PARAMETER ResultsPath

.NOTES
	Author: David Howell
	Last Modified: 01/04/2016
#>
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$True)]
	[String]
	$ResultsPath
)


# Table to store Module information for timeline parsing 
# Fields:
# 	Name - Name of the module
#	Source - Value to store in the "source" field in the timeline csv
#	Time_Fields - Hashtable containing all time field names, and the type of time. types include:
# 		File Created, File Accessed, File Written, Program Executed, Program Exited, File Read, File Downloaded, Log Generated, URL Visited
#	Metadata_Fields - Hashtable of metadata fields, and their values. Types include:
#		FileName, FilePath, Username, MD5, SHA1, SHA256, ProcessID

#region Field Mapping Table
$Modules = @()
$Modules += $Object = New-Object -TypeName PSObject -Property ( @{ 
	Name = "Get-AppCompatCache.ps1"
	Source = "AppCompatCache"
	Time_Fields = @{ Time = "Program Executed" }
	Metadata_Fields = @{ FilePath = "Name" }
	})
$Modules += $Object = New-Object -TypeName PSObject -Property ( @{ 
	Name = "Get-PrefetchLite.ps1"
	Source = "Prefetch"
	Time_Fields = @{ LastExecutionTime = "Program Executed"; LastExecutionTime_1 = "Program Executed"; LastExecutionTime_2 = "Program Executed"; LastExecutionTime_3 = "Program Executed"; LastExecutionTime_4 = "Program Executed"; LastExecutionTime_5 = "Program Executed"; LastExecutionTime_6 = "Program Executed"; LastExecutionTime_7 = "Program Executed"; LastExecutionTime_8 = "Program Executed" }
	Metadata_Fields = @{ FileName = "Name" }
	})
$Modules += $Object = New-Object -TypeName PSObject -Property ( @{
	Name = "Get-UserAssist.ps1"
	Source = "User Assist"
	Time_Fields = @{ Time_Executed = "Program Executed" }
	Metadata_Fields = @{ FileName = "File_Name"; FilePath = "File_Path"; UserName = "Username" }
	})
$Modules += $Object = New-Object -TypeName PSObject -Property ( @{
	Name = "Get-RekallPSList.ps1"
	Source = "Rekall-PSList"
	Time_Fields = @{ Process_Start_Time = "Program Executed"; Process_End_Time = "Program Exited" }
	Metadata_Fields = @{ FilePath = "Process_File_Path"; FileName = "Process_File_Name"; ProcessID = "Process_ID" }
	})
$Modules += $Object = New-Object -TypeName PSObject -Property ( @{
	Name = "Get-Processes.ps1"
	Source = "Get-Process"
	Time_Fields = @{ Process_Start_Time = "Program Executed"; Process_Exit_Time = "Program Exited" }
	Metadata_Fields = @{ FilePath = "Process_Path"; FileName = "Process_Name"; MD5 = "MD5"; SHA1 = "SHA1"; SHA256 = "SHA256"; ProcessID = "Process_ID" }
	})
#endregion Field Mapping Table

# First check the results in the results directory and parse out the computer names from the results file name
[String[]]$Computers = Get-ChildItem -Path $ResultsPath -File -Filter *.csv -Recurse | ForEach-Object { if ($_.BaseName -match "(.+)-(Get-.+\.ps1)") { $matches[1] } } | Select-Object -Unique

ForEach ($Computer in $Computers) {
	if (-not(Test-Path -Path "$ResultsPath\Analysis")) {
		New-Item -Path "$ResultsPath\Analysis" -ItemType Directory | Out-Null
	}
	# Loop through each result file, check if we have field mappings in the $Modules array, and attempt to parse the data in the results file
	$ResultsFiles = Get-ChildItem -Path "$ResultsPath\" -Filter "$Computer*.csv" -Recurse
	ForEach ($ResultsFile in $ResultsFiles) {
		$ResultsFile.BaseName -match "(.+)-(Get-.+\.ps1)" | Out-Null
		if ($Modules.Name -contains $matches[2]) {
			$ValueMappings = $Modules | Where-Object { $_.Name -eq $matches[2] }
			
			# Process each line for each time field. Some line items can contain multiple time fields (accessed, modified, created) but we want them to appear it the timeline as 3 entries
			Import-Csv -Path $ResultsFile.FullName | ForEach-Object {
				ForEach ($TimeField in $ValueMappings.Time_Fields.Keys) {
					if ($_.$TimeField) {
						$TempObject = New-Object PSObject
					
						$TempObject | Add-Member -MemberType NoteProperty -Name "DateTime" -Value ([DateTime]($_.$TimeField))
						$TempObject | Add-Member -MemberType NoteProperty -Name "Source" -Value $ValueMappings.Source
						$TempObject | Add-Member -MemberType NoteProperty -Name "Event Type" -Value $ValueMappings.Time_Fields.$TimeField
						
						# Add each metadata field
						ForEach ($MetaDataField in $ValueMappings.Metadata_Fields.Keys) {
							if ($MetaDataField -eq "FileName") {
								$TempObject | Add-Member -MemberType NoteProperty -Name "FileName" -Value ($_.($ValueMappings.Metadata_Fields.FileName))
							} elseif ($MetaDataField -eq "FilePath") {
								$TempObject | Add-Member -MemberType NoteProperty -Name "FilePath" -Value ($_.($ValueMappings.Metadata_Fields.FilePath))
							} elseif ($MetaDataField -eq "UserName") {
								$TempObject | Add-Member -MemberType NoteProperty -Name "UserName" -Value ($_.($ValueMappings.Metadata_Fields.UserName))
							} elseif ($MetaDataField -eq "MD5") {
								$TempObject | Add-Member -MemberType NoteProperty -Name "MD5" -Value ($_.($ValueMappings.Metadata_Fields.MD5))
							} elseif ($MetaDataField -eq "SHA1") {
								$TempObject | Add-Member -MemberType NoteProperty -Name "SHA1" -Value ($_.($ValueMappings.Metadata_Fields.SHA1))
							} elseif ($MetaDataField -eq "SHA256") {
								$TempObject | Add-Member -MemberType NoteProperty -Name "SHA256" -Value ($_.($ValueMappings.Metadata_Fields.SHA256))
							} elseif ($MetaDataField -eq "ProcessID") {
								$TempObject | Add-Member -MemberType NoteProperty -Name "ProcessID" -Value ($_.($ValueMappings.Metadata_Fields.ProcessID))
							}
						}
						
						if (-not $TempObject.FileName -and ($TempObject.FilePath)) {
							if ($TempObject.FilePath -match "([^\\]+\\)?(.+)") {
								$TempObject | Add-Member -MemberType NoteProperty -Name "FileName" -Value $matches[2]
							}
						}
						
						$TempObject | Select-Object -Property "DateTime", "Source", "Event Type", "FileName", "FilePath", "Username", "MD5", "SHA1", "SHA256", "ProcessID" | Export-Csv -Path "$ResultsPath\Analysis\$Computer-Timeline.csv" -Append -NoTypeInformation
					}
				}
			}
		}
	}
	
	$Excel = New-Object -ComObject Excel.Application
	$Workbook = $Excel.Workbooks.Open("$ResultsPath\Analysis\$Computer-Timeline.csv")
	$Worksheet = $Workbook.ActiveSheet
	$Worksheet.Columns.Item("A:I").AutoFit()
	$UsedRange = $Worksheet.UsedRange
	$SortRange = $Worksheet.Range("A2")
	$UsedRange.Sort($SortRange,[Microsoft.Office.Interop.Excel.XlSortOrder]::xlDescending)
	$Excel.Save("$ResultsPath\$Computer\Timeline.xlsx")
	$Excel.Quit()
	[System.Runtime.InteropServices.Marshal]::ReleaseComObject($Excel)
}