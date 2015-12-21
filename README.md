# Invoke-LiveResponse
Another modular incident response framework utilizing PowerShell and WinRM
Original idea came from Dave Hull's Kansa project:  https://github.com/davehull/Kansa

# Goals
* Provide a GUI for people that dislike command-lines
* Provide a command-line for people that dislike GUIs
* Ability for anyone to create modules to extend the toolset
* Ability to create logical groups of modules
* Ability to run remotely through PowerShell remoting
* Ability to run against a large number of target systems for stacking

# Switches
* -ComputerName
  * Type: String Array
  * Description: Use this switch to specify the target computer or computers you wish to perform live response on.
* -Module
  * Type: String Array
  * Description: Use this switch to specify a module, or multiple modules you wish to execute against the target computer(s).
  * Notes: Can write the name with or without the .ps1 extension.
* -ModuleSet
  * Type: String
  * Description: Use this switch to specify a group of modules you wish to execute against the target computer(s).
* -ShowModules
  * Type: Switch
  * Description: Returns a list of available modules along with some metadata, such as if they have a binary dependency (meaning they require an additional executable to be copied to the target computer(s)).
* -ShowModuleSets
  * Type: Switch
  * Description: Returns a list of available module sets, and the modules within them. Module sets are groups of modules, which are defined in the ModuleSets.conf file within the modules directory.
* -Config
  * Type: Switch
  * Description: Use this switch to either display the current saved configurations, or to change the configurations. Current configurations include -SavePath and -ConcurrentJobs.
* -SavePath
  * Type: String
  * Description: Use this switch with the Config switch to set a persistent save path, or use it when executing modules for a one-off save path.
  * Default Value: .\Results
* -ConcurrentJobs
  * Type: Integer
  * Description: Use this switch with the Config switch to set a persistent number of concurrent jobs, or use it when executing modules for a one-off amount of concurrent jobs.
  * Default Value: 3
* -Credential
  * Type: Switch
  * Description: This switch launches the .\Plugins\Invoke-LiveResponseCredentials.ps1 plugin to attain alternate credentials. This is so you can replace the plugin with a script to retrieve credentials from a privileged account manager if necessary.
* -GUI
  * Type: Switch
  * Description: This switch launches the Invoke-LiveResponseGUI.ps1 plugin for those that don't like command-line and prefer a GUI instead.

# Examples
* Invoke-LiveResponse -Config -SavePath \\servername\smbshare\LRResults
  * Configure the default save path
* Invoke-LiveResponse -Config -ConcurrentJos 5
  * Configure the number of concurrent jobs	
* Invoke-LiveResponse -ShowModules
  * Show available modules
* Invoke-LiveResponse -ShowModuleSets
  * Show the available module sets
* Invoke-LiveResponse -ComputerName Target1, Target2
  * Run the default module set on target computer
* Invoke-LiveResponse -ComputerName Target1, Target2 -ModuleSet MalwareTriage
  * Run the MalwareTriage module set on target computer
* Invoke-LiveResponse -ComputerName Target1, Target2 -Module Get-Processes, Get-Netstat
  * Run the Get-Processes and Get-Netstat modules on target computer
* Invoke-LiveResponse -ComputerName Target1, Target2 -Module Get-Processes.ps1, Get-Netstat -SavePath D:\Results -ConcurrentJobs 2
  * Run Get-Processes and Get-Netstat modules against Target1 and Target2, running both jobs concurrently and saving the results to D:\Results.

# Usage

## Change the Default Save Path
The default save path is the .\Results directory where the script is located. Here is how you change this:

### Command-Line
Invoke-LiveResponse.ps1 -Config -SavePath "C:\New\SavePath"

### GUI
* Click File > Options
* Put a check in the box next to Save Path
* Click the Browse Button next to the next box to browse to your new save path, or just type in the save path.
