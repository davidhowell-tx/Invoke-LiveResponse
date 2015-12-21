<#
.SYNOPSIS
    Gets the running processes and lists the modules being used by each process. 

.NOTES
    Original From Dave Hull's Kansa repository on GitHub: 11/16/2014
    Modified: 12/11/2015
	
OUTPUT csv
#>

# Create an Array for our Process Modules
$ProcessModules=@()

function Get-FileHash {
	<#
	.SYNOPSIS 
	Get-FileHash calculates the hash value of the supplied file.

	.PARAMETER FilePath
	Path of the file to compute a hash.

	.PARAMETER HashType
	Type of hash to calculate (MD5, SHA1, SHA256)

	.NOTES
	Copied from Kansa module on 01/21/2015 and cleaned up by David Howell.
	#>

	[CmdletBinding()]Param(
	[Parameter(Mandatory=$True)][String]$FilePath,
	[ValidateSet("MD5","SHA1","SHA256")][String]$HashType
	)

	# Switch to set which Cryptography Class is needed for computation
	Switch ($HashType.ToUpper()) {
		"MD5" { $Hash=[System.Security.Cryptography.MD5]::Create() }
		"SHA1" { $Hash=[System.Security.Cryptography.SHA1]::Create() }
		"SHA256" { $Hash=[System.Security.Cryptography.SHA256]::Create() }
	}

	# Test if the provided FilePath exists
	if (Test-Path $FilePath) {
		# Read the Content of the File in Bytes
		$FileinBytes=[System.IO.File]::ReadAllBytes($FilePath)
		# Use CalculateHash Method to determine hash
		$HashofBytes=$Hash.ComputeHash($FileinBytes)
		# Use BitConverter to Convert to String
		$FileHash=[System.BitConverter]::ToString($HashofBytes)
		# Remove the dashes from the hash
		$FileHash.Replace("-","")
	} else {
		Write-Host "Unable to locate File at $FilePath"
	}
}

# Use Get-Process command to list all running processes
$Processes = Get-Process -ErrorAction SilentlyContinue | Select-Object -Property Name, Path, Modules, Id
# Loop through each process and get the modules.
ForEach ($Process in $Processes) {
	$Modules=$Process.Modules | Select-Object -Property *
	# Loop through each module, compute their has, and add to the array
	ForEach ($Module in $Modules) {
		$ModuleObject = New-Object -TypeName PSObject
		$ModuleObject | Add-Member -MemberType NoteProperty -Name "ProcessName" -Value $Process.Name
		$ModuleObject | Add-Member -MemberType NoteProperty -Name "ProcessPath" -Value $Process.Path
		$ModuleObject | Add-Member -MemberType NoteProperty -Name "ProcessID" -Value $Process.Id
		$ModuleObject | Add-Member -MemberType NoteProperty -Name "ModuleName" -Value $Module.ModuleName
		$ModuleObject | Add-Member -MemberType NoteProperty -Name "ModuleInternalName" -Value $Module.FileVersionInfo.InternalName
		$ModuleObject | Add-Member -MemberType NoteProperty -Name "ModuleOriginalName" -Value $Module.FileVersionInfo.OriginalFilename
		$ModuleObject | Add-Member -MemberType NoteProperty -Name "ModuleFilePath" -Value $Module.FileName
		$ModuleObject | Add-Member -MemberType NoteProperty -Name "ModuleLanguage" -Value $Module.FileVersionInfo.Language
		$ModuleObject | Add-Member -MemberType NoteProperty -Name "ModuleFileSize" -Value $Module.Size
		$ModuleObject | Add-Member -MemberType NoteProperty -Name "ModuleFileDescription" -Value $Module.Description
		$ModuleObject | Add-Member -MemberType NoteProperty -Name "ModuleFileCompany" -Value $Module.Company
		#$MD5Hash = ""
		#$SHA1Hash = ""
		$SHA256Hash = ""
		# Verify File still exists and get the hash
		if (Test-Path -Path $Module.FileName) {
			#$MD5Hash = Get-FileHash -FilePath $Module.FileName -HashType MD5
			#$SHA1Hash = Get-FileHash -FilePath $Module.FileName -HashType SHA1
			$SHA256Hash = Get-FileHash -FilePath $Module.FileName -HashType SHA256
		}
		$ModuleObject | Add-Member -MemberType NoteProperty -Name "FileHash" -Value $Hash
		$ProcessModules+=$ModuleObject
	}
}

$ProcessModules