<#
.SYNOPSIS
	Uses WMI to query for installed programs.

.NOTES
    Author: David Howell
    Last Modified: 02/01/2016
    
OUTPUT csv
#>
Get-WmiObject -Class Win32_Product -ErrorAction SilentlyContinue | Select-Object -Property Name, Version, Caption, Description, InstallDate, InstallLocation, InstallSource, LocalPackage, PackageName, ProductID, RegCompany, RegOwner, SKUNumber, Transforms, URLInfoAbout, URLUpdateInfo, Vendor