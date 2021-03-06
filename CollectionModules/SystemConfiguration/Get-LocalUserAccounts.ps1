 <#
.SYNOPSIS
	Returns a list of the local user accounts on the computer.

.NOTES
    Author: David Howell
    Last Modified: 04/02/2015
    
OUTPUT csv
#>
  
Get-WMIObject -Class Win32_UserAccount -Filter "LocalAccount='$True'" -ErrorAction SilentlyContinue | Select-Object -Property Domain, Name, FullName, Disabled, PasswordExpires, SID, Description