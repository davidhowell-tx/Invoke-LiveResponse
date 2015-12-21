<#
.SYNOPSIS
	Invoke-LiveResponse plugin that runs Get-Credential.

.DESCRIPTION
	This plugin runs the Get-Credential cmdlet and returns a Credential object for us in Invoke-LiveResponse.  The existence of this script is here to have the functionality of a replaceable plugin for retreiving credentials that can easily be replaced for interaction with a privileged account manager without requiring code changes to the original Invoke-LiveResponse script.

#>
[OutputType([System.Management.Automation.PSCredential])]
Param (

)

# Just use built in Get-Credential cmdlet.
[System.Management.Automation.PSCredential]$Creds = Get-Credential -Message "Enter credentials to use with Invoke-LiveResponse"

# Return the PSCredential object for use with Invoke-LiveResponse
return $Creds