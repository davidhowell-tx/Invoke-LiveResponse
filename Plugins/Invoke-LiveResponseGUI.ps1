

[CmdletBinding()]Param(
	[Parameter(Mandatory=$False)]
		[String]
		$ScriptDirectory
)
# If user didn't supply the Script Path, determine the script path
if (-not ($ScriptDirectory)) {
	Try {
		$ScriptDirectory = Split-Path ($MyInvocation.MyCommand.Path) -ErrorAction Stop
	} Catch {
		$ScriptDirectory = (Get-Location).Path
	}
	
	# Remove the \Plugins from the current path
	if ($ScriptDirectory -match "([A-Z]:\\)([^\\]+\\)+Plugins$") {
		$ScriptDirectory = $ScriptDirectory -split "\\Plugins"
		$ScriptDirectory = $ScriptDirectory.Trim()
	}
}
# Add .NET Forms class to be used in creating the GUI
Add-Type -AssemblyName System.Windows.Forms

# Add Drawing class for Fonts and Images/Icons
Add-Type -AssemblyName System.Drawing

# Create a font object to replicate the font used during creation of the form
$Font = New-Object System.Drawing.Font -ArgumentList "Microsoft Sans Serif", 8.25

#region Create Form for Options Menu
function OptionsMenu {
	[CmdletBinding()]Param(
		[Parameter(Mandatory=$True)][String]$ScriptDirectory,
		[Parameter(Mandatory=$True)][System.Drawing.Font]$Font
	)
	# Options Form
	$OptionsForm = New-Object System.Windows.Forms.Form
	$OptionsForm.FormBorderStyle = "FixedDialog"
	$OptionsForm.Size = "310,170"
	$OptionsForm.Text = "Invoke-LiveResponse Options"
	$OptionsForm.Font = $Font
	$OptionsForm.MaximizeBox = $False
	$OptionsForm.StartPosition = "CenterScreen"
	
	# Save Path Checkbox
	$OptionsFormCheckboxSavePath = New-Object System.Windows.Forms.CheckBox
	$OptionsFormCheckboxSavePath.Size = "100,23"
	$OptionsFormCheckboxSavePath.Location = "5,5"
	$OptionsFormCheckboxSavePath.Text = "Save Path:"
	$OptionsForm.Controls.Add($OptionsFormCheckboxSavePath)
	$OptionsFormCheckboxSavePath.add_CheckStateChanged({
		if ($OptionsFormCheckboxSavePath.Checked -eq $True) {
			$OptionsFormTextboxSavePath.Enabled=$True
		} else {
			$OptionsFormTextboxSavePath.Enabled = $False
		}
	})
	
	# Save Path Textbox
	$OptionsFormTextboxSavePath = New-Object System.Windows.Forms.TextBox
	$OptionsFormTextboxSavePath.Size = "200,23"
	$OptionsFormTextboxSavePath.Location = "5,28"
	$OptionsFormTextboxSavePath.Enabled = $False
	$OptionsForm.Controls.Add($OptionsFormTextboxSavePath)
	$OptionsFormFolderBrowserDialogSavePath = New-Object System.Windows.Forms.FolderBrowserDialog
	
	# Save Path Browse Button
	$OptionsFormButtonBrowseSavePath = New-Object System.Windows.Forms.Button
	$OptionsFormButtonBrowseSavePath.Size = "75,23"
	$OptionsFormButtonBrowseSavePath.Location = "210,25"
	$OptionsFormButtonBrowseSavePath.Text = "Browse.."
	$OptionsFormButtonBrowseSavePath.Add_Click({
		if ($OptionsFormFolderBrowserDialogSavePath.ShowDialog() -ne "Cancel") {
			$OptionsFormTextboxSavePath.Text = $OptionsFormFolderBrowserDialogSavePath.SelectedPath
		}
	})
	$OptionsForm.Controls.Add($OptionsFormButtonBrowseSavePath)

	# Concurrent Jobs Checkbox
	$OptionsFormCheckboxConcurrentJobs = New-Object System.Windows.Forms.CheckBox
	$OptionsFormCheckboxConcurrentJobs.Size = "120,23"
	$OptionsFormCheckboxConcurrentJobs.Location = "5,60"
	$OptionsFormCheckboxConcurrentJobs.Text = "Concurrent Jobs:"
	$OptionsForm.Controls.Add($OptionsFormCheckboxConcurrentJobs)
	$OptionsFormCheckboxConcurrentJobs.add_CheckStateChanged({
		if ($OptionsFormCheckboxConcurrentJobs.Checked -eq $True) {
			$OptionsFormNumericUpDownConcurrentJobs.Enabled=$True
		} else {
			$OptionsFormNumericUpDownConcurrentJobs.Enabled = $False
		}
	})
	
	# Concurrent Jobs NumericUpDown
	$OptionsFormNumericUpDownConcurrentJobs = New-Object System.Windows.Forms.NumericUpDown
	$OptionsFormNumericUpDownConcurrentJobs.Size = "50,23"
	$OptionsFormNumericUpDownConcurrentJobs.Location = "130,60"
	$OptionsFormNumericUpDownConcurrentJobs.Text = "3"
	$OptionsFormNumericUpDownConcurrentJobs.Enabled = $False
	$OptionsFormNumericUpDownConcurrentJobs.Maximum = 10
	$OptionsForm.Controls.Add($OptionsFormNumericUpDownConcurrentJobs)

	# Save Button
	$OptionsFormButtonSave = New-Object System.Windows.Forms.Button
	$OptionsFormButtonSave.Size = "75,23"
	$OptionsFormButtonSave.Location = "5,100"
	$OptionsFormButtonSave.Text = "Save"
	$OptionsFormButtonSave.add_Click({
		if ($OptionsFormCheckboxSavePath.Checked -eq $True) {
			& "$ScriptDirectory\Invoke-LiveResponse.ps1" -Config -SavePath $OptionsFormTextboxSavePath.Text
		} else {
			& "$ScriptDirectory\Invoke-LiveResponse.ps1" -Config -SavePath ""
		}
		if ($OptionsFormCheckboxConcurrentJobs.Checked -eq $True) {
			& "$ScriptDirectory\Invoke-LiveResponse.ps1" -Config -ConcurrentJobs $OptionsFormNumericUpDownConcurrentJobs.Text
		} else {
			& "$ScriptDirectory\Invoke-LiveResponse.ps1" -Config -ConcurrentJobs ""
		}
		$OptionsForm.Close()
		$OptionsForm.Dispose()
	})
	$OptionsForm.Controls.Add($OptionsFormButtonSave)
	
	# Cancel Button
	$OptionsFormButtonCancel = New-Object System.Windows.Forms.Button
	$OptionsFormButtonCancel.Size = "75,23"
	$OptionsFormButtonCancel.Location = "90,100"
	$OptionsFormButtonCancel.Text = "Cancel"
	$OptionsForm.CancelButton = $OptionsFormButtonCancel
	$OptionsForm.Controls.Add($OptionsFormButtonCancel)
	
	# Check if a Save Path is already configured
	$Configuration = & "$ScriptDirectory\Invoke-LiveResponse.ps1" -Config
	if ($Configuration.SavePath -ne $null -and $Configuration.SavePath -ne "") {
		$OptionsFormTextboxSavePath.Text = $Configuration.SavePath
		$OptionsFormCheckboxSavePath.Checked = $True
	}
	
	# Show Options Form
	$OptionsForm.ShowDialog() | Out-Null
}
#endregion Create Form for Options Menu

#region Create Form for About Menu
function AboutMenu {
	[CmdletBinding()]Param(
		[Parameter(Mandatory=$True)][System.Drawing.Font]$Font
	)
	# About Form
	$AboutForm = New-Object System.Windows.Forms.Form
	$AboutForm.FormBorderStyle="FixedDialog"
	$AboutForm.Size = "310,150"
	$AboutForm.Text = "About Invoke-LiveResponse"
	$AboutForm.Font = $Font
	$AboutForm.MaximizeBox = $False
	$AboutForm.StartPosition = "CenterScreen"
	
	# Picturebox for the PowerShell icon
	$AboutFormImage = New-Object System.Windows.Forms.PictureBox
	$AboutFormImage.Image = ([Drawing.Icon]::ExtractAssociatedIcon((Get-Command powershell).Path)).ToBitmap()
	$AboutFormImage.Location = "5,5"
	$AboutFormImage.Size = "32,32"
	$AboutForm.Controls.Add($AboutFormImage)
	
	# Invoke-LiveResponse Label
	$AboutFormLabelName = New-Object System.Windows.Forms.Label
	$AboutFormLabelName.Location = "45,15"
	$AboutFormLabelName.Size = "200,15"
	$AboutFormLabelName.Text = "Invoke-LiveResponse"
	$AboutForm.Controls.Add($AboutFormLabelName)
	
	# Version Label
	$AboutFormLabelVersion = New-Object System.Windows.Forms.Label
	$AboutFormLabelVersion.Location = "45,35"
	$AboutFormLabelVersion.Size = "200,15"
	$AboutFormLabelVersion.Text = "Version: 1.1"
	$AboutForm.Controls.Add($AboutFormLabelVersion)
	
	# Link Label for Github
	$AboutFormLinkLabelGithub = New-Object System.Windows.Forms.LinkLabel
	$AboutFormLinkLabelGithub.Location = "5,95"
	$AboutFormLinkLabelGithub.Size = "200,15"
	$AboutFormLinkLabelGithub.Text = "https://github.com/davidhowell-tx"
	$AboutFormLinkLabelGithub.LinkColor = "BLUE"
	$AboutFormLinkLabelGithub.ActiveLinkColor = "RED"
	$AboutFormLinkLabelGithub.Add_Click({
		[System.Diagnostics.Process]::Start("https://github.com/davidhowell-tx")
	})
	$AboutForm.Controls.Add($AboutFormLinkLabelGithub)
	
	# OK Button
	$AboutFormButtonOK = New-Object System.Windows.Forms.Button
	$AboutFormButtonOK.Location = "205,85"
	$AboutFormButtonOK.Size = "60,23"
	$AboutFormButtonOK.Text = "OK"
	$AboutForm.Controls.Add($AboutFormButtonOK)
	$AboutForm.CancelButton = $AboutFormButtonOK
	
	# Show About Form
	$AboutForm.ShowDialog() | Out-Null
}
#endregion Create Form for About Menu

#region Create Form for Main Menu
# Main Form
$MainForm = New-Object System.Windows.Forms.Form
$MainForm.FormBorderStyle="FixedDialog"
$MainForm.Size="497,370"
$MainForm.Text="Invoke-LiveResponse"
$MainForm.Font = $Font
$MainForm.MaximizeBox=$False
$MainForm.StartPosition="CenterScreen"

# Menu Strip for Drop Downs
$MainFormMenuStrip = New-Object System.Windows.Forms.MenuStrip
$MainFormMenuStrip.Location = "0,0"
$MainFormMenuStrip.Size = "200,20"

# File Menu Item
$MainFormMenuItemFile = New-Object System.Windows.Forms.ToolStripMenuItem
$MainFormMenuItemFile.Text = "File"
$MainFormMenuItemFile.ShortcutKeys = "Alt,F"
$MainFormMenuStrip.Items.Add($MainFormMenuItemFile) | Out-Null

# Options Menu Item
$MainFormMenuItemOptions = New-Object System.Windows.Forms.ToolStripMenuItem
$MainFormMenuItemOptions.Text = "Options"
$MainFormMenuItemOptions.Add_Click({
	OptionsMenu -ScriptDirectory $ScriptDirectory -Font $Font
})
$MainFormMenuItemFile.DropDownItems.Add($MainFormMenuItemOptions) | Out-Null

# Exit Menu Item
$MainFormMenuItemExit = New-Object System.Windows.Forms.ToolStripMenuItem
$MainFormMenuItemExit.Text = "Exit"
$MainFormMenuItemFile.DropDownItems.Add($MainFormMenuItemExit) | Out-Null
$MainFormMenuItemExit.Add_Click({
	$MainForm.Close()
	$MainForm.Dispose()
})

# Help Menu Item
$MainFormMenuItemHelp = New-Object System.Windows.Forms.ToolStripMenuItem
$MainFormMenuItemHelp.Text = "Help"
$MainFormMenuStrip.Items.Add($MainFormMenuItemHelp) | Out-Null

# About Menu Item
$MainFormMenuItemAbout = New-Object System.Windows.Forms.ToolStripMenuItem
$MainFormMenuItemAbout.Text = "About"
$MainFormMenuItemAbout.Add_Click({
	AboutMenu -Font $Font
})
$MainFormMenuItemHelp.DropDownItems.Add($MainFormMenuItemAbout) | Out-Null
$MainForm.Controls.Add($MainFormMenuStrip)

# "Modules" Label
$MainFormLabelModules = New-Object System.Windows.Forms.Label
$MainFormLabelModules.Text="Modules:"
$MainFormLabelModules.Location="5,25"
$MainFormLabelModules.Size="50,15"
$MainForm.Controls.Add($MainFormLabelModules)

# "Targets" Label
$MainFormLabelTargets = New-Object System.Windows.Forms.Label
$MainFormLabelTargets.Text="Targets:"
$MainFormLabelTargets.Location="258,25"
$MainFormLabelTargets.Size="52,15"
$MainForm.Controls.Add($MainFormLabelTargets)

# Modules Listbox
$MainFormListboxModules = New-Object System.Windows.Forms.CheckedListBox
$MainFormListboxModules.Location="12,45"
$MainFormListboxModules.Size="212,199"
$MainFormListboxModules.ScrollAlwaysVisible=$True
$MainFormListboxModules.CheckOnClick=$True
$MainFormListboxModules.Sorted=$True
$MainForm.Controls.Add($MainFormListboxModules)

# Right-Click Menu for Modules Listbox
$MainFormContextMenuModuleInfo = New-Object System.Windows.Forms.ContextMenuStrip
$MainFormMenuItemModuleInfo = New-Object System.Windows.Forms.ToolStripMenuItem
$MainFormMenuItemModuleInfo.Text = "More Inf"
$MainFormMenuItemModuleInfo.Add_Click({
	# Look up the Description for the Selected Module	
	ForEach ($Module in $ModuleList) {
		if ($Module.Name -eq $MainFormListboxModules.Items[$MainFormListboxModules.SelectedIndex]) {
			$ModuleDescription = @()
			$ModuleDescription += "Name: " + $Module.Name + "`n"
			$ModuleDescription += "Description: " + $Module.Description + "`n"
			$ModuleDescription += "Output Type: " + $Module.OutputType + "`n"
			$ModuleDescription += "Binary Dependency: " + $Module.BinaryDependency + "`n"
			$ModuleDescription += "Binary Path: " + $Module.BinaryPath + "`n"
			[System.Windows.Forms.MessageBox]::Show($ModuleDescription)
		}
	}
})
$MainFormContextMenuModuleInfo.Items.Add($MainFormMenuItemModuleInfo) | Out-Null
$MainFormListboxModules.ContextMenuStrip=$MainFormContextMenuModuleInfo

# "Module Set" Label
$MainFormLabelModuleset = New-Object System.Windows.Forms.Label
$MainFormLabelModuleset.Text = "Module Set:"
$MainFormLabelModuleset.Location = "5,250"
$MainFormLabelModuleset.Size = "70,15"
$MainForm.Controls.Add($MainFormLabelModuleset)

# Drop Down List to pick Module Set
$MainFormComboboxModuleSets = New-Object System.Windows.Forms.Combobox
$MainFormComboboxModuleSets.Location = "10,265"
$MainFormComboboxModuleSets.Size = "212,21"
$MainFormComboboxModuleSets.Add_SelectedIndexChanged({
	# First, uncheck all modules
	for ($i=0; $i -lt $MainFormListboxModules.Items.Count; $i++) {
		$MainFormListboxModules.SetItemChecked($i, $False)
	}
	
	# Now select all of the modules included in the selected module set
	if ($MainFormComboboxModuleSets.SelectedItem -ne $null -and $MainFormComboboxModuleSets -ne "") {
		ForEach ($ModuleSet in $ModuleSetList) {
			if ($ModuleSet.Name -eq $MainFormComboboxModuleSets.SelectedItem) {
				$Modules = $ModuleSet.Modules -split ", "
				ForEach ($Module in $Modules) {
					for ($i=0; $i -lt $MainFormListboxModules.Items.Count; $i++) {
						if ($MainFormListboxModules.Items[$i] -eq $Module) { 
							$MainFormListboxModules.SetItemChecked($i, $True)
						}
					}
				}
			}
		}
	}
})
$MainForm.Controls.Add($MainFormComboboxModuleSets)

# Targets Listbox
$MainFormListboxTargets = New-Object System.Windows.Forms.ListBox
$MainFormListboxTargets.Location="258,45"
$MainFormListboxTargets.Size="219,147"
$MainFormListboxTargets.ScrollAlwaysVisible=$True
$MainForm.Controls.Add($MainFormListboxTargets)

# Button to Add a new target to targets listbox

$MainFormButtonAddTarget = New-Object System.Windows.Forms.Button
$MainFormButtonAddTarget.Text="Add"
$MainFormButtonAddTarget.Location="298,195"
$MainFormButtonAddTarget.Size="55,23"
$MainFormButtonAddTarget.Add_Click({
	if ($MainFormTextboxAddTarget.Text -ne $null -and $MainFormTextboxAddTarget.Text -ne "") {
		$MainFormListboxTargets.Items.Add($MainFormTextboxAddTarget.Text)
		$MainFormTextboxAddTarget.Text=""
	}
})
$MainForm.Controls.Add($MainFormButtonAddTarget)

# Button to Remove a target from targets listbox
$MainFormButtonRemoveTarget = New-Object System.Windows.Forms.Button
$MainFormButtonRemoveTarget.Text="Remove"
$MainFormButtonRemoveTarget.Location="385,195"
$MainFormButtonRemoveTarget.Size="55,23"
$MainFormButtonRemoveTarget.Add_Click({ $MainFormListboxTargets.Items.Remove($MainFormListboxTargets.SelectedItem)})
$MainForm.Controls.Add($MainFormButtonRemoveTarget)

# Textbox to enter in target computer names
$MainFormTextboxAddTarget = New-Object System.Windows.Forms.TextBox
$MainFormTextboxAddTarget.Location="258,224"
$MainFormTextboxAddTarget.Size="219,20"
$MainFormTextboxAddTarget.Add_KeyDown({
	# If user presses Enter while this box is selected, add the value in the textbox to the Target Listbox
	if ($_.KeyCode -eq "Enter") {
		if ($MainFormTextboxAddTarget.Text -ne $null -and $MainFormTextboxAddTarget.Text -ne "") {
			$MainFormListboxTargets.Items.Add($MainFormTextboxAddTarget.Text)
			$MainFormTextboxAddTarget.Text=""
		}
	}
})
$MainForm.Controls.Add($MainFormTextboxAddTarget)

# "Current User" label
$MainFormLabelCurrentUser = New-Object System.Windows.Forms.Label
$MainFormLabelCurrentUser.Text="Current User:"
$MainFormLabelCurrentUser.Location="300,250"
$MainFormLabelCurrentUser.Size="75,15"
$MainForm.Controls.Add($MainFormLabelCurrentUser)

# Label for current user name
$MainFormLabelUsername = New-Object System.Windows.Forms.Label
$MainFormLabelUsername.Text=$Env:USERNAME
$MainFormLabelUsername.Location="380,250"
$MainFormLabelUsername.Size="150,15"
$MainForm.Controls.Add($MainFormLabelUsername)

# Button to Change Credentials
$MainFormButtonCredential = New-Object System.Windows.Forms.Button
$MainFormButtonCredential.Text="Change Credentials"
$MainFormButtonCredential.Location="300,270"
$MainFormButtonCredential.Size="120,23"
# Run the Invoke-LiveResponseCredentials script when this button is clicked
$MainFormButtonCredential.Add_Click({
	$Credentials = & "$ScriptDirectory\Plugins\Invoke-LiveResponseCredentials.ps1"
	# Update the GUI with the new credentials
	if ($Credentials -ne $null -and $Credentials -ne "") {
		$MainFormLabelUsername.Text=$Credentials.Username
		$MainFormLabelUsername.Refresh()
	}
})
$MainForm.Controls.Add($MainFormButtonCredential)

# Run Button
$MainFormButtonRun = New-Object System.Windows.Forms.Button
$MainFormButtonRun.Text="Run"
$MainFormButtonRun.Size="75,23"
$MainFormButtonRun.Location="149,310"
$MainFormButtonRun.Add_Click({
	$ModulesSelected=$False
	# Verify there is at least one selected module
	for($i=0; $i -lt $MainFormListboxModules.Items.Count; $i++) {
		if ($MainFormListboxModules.GetItemChecked($i) -eq $True) {
			$ModulesSelected=$True
		}
	}
	# No modules are selected, give a pop up error message
	if ($ModulesSelected -eq $False) {
		[System.Windows.Forms.MessageBox]::Show("No Modules Selected")
	} else {
		# Verify at least 1 target entered
		if ($MainFormListboxTargets.Items.Count -eq 0) {
			[System.Windows.Forms.MessageBox]::Show("No Targets Entered")
		} else {
			# Initialize selection arrays
			$ExecutingModuleList = @()
			
			# Add the Selected Modules and Targets to the Arrays, then run the function to Execute Modules
			for ($i=0; $i -lt $MainFormListboxModules.Items.Count; $i++) {
				if ($MainFormListboxModules.GetItemChecked($i) -eq $True) {
					$ExecutingModuleList += [String]$MainFormListboxModules.Items[$i].ToString()
				}
			}
			[String[]]$ExecutingTargetList = $MainFormListboxTargets.Items
			$MainForm.Close()
			$MainForm.Dispose()
			
			if ($Credentials) {
				& "$ScriptDirectory\Invoke-LiveResponse.ps1" -ComputerName $ExecutingTargetList -Module $ExecutingModuleList -Credential $Credentials
			} else {
                & "$ScriptDirectory\Invoke-LiveResponse.ps1" -ComputerName $ExecutingTargetList -Module $ExecutingModuleList
			}
		}
	}
})
$MainForm.Controls.Add($MainFormButtonRun)

# Cancel Button
$MainFormButtonCancel = New-Object System.Windows.Forms.Button
$MainFormButtonCancel.Text="Cancel"
$MainFormButtonCancel.Size="75,23"
$MainFormButtonCancel.Location="260,310"
$MainForm.Controls.Add($MainFormButtonCancel)
$MainForm.CancelButton=$MainFormButtonCancel
#endregion Create Form for Main Menu

# Query for a list of available modules
$ModuleList = & "$ScriptDirectory\Invoke-LiveResponse.ps1" -ShowModules

# Add the modules to the Module Listbox in the GUI
ForEach ($Module in $ModuleList) {
	$MainFormListboxModules.Items.Add($Module.Name.Trim(".ps1")) | Out-Null
}

# Query for a list of available Module Sets
$ModuleSetList = & "$ScriptDirectory\Invoke-LiveResponse.ps1" -ShowModuleSets

# Add the Module Sets to the Module Combobox in the GUI
ForEach ($ModuleSet in $ModuleSetList) {
	$MainFormComboboxModuleSets.Items.Add($ModuleSet.Name) | Out-Null
}

# Launch the GUI
$MainForm.ShowDialog() | Out-Null