 <#
.SYNOPSIS
	Returns the local "Administrators" group's membership.

.NOTES
    Author: David Howell
    Last Modified: 04/02/2015
    
OUTPUT txt
#>

& net localgroup administrators | Select-Object -Skip 6 | Where-Object -FilterScript { 	$_ -and $_ -notmatch "The command completed successfully" } | ForEach-Object {
    $o = "" | Select-Object LocalAdministrators
    $o.LocalAdministrators = $_
    $o
}