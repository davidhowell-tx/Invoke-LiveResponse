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

# Usage

## Results Save Path
The default save path is the "\Results" directory in the folder where Invoke-LiveResponse.ps1 is located. If you want to change this path you can do the following:

### Command-Line
Invoke-LiveResponse.ps1 -Config -SavePath "C:\New\SavePath"

### GUI
* Click File > Options
* Put a check in the box next to Save Path
