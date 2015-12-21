<#
.SYNOPSIS
	Uses WMI to query for installed programs.

.NOTES
    Author: David Howell
    Last Modified: 04/02/2015
    
OUTPUT csv
#>
Try {
	Get-WmiObject -Class Win32_Product -ErrorAction Stop | Select-Object -Property Name, Version, Caption, Description, InstallDate, InstallLocation, InstallSource, LocalPackage, PackageName, ProductID, RegCompany, RegOwner, SKUNumber, Transforms, URLInfoAbout, URLUpdateInfo, Vendor
} Catch {
}