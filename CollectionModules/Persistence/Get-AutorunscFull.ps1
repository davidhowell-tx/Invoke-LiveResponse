<#
.SYNOPSIS
	Uses Sysinternal's Autorunsc.exe to look at common autorun locations (persistence mechanisms). Calculates file hashes and verifies digital signatures.
	WARNING - This module takes a very long time to complete.

.DESCRIPTION
	Uses the BINARY directive to tell Invoke-LiveResponse to copy the autorunsc.exe binary to the target system, then execute the script, then remove the binary when it is done.

.NOTES
	Last Modified: 12/12/2015
	Written for autorunsc.exe version 13.40

OUTPUT csv
BINARY autorunsc.exe
#>

if (Test-Path "$Env:SystemRoot\Autorunsc.exe" -ErrorAction SilentlyContinue) {
	Try {
		& $Env:SystemRoot\Autorunsc.exe /accepteula -a * -c -h -m -s -t | ConvertFrom-Csv | Select-Object -Property Time, "Entry Location", Entry, Enabled, Category, Profile, Description, Publisher, "Image Path", Version, "Launch String", MD5, "SHA-1", "SHA-256"
	} Catch {
		# Failed to run
	}
}