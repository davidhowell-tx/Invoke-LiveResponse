<#
.SYNOPSIS
    PowerShell based live response via WinRM, and Invoke-Command.

.DESCRIPTION
    This project is an off-shoot of Dave Hull's Kansa project. https://github.com/davehull/Kansa/
	I had some ideas for expanding the project and adding a GUI, so decided to create my own project.

.PARAMETER ComputerName
    Name or IP Address of the target computer(s). Can accept a comma separated list, or a variable containing a string array.

.PARAMETER Module
	Execute the specified Module or Modules against the target system. Can accept a comma separated list, or a variable containing a string array.

.PARAMETER ModuleSet
	Execute the specified ModuleSet against the target system. Module sets are groups of modules that you can configure for different configurations (i.e. IISServerTriage, StandardLR)

.PARAMETER ShowModules
	Provides a list of all available modules, their descriptions, output format, and any binary dependencies.

.PARAMETER ShowModuleSets
	Provides a list of all configured module sets.  Module sets are groups of modules that you can configure for different configurations (i.e. IISServerTriage, StandardLR)

.PARAMETER Config
	If you want to change the default save path use this switch.  New save path is saved in %USERPROFILE%\AppData\Roaming\Invoke-LiveResponse.conf

.PARAMETER SavePath
	If you need to specify a different Save Path other than the default (.\Results).
	Can be used with the -Config switch to save a different save path in a config file.

.PARAMETER ConcurrentJobs
	PowerShell's Runspace pools are used to execute tasks against multiple systems simultaenously. 
	Use ConcurrentJobs switch along with Config switch to change the number of simultaneous jobs.
	Default is 3.

.PARAMETER Credential
	This parameter calls the Invoke-LiveResponseCredentials.ps1 in the .\Plugins directory. By default, this script performs the builtin PowerShell Get-Credential command, which prompts the user for their credentials, but can be replaced with other plugins that interact with Privileged Account Management apis.

.PARAMETER GUI
	This parameter calls the Invoke-LiveResponseGUI.ps1 in the .\Plugins directory so the user can utilize a GUI rather than running at the command line.

.EXAMPLE
	Configure the default save path
	Invoke-LiveResponse -Config -SavePath \\servername\smbshare\LRResults

.EXAMPLE
	Configure the number of concurrent jobs
	Invoke-LiveResponse -Config -ConcurrentJos 5
	
.EXAMPLE
	Show available modules
	Invoke-LiveResponse -ShowModules

.EXAMPLE
	Show the available module sets
	Invoke-LiveResponse -ShowModuleSets

.EXAMPLE
	Run the default module set on target computer
	Invoke-LiveResponse -Target COMPUTERNAME

.EXAMPLE
	Run the MalwareTriage module set on target computer
	Invoke-LiveResponse -Target COMPUTERNAME -ModuleSet MalwareTriage

.EXAMPLE
	Run the Get-Processes and Get-Netstat modules on target computer
	Invoke-LiveResponse -Target COMPUTERNAME -Module Get-Processes, Get-Netstat

.NOTES
    Author: David Howell
    Last Modified: 12/16/2015
    Version: 1.1.0
#>
[CmdletBinding(DefaultParameterSetName="LRModule")]
Param(
	[Parameter(Mandatory=$True,ParameterSetName="LRModule")]
	[Parameter(Mandatory=$True,ParameterSetName="LRModuleSet")]
	[ValidateNotNullOrEmpty()]
	[String[]]
	$ComputerName,
	
	[Parameter(Mandatory=$True,ParameterSetName="ShowModules")]
	[Switch]
	$ShowModules,

	[Parameter(Mandatory=$True,ParameterSetName="ShowModuleSets")]
	[Switch]
	$ShowModuleSets,

	[Parameter(Mandatory=$True,ParameterSetName="Config")]
	[Switch]
	$Config,

	[Parameter(Mandatory=$False,ParameterSetName="Config")]
	[Parameter(Mandatory=$False,ParameterSetName="LRModule")]
	[Parameter(Mandatory=$False,ParameterSetName="LRModuleSet")]
	[String]
	$SavePath,
	
	[Parameter(Mandatory=$true,ParameterSetName="Config")]
	[Int]
	$ConcurrentJobs,
	
	[Parameter(Mandatory=$False,ParameterSetName="LRModule")]
	[Parameter(Mandatory=$False,ParameterSetName="LRModuleSet")]
	[Switch]
	$Credential,
	
	[Parameter(Mandatory=$True,ParameterSetName="GUI")]
	[Switch]
	$GUI
)

# Using Dynamic Parameters for Module and ModuleSet switches
DynamicParam {
	# Determine executing directory
	Try {
		$ScriptDirectory = Split-Path ($MyInvocation.MyCommand.Path) -ErrorAction Stop
	} Catch {
		$ScriptDirectory = (Get-Location).Path
	}
	
	$RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
	
	# Check for ModuleSets.conf. If it exists, import the Module Sets as a possible value for the ModuleSet parameter.
	if (Test-Path -Path "$ScriptDirectory\Modules\ModuleSets.conf") {
		$ModuleSetAttrColl = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
		$ModuleSetParamAttr = New-Object System.Management.Automation.ParameterAttribute
		$ModuleSetParamAttr.Mandatory = $True
		$ModuleSetParamAttr.ParameterSetName = "LRModuleSet"
		$ModuleSetAttrColl.Add($ModuleSetParamAttr)
		[XML]$ModuleSetsXML = Get-Content -Path "$ScriptDirectory\Modules\ModuleSets.conf" -ErrorAction Stop
		$ModuleSetValidateSet = @()
		$ModuleSetsXML.ModuleSets | Get-Member -MemberType Property | Select-Object -ExpandProperty Name | Where-Object { $_ -ne "#comment" } | ForEach-Object {
			$ModuleSetValidateSet += $_
		}
		$ModuleSetValSetAttr = New-Object System.Management.Automation.ValidateSetAttribute($ModuleSetValidateSet)
		$ModuleSetAttrColl.Add($ModuleSetValSetAttr)
		$ModuleSetRuntimeParam = New-Object System.Management.Automation.RuntimeDefinedParameter("ModuleSet", [string], $ModuleSetAttrColl)
		$RuntimeParameterDictionary.Add("ModuleSet", $ModuleSetRuntimeParam)
	}
	
	if (Get-ChildItem -Path "$ScriptDirectory\Modules" -Filter *.ps1) {
		$ModuleAttrColl = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
		$ModuleParamAttr = New-Object System.Management.Automation.ParameterAttribute
		$ModuleParamAttr.Mandatory = $True
		$ModuleParamAttr.ParameterSetName = "LRModule"
		$ModuleAttrColl.Add($ModuleParamAttr)
		$ModuleValidateSet = Get-ChildItem -Path "$ScriptDirectory\Modules" -Filter *.ps1 | Select-Object -ExpandProperty BaseName
		$ModuleValSetAttr = New-Object System.Management.Automation.ValidateSetAttribute($ModuleValidateSet)
		$ModuleAttrColl.Add($ModuleValSetAttr)
		$ModuleRuntimeParam = New-Object System.Management.Automation.RuntimeDefinedParameter("Module", [string], $ModuleAttrColl)
		$RuntimeParameterDictionary.Add("Module", $ModuleRuntimeParam)
	}
	
	if ($RuntimeParameterDictionary) {
		return $RuntimeParameterDictionary
	}
}

Begin {
	# Loop through the PSBoundParameters hashtable and add all variables. This makes it so the dynamic variables are set and we can tab complete with them.
	$PSBoundParameters.GetEnumerator() | ForEach-Object { New-Variable -Name $_.Key -Value $_.Value -ErrorAction SilentlyContinue }
} Process {

	#region Check PowerShell Version
	# Verify we are running on PowerShell version 3 or higher
	Write-Verbose -Message "Checking PowerShell Version.  Version 3 or higher is required."
	if ($PSVersionTable.PSVersion.Major -lt 3) {
		Write-Error -Message "PowerShell version needs to be 3 or higher.  You are using version $($PSVersionTable.PSVersion.ToString()). Exiting script."
		exit
	} else {
		Write-Verbose -Message "PowerShell version $($PSVersionTable.PSVersion.Major) is sufficient, continuing."
	}
	#endregion Check PowerShell Version

	#region Get Executing Directory
	# Determine executing directory
	Write-Verbose -Message "Determining script's executing directory to use in locating modules."
	Try {
		$ScriptDirectory = Split-Path ($MyInvocation.MyCommand.Path) -ErrorAction Stop
	} Catch {
		$ScriptDirectory = (Get-Location).Path
	}
	Write-Verbose -Message "Script's executing directory is $ScriptDirectory."
	$BinaryDirectory = $ScriptDirectory + "\Modules\Binaries\"
	Write-Verbose -Message "Script's binary dependency directory is $BinaryDirectory."
	#endregion Get Executing Directory

	#region Import Configuration Information
	# Check for configuration file. Read contents, if it exists.
	Write-Verbose -Message "Checking for configuration file to import settings."
	if (Test-Path -Path "$Env:APPDATA\Invoke-LiveResponse.conf") {
		[XML]$Config = Get-Content -Path "$Env:APPDATA\Invoke-LiveResponse.conf" -ErrorAction Stop
		Write-Verbose -Message "Configuration file found and imported."
	}

	# If a save path is listed in the configuration file, use it. Otherwise, set to the default.
	if ($Config.Configuration.SavePath) {
		$SaveLocation = $Config.Configuration.SavePath
		Write-Verbose -Message "Save path imported:  $($Config.Configuration.SavePath)"
	} else {
		$SaveLocation = $ScriptDirectory + "\Results\"
	}
	
	# If a concurrent jobs count is listed in the configuration file, use it. Otherwise use the default of 5.
	if ($Config.Configuration.ConcurrentJobs) {
		$RunspaceCount = $Config.Configuration.ConcurrentJobs
	} else {
		$RunspaceCount = 3
	}
	
	# Clean up variables we don't need after configuration import
	Remove-Variable -Name Config
	#endregion Import Configuration Information

	# Array to contain list of "selected modules", which is added based on the switches used and values provided for -Module or -ModuleSet
	$SelectedModules = New-Object System.Collections.ArrayList
	
	#region Parameter Set Name switch
	switch ($PSCmdlet.ParameterSetName) {
		# Config Parameter Set, used to save a non-default Module or Save Path in a XML file to user does not always need to designate their special path
		"Config" {
			# We need to either import the current configuration if it exists, or create a new one
			if (Test-Path -Path "$Env:APPDATA\Invoke-LiveResponse.conf") {
				# Check if configuration file exists. Import if it does
				[XML]$ConfigObject = Get-Content -Path "$Env:APPDATA\Invoke-LiveResponse.conf"
			} else {
				# If configuration file doesn't exist, create it
				$ConfigObject = New-Object System.Xml.XmlDocument
				$ConfigurationElement = $ConfigObject.CreateElement("Configuration")
				$ConfigObject.AppendChild($ConfigurationElement) | Out-Null
			}
			
			# If user provided a save path, either add it to the configuration or update the configuration's previous entry
			if ($SavePath) {
				if ($ConfigObject.Configuration.SavePath) {
					$ConfigObject.Configuration.SavePath = $SavePath
				} else {
					$ConfigurationElement.SetAttribute("SavePath",$SavePath)
				}
				$ConfigObject.Save("$Env:APPDATA\Invoke-LiveResponse.conf")
			}
			
			# If user provided a concurrent jobs amount, either add it ot the configuration or update the configuration's previous entry
			if ($ConcurrentJobs) {
				if ($ConfigObject.Configuration.ConcurrentJobs) {
					$ConfigObject.Configuration.ConcurrentJobs = $ConcurrentJobs
				} else {
					$ConfigurationElement.SetAttribute("ConcurrentJobs",$ConcurrentJobs)
				}
				$ConfigObject.Save("$Env:APPDATA\Invoke-LiveResponse.conf")
			}
			
			# Show the current configuration settings after any updates
			$TempObject = New-Object PSObject
			$TempObject | Add-Member -MemberType NoteProperty -Name "SavePath" -Value ($ConfigObject.Configuration.SavePath)
			$TempObject | Add-Member -MemberType NoteProperty -Name "ConcurrentJobs" -Value ($ConfigObject.Configuration.ConcurrentJobs)
			return $TempObject
		}
		
		# ShowModules Parameter Set, used to display a list of available modules and their Description, Output Type, and Binary Dependencies
		"ShowModules" {
			$Modules = Get-ChildItem -Path "$ScriptDirectory\Modules" -Filter *.ps1 | Select-Object -Property Name, FullName
			$ModuleArray=@()
			$ConfirmPreference = "none"
			$Modules | ForEach-Object {
				$TempObject = New-Object PSObject
				$TempObject | Add-Member -MemberType NoteProperty -Name "Name" -Value $_.Name
				$TempObject | Add-Member -MemberType NoteProperty -Name "FilePath" -Value $_.FullName
				# Parse the Directives from the Modules
				$Directives = Get-Content -Path $_.FullName | Select-String -CaseSensitive -Pattern "^(OUTPUT|BINARY)"
				[String]$OutputType="txt"
	            $BinaryDependency=$False
	            [String]$BinaryName="N/A"
	            ForEach ($Directive in $Directives) {
	                if ($Directive -match "(^OUTPUT) (.*)") {
	                    [String]$OutputType=$matches[2]
	                }
	                if ($Directive -match "(^BINARY) (.*)") {
	                    $BinaryDependency=$True
	                    [String]$BinaryName=$matches[2]
	                }
	            }
	            $TempObject | Add-Member -MemberType NoteProperty -Name "OutputType" -Value $OutputType
	            $TempObject | Add-Member -MemberType NoteProperty -Name "BinaryDependency" -Value $BinaryDependency
	            $TempObject | Add-Member -MemberType NoteProperty -Name "BinaryName" -Value $BinaryName
				$TempObject | Add-Member -MemberType NoteProperty -Name "Description" -Value (Get-Help $_.FullName | Select-Object -ExpandProperty Synopsis)
				$ModuleArray += $TempObject
			}
			
			$ModuleArray | Select-Object -Property Name, Description, OutputType, BinaryDependency, BinaryName
		}
		
		"ShowModuleSets" {
			$ModuleSetArray = @()
			
			# Check for ModuleSets.conf and read contents
			Write-Verbose -Message "Checking for ModuleSets.conf file to import settings."
			if (Test-Path -Path "$ScriptDirectory\Modules\ModuleSets.conf") {
				[XML]$ModuleSetsXML = Get-Content -Path "$ScriptDirectory\Modules\ModuleSets.conf" -ErrorAction Stop
				Write-Verbose -Message "ModuleSets.conf found and imported."
			} else {
				Write-Verbose -Message "ModuleSets.conf not found."
			}
			
			$ModuleSetsXML.ModuleSets | Get-Member -MemberType Property | Select-Object -ExpandProperty Name | Where-Object { $_ -ne "#comment" } | ForEach-Object {
				# For each module set, create a custom object and populate metadata
				$TempObject = New-Object PSObject
				$TempObject | Add-Member -MemberType NoteProperty -Name "Name" -Value $_
				$TempObject | Add-Member -MemberType NoteProperty -Name "Description" -Value $ModuleSetsXML.ModuleSets.$_.Description
				$TempObject | Add-Member -MemberType NoteProperty -Name "Modules" -Value ([String]::Join(', ', $ModuleSetsXML.ModuleSets.$_.Module))
				
				# Add custom object to our array
				$ModuleSetArray += $TempObject
			}
			
			# Show the contents of our array
			$ModuleSetArray | Select-Object -Property Name, Description, Modules
			
		}
		
		# LRModule Parameter Set, used to perform live response with a specific module or modules
		"LRModule" {
			# This section of code only sets the SelectedModules variable.  Execution code is later
			
			# Verify the module exists before adding it to selected modules list
			$Module | ForEach-Object {
				if ($_ -notmatch ".+\.ps1") {
					$_ = $_ + ".ps1"
				}

				if (Test-Path -Path "$ScriptDirectory\Modules\$_") {
					# Gather information about the module that will be needed later during processing
					$TempObject = New-Object PSObject
					$TempObject | Add-Member -MemberType NoteProperty -Name "Name" -Value $_
					$TempObject | Add-Member -MemberType NoteProperty -Name "FilePath" -Value "$ScriptDirectory\Modules\$_"
					# Parse the Directives from the Modules
					$Directives = Get-Content -Path "$ScriptDirectory\Modules\$_" | Select-String -CaseSensitive -Pattern "^(OUTPUT|BINARY)"
					[String]$OutputType="txt"
		            $BinaryDependency=$False
		            [String]$BinaryName="N/A"
		            ForEach ($Directive in $Directives) {
		                if ($Directive -match "(^OUTPUT) (.*)") {
		                    [String]$OutputType=$matches[2]
		                }
		                if ($Directive -match "(^BINARY) (.*)") {
		                    $BinaryDependency=$True
		                    [String]$BinaryName=$matches[2]
		                }
		            }
					$TempObject | Add-Member -MemberType NoteProperty -Name "OutputType" -Value $OutputType
		            $TempObject | Add-Member -MemberType NoteProperty -Name "BinaryDependency" -Value $BinaryDependency
		            $TempObject | Add-Member -MemberType NoteProperty -Name "BinaryName" -Value $BinaryName
					$SelectedModules.Add($TempObject) | Out-Null
				} else {
					Write-Host "Module `"$_`" does not exist"
				}
				
				# Clean up variables we no longer need
				Remove-Variable -Name TempObject
				Remove-Variable -Name Directives
				Remove-Variable -Name BinaryDependency
				Remove-Variable -Name BinaryName
				Remove-Variable -Name OutputType
			}
		}
		
		# LRModuleSet Parameter Set, used to perform live response with a set of modules defined in ModuleSets.conf
		"LRModuleSet" {
			# This section of code only sets the SelectedModules variable.  Execution code is later
			
			# Check for ModuleSets.conf and read contents
			Write-Verbose -Message "Checking for ModuleSets.conf file to import settings."
			if (Test-Path -Path "$ScriptDirectory\Modules\ModuleSets.conf") {
				[XML]$ModuleSetsXML = Get-Content -Path "$ScriptDirectory\Modules\ModuleSets.conf" -ErrorAction Stop
				Write-Verbose -Message "ModuleSets.conf found and imported."
			} else {
				Write-Verbose -Message "ModuleSets.conf not found."
			}
			
			# Verify the existence of the module set provided by the user's input
			Write-Verbose -Message "Checking on the existence of module set `"$ModuleSet`""
			if (($ModuleSetsXML.ModuleSets | Get-Member -MemberType Property | Select-Object -ExpandProperty Name) -contains $ModuleSet) {
				Write-Verbose -Message "Module set does exist"
				$ModuleSetsXML.ModuleSets.$ModuleSet.Module | ForEach-Object {
					# Verify the module exists before adding it to selected modules list
					if (Test-Path -Path "$ScriptDirectory\Modules\$_") {
						# Gather information about the module that will be needed later during processing
						$TempObject = New-Object PSObject
						$TempObject | Add-Member -MemberType NoteProperty -Name "Name" -Value $_
						$TempObject | Add-Member -MemberType NoteProperty -Name "FilePath" -Value "$ScriptDirectory\Modules\$_"
						# Parse the Directives from the Modules
						$Directives = Get-Content -Path "$ScriptDirectory\Modules\$_" | Select-String -CaseSensitive -Pattern "^(OUTPUT|BINARY)"
						[String]$OutputType="txt"
			            $BinaryDependency=$False
			            [String]$BinaryName="N/A"
			            ForEach ($Directive in $Directives) {
			                if ($Directive -match "(^OUTPUT) (.*)") {
			                    [String]$OutputType=$matches[2]
			                }
			                if ($Directive -match "(^BINARY) (.*)") {
			                    $BinaryDependency=$True
			                    [String]$BinaryName=$matches[2]
			                }
			            }
						$TempObject | Add-Member -MemberType NoteProperty -Name "OutputType" -Value $OutputType
			            $TempObject | Add-Member -MemberType NoteProperty -Name "BinaryDependency" -Value $BinaryDependency
			            $TempObject | Add-Member -MemberType NoteProperty -Name "BinaryName" -Value $BinaryName
						$SelectedModules.Add($TempObject) | Out-Null
					}
				}
			} else {
				Write-Error -Message "Module set `"$ModuleSet`" does not exist.  Use -ShowModuleSets switch to view them, or edit the ModuleSets.conf file in the Modules directory."
			}
			
			# Clean up variables we no longer need
			Remove-Variable -Name TempObject
			Remove-Variable -Name Directives
			Remove-Variable -Name BinaryDependency
			Remove-Variable -Name BinaryName
			Remove-Variable -Name OutputType
			Remove-Variable -Name ModuleSetsXML
		}
		
		# GUI Parameter Set, used to launch the Invoke-LiveResponseGUI.ps1 script
		"GUI" {
			& "$ScriptDirectory\Plugins\Invoke-LiveResponseGUI.ps1" -ScriptDirectory $ScriptDirectory
		}
	}
	#endregion Parameter Set Name switch
	
	# Continue to perform live response actions, if we are using a parameter set for live response.
	if ($SelectedModules) {
		Write-Verbose "Continuing to Live Response"
		# If a Save Path was provided, override the path from the Configuration file
		if ($SavePath) {
			$SaveLocation = $SavePath
		}
		
		# If the Credential switch was specified, launch the Invoke-LiveResponseCredentials.ps1 script in the Plugins directory
		if ($Credential) {
			Write-Verbose "Credential switch specified"
			[System.Management.Automation.PSCredential]$Credentials = & "$ScriptDirectory\Plugins\Invoke-LiveResponseCredentials.ps1"
		}
		
		# Create a Synchroznied hashtable to share progress with other runspaces/scripts
		$SynchronizedHashtable = [System.Collections.HashTable]::Synchronized(@{})
		
		# Create a ProgressLogMessage array to store log entries to send to log file
		$SynchronizedHashtable.ProgressLogMessage = New-Object System.Collections.ArrayList
		
		# Create a Progress Bar Message array to store messages for the progress bar
		$SynchronizedHashtable.ProgressBarMessage = New-Object System.Collections.ArrayList
		
		# Create a total count of module jobs to run for a progress bar
		$SynchronizedHashtable.ProgressBarTotal = $ComputerName.Count * $SelectedModules.Count
		$SynchronizedHashtable.ProgressBarCurrent = 0
		
		# Get the execution time and add that to the save path
		$StartTime=Get-Date -Format yyyyMMdd-HHmmss
		$SaveLocation = $SaveLocation + "\$StartTime"
		
		# Create the results directory
		New-Item -Path $SaveLocation -ItemType Directory -Force | Out-Null

		# Set a log path and create a log file
		$LogPath = "$SaveLocation\Logfile.Log"
		New-Item -Path $LogPath -ItemType File -Force | Out-Null
		
		# Initialize log file with some information about the current run execution
		Add-Content -Path $LogPath -Value "$(Get-Date -Format yyyyMMdd-H:mm:ss) Initiating Invoke-LiveResponse"
		Add-Content -Path $LogPath -Value (Get-Date -Format "MMMM dd, yyyy H:mm:ss")
		Add-Content -Path $LogPath -Value "$(Get-Date -Format yyyyMMdd-H:mm:ss) ##############################"
		Add-Content -Path $LogPath -Value "$(Get-Date -Format yyyyMMdd-H:mm:ss) Curent User: $Env:Username"
		Add-Content -Path $LogPath -Value "$(Get-Date -Format yyyyMMdd-H:mm:ss) Current Computer: $env:Computername"
		Add-Content -Path $LogPath -Value "$(Get-Date -Format yyyyMMdd-H:mm:ss) ##############################"
		Add-Content -Path $LogPath -Value "$(Get-Date -Format yyyyMMdd-H:mm:ss) Concurrent Job Count: $RunspaceCount"
		Add-Content -Path $LogPath -Value "$(Get-Date -Format yyyyMMdd-H:mm:ss) Target List: $ComputerName"
		Add-Content -Path $LogPath -Value "$(Get-Date -Format yyyyMMdd-H:mm:ss) Modules Selected:"
		Add-Content -Path $LogPath -Value $SelectedModules.Name
		Add-Content -Path $LogPath -Value "$(Get-Date -Format yyyyMMdd-H:mm:ss) ##############################"
		
		#region Live Response Scriptblock
		# Define a ScriptBlock with Parameters for our Live Response process
		$LiveResponseProcess = {
			[CmdletBinding()]Param(
				[Parameter(Mandatory=$True)]
				[String]
				$Computer,
				
				[Parameter(Mandatory=$True)]
				[String]
				$OutputPath,
				
				[Parameter(Mandatory=$True)]
				[PSObject[]]
				$Modules,
				
				[Parameter(Mandatory=$True)]
				[String]
				$BinaryDirectory,
				
				[Parameter(Mandatory=$True)]
				[System.Collections.HashTable]
				$SynchronizedHashtable,
				
				[Parameter(Mandatory=$False)]
				[System.Management.Automation.PSCredential]
				$Credential
			)
			$SynchronizedHashtable.ProgressLogMessage += "$(Get-Date -Format yyyyMMdd-H:mm:ss) $Computer : Job Processing beginning."
			
			#region Test/Fix WinRM
			# Test PowerShell Remoting, and if it doesn't work try to enable it
			Try {
				if ($Credential) {
					Invoke-Command -ComputerName $Computer -ScriptBlock {1} -Credential $Credential -ErrorAction Stop | Out-Null
				} else {
					Invoke-Command -ComputerName $Computer -ScriptBlock {1} -ErrorAction Stop | Out-Null
				}
				$SynchronizedHashtable.ProgressLogMessage += "$(Get-Date -Format yyyyMMdd-H:mm:ss) $Computer : WinRM seems to be functioning."
			} Catch {
				$SynchronizedHashtable.ProgressLogMessage += "$(Get-Date -Format yyyyMMdd-H:mm:ss) $Computer : WinRM doesn't appear to be functioning. Attempting to fix/enable it."
				# Verify WinRM Service is running. If it isn't, note the state and start the service.
				if ($Credential) {
					if ((Get-WmiObject -ComputerName $Computer -Class Win32_Service -Credential $Credential -Filter "Name='WinRM'").State -ne "Running") {
						(Get-WmiObject -ComputerName $Computer -Class Win32_Service -Credential $Credential -Filter "Name='WinRM'").StartService() | Out-Null
						$ChangedWinRM = $True
					}
				} else {
					if ((Get-WmiObject -ComputerName $Computer -Class Win32_Service -Filter "Name='WinRM'").State -ne "Running") {
						(Get-WmiObject -ComputerName $Computer -Class Win32_Service -Filter "Name='WinRM'").StartService() | Out-Null
						$ChangedWinRM = $True
					}
				}
				if ($ChangedWinRM -eq $True) {
					$SynchronizedHashtable.ProgressLogMessage += "$(Get-Date -Format yyyyMMdd-H:mm:ss) $Computer : WinRM service started."
				}
				
				Try {
					if ($Credential) {
						# Create a Remote Registry handle on the remote machine
						$ConnectionOptions = New-Object System.Management.ConnectionOptions
						$ConnectionOptions.UserName = $Credential.UserName
						$ConnectionOptions.SecurePassword = $Credential.Password
						
						$ManagementScope = New-Object System.Management.ManagementScope -ArgumentList \\$Computer\Root\default, $ConnectionOptions -ErrorAction Stop
						$ManagementPath = New-Object System.Management.ManagementPath -ArgumentList "StdRegProv"
						
						$Reg = New-Object System.Management.ManagementClass -ArgumentList $ManagementScope, $ManagementPath, $null
					} else {
						$Reg = New-Object -TypeName System.Management.ManagementClass -ArgumentList \\$Computer\Root\default:StdRegProv -ErrorAction Stop
					}
					
					# Value used to connect to remote HKLM registry hive
					$HKLM = 2147483650
					
					# Verify the Registry Directory Structure exists, and if not try to create it
					if ($Reg.EnumValues($HKLM,"SOFTWARE\Policies\Microsoft\Windows\WinRM").ReturnValue -ne 0) {
						$Reg.CreateKey($HKLM, "SOFTWARE\Policies\Microsoft\Windows\WinRM") | Out-Null
					}
					if ($Reg.EnumValues($HKLM,"SOFTWARE\Policies\Microsoft\Windows\WinRM\Service").ReturnValue -ne 0) {
						$Reg.CreateKey($HKLM,"SOFTWARE\Policies\Microsoft\Windows\WinRM\Service") | Out-Null
					}
					# Verify the AllowAutoConfig registry value is 1, or set it to 1
					$AutoConfigValue=$Reg.GetDWORDValue($HKLM,"SOFTWARE\Policies\Microsoft\Windows\WinRM\Service","AllowAutoConfig")
					if ($AutoConfigValue.ReturnValue -ne 0 -and $AutoConfigValue.uValue -ne 1) {
						$Reg.SetDWORDValue($HKLM,"SOFTWARE\Policies\Microsoft\Windows\WinRM\Service","AllowAutoConfig","0x1") | Out-Null
						$ChangedAutoConfig = $AutoConfigValue
						$SynchronizedHashtable.ProgressLogMessage += "$(Get-Date -Format yyyyMMdd-H:mm:ss) $Computer : Changed AllowAutoConfig registry key to 1."
					}
					# Verify the IPv4Filter registry value is *, or set it to *
					$IPV4Value=$Reg.GetStringValue($HKLM,"SOFTWARE\Policies\Microsoft\Windows\WinRM\Service","IPv4Filter")
					if ($IPV4Value.ReturnValue -ne 0 -and $IPV4Value.sValue -ne "*") {
						$Reg.SetStringValue($HKLM,"SOFTWARE\Policies\Microsoft\Windows\WinRM\Service","IPv4Filter","*") | Out-Null
						$ChangedIPV4Value = $IPV4Value
						$SynchronizedHashtable.ProgressLogMessage += "$(Get-Date -Format yyyyMMdd-H:mm:ss) $Computer : Changed IPV4Filter registry key to *"
					}
					# Verify the IPv6Filter registry value is *, or set it to *
					$IPV6Value=$Reg.GetStringValue($HKLM,"SOFTWARE\Policies\Microsoft\Windows\WinRM\Service","IPv6Filter")
					if ($IPV6Value.ReturnValue -ne 0 -and $IPV6Value.sValue -ne "*") {
						$Reg.SetStringValue($HKLM,"SOFTWARE\Policies\Microsoft\Windows\WinRM\Service","IPv6Filter","*") | Out-Null
						$ChangedIPV6Value = $IPV6Value
						$SynchronizedHashtable.ProgressLogMessage += "$(Get-Date -Format yyyyMMdd-H:mm:ss) $Computer : Changed IPV6Filter registry key to *"
					}
					
					# Now restart the WinRM service
					if ($Credential) {
						(Get-WmiObject -ComputerName $Computer -Class Win32_Service -Credential $Credential -Filter "Name='WinRM'").StopService() | Out-Null
						(Get-WmiObject -ComputerName $Computer -Class Win32_Service -Credential $Credential -Filter "Name='WinRM'").StartService() | Out-Null
					} else {
						(Get-WmiObject -ComputerName $Computer -Class Win32_Service -Filter "Name='WinRM'").StopService() | Out-Null
						(Get-WmiObject -ComputerName $Computer -Class Win32_Service -Filter "Name='WinRM'").StartService() | Out-Null
					}
				} Catch {
				}
			}
			#endregion Test/Fix WinRM
			
			#region Execute Modules
			ForEach ($Module in $Modules) {
				$SynchronizedHashtable.ProgressBarMessage += "Executing $($Module.Name) on $Computer"
				# Execute the module on the computer through WinRM and Invoke-Command
				$SynchronizedHashtable.ProgressLogMessage += "$(Get-Date -Format yyyyMMdd-H:mm:ss) $Computer : Executing module $($Module.Name)"
				if ($Credential) {
					$JobResults = Invoke-Command -ComputerName $Computer -FilePath $Module.FilePath -Credential $Credential -ErrorAction SilentlyContinue
				} else {
					$JobResults = Invoke-Command -ComputerName $Computer -FilePath $Module.FilePath -ErrorAction SilentlyContinue
				}
				
				$SynchronizedHashtable.ProgressLogMessage += "$(Get-Date -Format yyyyMMdd-H:mm:ss) $Computer : Job $($Module.Name) completed."
				if ($JobResults) {
						switch ($Module.OutputType) {
							"txt" {
								Set-Content -Path "$OutputPath\$Computer-$($Module.Name).$($Module.OutputType)" -Value $JobResults -Force | Out-Null
							}
							"csv" {
								$JobResults | Select-Object -Property * -ExcludeProperty PSComputerName, RunspaceId | Export-Csv -Path "$OutputPath\$Computer-$($Module.Name).$($Module.OutputType)" -NoTypeInformation -Force | Out-Null
							}
							"tsv" { Out-File -FilePath
								$JobResults | ConvertTo-Csv -Delimiter "`t" -NoTypeInformation | Set-Content -Path "$OutputPath\$Computer-$($Module.Name).$($Module.OutputType)" -Force | Out-Null
							}
							"xml" {
								[System.Xml.XmlDocument]$Temp = $JobResults
								$Temp.Save("$OutputPath\$Computer-$($Module.Name).$($Module.OutputType)")
								Remove-Variable -Name "Temp"
							}
							"bin" {
								Set-Content -Path "$OutputPath\$Computer-$($Module.Name).$($Module.OutputType)" -Value $JobResults -Force | Out-Null
							}
							"zip" {
								Set-Content -Path "$OutputPath\$Computer-$($Module.Name).$($Module.OutputType)" -Value $JobResults -Force | Out-Null
							}
							default {
								Set-Content -Path "$OutputPath\$Computer-$($Module.Name).$($Module.OutputType)" -Value $JobResults -Force | Out-Null
							}
						}
					} else {
						$SynchronizedHashtable.ProgressLogMessage += "$(Get-Date -Format yyyyMMdd-H:mm:ss) $Computer : No results were returned from $($Module.Name)."
					}
				
				# Clean Up the Job Results variable
				Remove-Variable -Name JobResults
				$SynchronizedHashtable.ProgressBarCurrent++
			}
			$SynchronizedHashtable.ProgressBarMessage += "Processing complete for $Computer"
			#endregion Execute Modules
			
			#region Clean up changes
			# If WinRM  wasn't running before, lets stop it
			if ($ChangedWinRM -ne $null) {
				if ($Credential) {
					(Get-WmiObject -ComputerName $Computer -Class Win32_Service -Credential $Credential -Filter "Name='WinRM'").StopService() | Out-Null
				} else {
					(Get-WmiObject -ComputerName $Computer -Class Win32_Service -Filter "Name='WinRM'").StopService() | Out-Null
				}
				$SynchronizedHashtable.ProgressLogMessage += "$(Get-Date -Format yyyyMMdd-H:mm:ss) $Computer : Stopped WinRM service."
			}
			
			# Set registry settings back to their original state
			if ($ChangedAutoConfig -ne $null) {
				if ($ChangedAutoConfig.uValue -eq $null) {
					$Reg.DeleteValue($HKLM,"SOFTWARE\Policies\Microsoft\Windows\WinRM\Service","AllowAutoConfig")
				} else {
					$Reg.SetDWORDValue($HKLM,"SOFTWARE\Policies\Microsoft\Windows\WinRM\Service","AllowAutoConfig",$ChangedAutoConfig)
				}
				$SynchronizedHashtable.ProgressLogMessage += "$(Get-Date -Format yyyyMMdd-H:mm:ss) $Computer : AllowAutoConfig registry key changed back to original setting."
			}
			
			if ($ChangedIPV4Value -ne $null) {
				if ($ChangedIPV4Value.uValue -eq $null) {
					$Reg.DeleteValue($HKLM,"SOFTWARE\Policies\Microsoft\Windows\WinRM\Service","IPv4Filter")
				} else {
					$Reg.SetStringValue($HKLM,"SOFTWARE\Policies\Microsoft\Windows\WinRM\Service","IPv4Filter",$ChangedIPV4Value)
				}
				$SynchronizedHashtable.ProgressLogMessage += "$(Get-Date -Format yyyyMMdd-H:mm:ss) $Computer : IPV4Filter registry key changed back to original setting."
			}
			
			if ($ChangedIPV6Value -ne $null) {
				if ($ChangedIPV6Value.uValue -eq $null) {
					$Reg.DeleteValue($HKLM,"SOFTWARE\Policies\Microsoft\Windows\WinRM\Service","IPv6Filter")
				} else {
					$Reg.SetStringValue($HKLM,"SOFTWARE\Policies\Microsoft\Windows\WinRM\Service","IPv6Filter",$ChangedIPV6Value)
				}
				$SynchronizedHashtable.ProgressLogMessage += "$(Get-Date -Format yyyyMMdd-H:mm:ss) $Computer : IPV6Filter registry key changed back to original setting."
			}
			#endregion Clean up changes
			
			# Set Job Status to Complete
			$SynchronizedHashtable."JobStatus-$($Computer)" = "Complete"
		}
		#endregion Live Response Scriptblock
		
		#region Create Runspace Pool and Runspaces
		# Create a Runspace pool with Single-Threaded apartments
		$RunspacePool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1,$RunspaceCount)
		$RunspacePool.ApartmentState = "STA"
		$RunspacePool.Open()
		$SynchronizedHashtable.ProgressLogMessage += "$(Get-Date -Format yyyyMMdd-H:mm:ss) Runspace Pool created with a max of $RunspaceCount runspaces."
		
		# Create an Array to store our Runspace Jobs
		$RunspaceJobArray = @()
		
		# Create PowerShell processes for each computer and add to our runspace pool
		ForEach ($Computer in $ComputerName) {
			$SynchronizedHashtable."JobStatus-$($Computer)" = "InProgress"
			$SynchronizedHashtable.ProgressBarMessage += "Creating a job in queue for $Computer"
			Write-Verbose "Creating a job in queue for $Computer"
			$RunspaceJob = [System.Management.Automation.PowerShell]::Create()
			$RunspaceJob.AddScript($LiveResponseProcess) | Out-Null
			$RunspaceJob.AddParameter("Computer", $Computer) | Out-Null
			$RunspaceJob.AddParameter("OutputPath", $SaveLocation) | Out-Null
			$RunspaceJob.AddParameter("Modules", $SelectedModules) | Out-Null
			$RunspaceJob.AddParameter("BinaryDirectory", $BinaryDirectory) | Out-Null
			$RunspaceJob.AddParameter("SynchronizedHashtable",$SynchronizedHashtable) | Out-Null
			if ($Credential) {
				$RunspaceJob.AddParameter("Credential", $Credentials) | Out-Null
			}
			$RunspaceJob.RunspacePool = $RunspacePool
			
			# Add the job to our Job Array
			$RunspaceJobArray += New-Object PSObject -Property @{ Pipe = $RunspaceJob; Result = $RunspaceJob.BeginInvoke() }
			$SynchronizedHashtable.ProgressLogMessage += "$(Get-Date -Format yyyyMMdd-H:mm:ss) $Computer : PowerShell process created for $Computer in Runspace pool."
		}
		#endregion Create Runspace Pool and Runspaces
		
		# Use LoggingCounter to maintain location in the progress messages to write entries to the log file
		[int]$LoggingCounter = 0
		
		# While loop to continue checking job status and write log entries to the log file
		while ($RunspaceJobArray.Result.IsCompleted -contains $False -and ($SynchronizedHashtable.Keys -like "JobStatus*" | ForEach-Object { $SynchronizedHashtable.$_ }) -Contains "InProgress") {
			# Create Progress Bar if not in GUI mode
			if (-not($GUI)) {
				Write-Progress -Activity "Performing Live Response" -Status $SynchronizedHashtable.ProgressBarMessage[$SynchronizedHashtable.ProgressBarMessage.Count - 1] -PercentComplete ($SynchronizedHashtable.ProgressBarCurrent / $SynchronizedHashtable.ProgressBarTotal * 100)
			}
			Start-Sleep -Seconds 1
		}
		
		# Write progress log messages to our log file
		while ($LoggingCounter -lt $SynchronizedHashtable.ProgressLogMessage.Count) {
			Add-Content -Path $LogPath -Value $SynchronizedHashtable.ProgressLogMessage[$LoggingCounter]
			$LoggingCounter++
			# Create Progress Bar if not in GUI mode
			if (-not($GUI)) {
				Write-Progress -Activity "Performing Live Response" -Status $SynchronizedHashtable.ProgressBarMessage[$SynchronizedHashtable.ProgressBarMessage.Count - 1] -PercentComplete ($SynchronizedHashtable.ProgressBarCurrent / $SynchronizedHashtable.ProgressBarTotal * 100)
			}
		}
		
		Add-Content -Path $LogPath -Value "$(Get-Date -Format yyyyMMdd-H:mm:ss) ##############################"
		$RunspacePool.Dispose()
		$RunspacePool.Close()
		
		Invoke-Item -Path $SaveLocation
	}
}