<#
.SYNOPSIS
	Lists the running processes through WMI and calculates their hashes.
	
.NOTES
	Author: David Howell
	Last Modified: 12/11/2015
	
OUTPUT csv
#>

# Use WMI Win32_Process to list the running processes
$WMIProcesses = Get-WmiObject -Class Win32_Process | Select-Object Name, CommandLine, ExecutablePath, Handle, HandleCount, CreationDate, PageFileUsage, PeakPageFileUsage, ParentProcessId, ProcessId

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
    if (Test-Path $FilePath -ErrorAction SilentlyContinue) {
        # Read the Content of the File in Bytes
        $FileinBytes=[System.IO.File]::ReadAllBytes($FilePath)
        # Use CalculateHash Method to determine hash
        $HashofBytes=$Hash.ComputeHash($FileinBytes)
        # Use BitConverter to Convert to String
        $FileHash=[System.BitConverter]::ToString($HashofBytes)
        # Remove the dashes from the hash
        $FileHash.Replace("-","")
    } else {
    	# Unable to locate File at $FilePath
    }
}

# For each process returned, calculate hash values
ForEach($Process in $WMIProcesses) {
    # Reset variable for each loop to be sure we don't add the hash of the previously calculated file to the current file
    $MD5Hash = $null
	$SHA1Hash = $null
	$SHA256Hash = $null
    if ($Process.ExecutablePath -ne $null -and $Process.ExecutablePath -ne "") {
        $MD5Hash = Get-FileHash -FilePath $Process.ExecutablePath -HashType MD5
		$SHA1Hash = Get-FileHash -FilePath $Process.ExecutablePath -HashType SHA1
		$SHA256Hash = Get-FileHash -FilePath $Process.ExecutablePath -HashType SHA256
        $Process | Add-Member -MemberType NoteProperty -Name "MD5" -Value $MD5Hash
		$Process | Add-Member -MemberType NoteProperty -Name "SHA1" -Value $SHA1Hash
		$Process | Add-Member -MemberType NoteProperty -Name "SHA256" -Value $SHA256Hash
    } else {
        $Process | Add-Member -MemberType NoteProperty -Name "MD5" -Value ""
		$Process | Add-Member -MemberType NoteProperty -Name "SHA1" -Value ""
		$Process | Add-Member -MemberType NoteProperty -Name "SHA256" -Value ""
    }
}

$WMIProcesses | Select-Object Name, ExecutablePath, MD5, SHA1, SHA256, ProcessId, ParentProcessId, CreationDate, PageFileUsage, PeakPageFileUsage, Handle, HandleCount, CommandLine