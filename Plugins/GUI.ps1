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

#region Create Form for Change Credentials Click
function ChangeCredentials {
	[CmdletBinding()]Param(
		[Parameter(Mandatory=$True)][String]$ScriptDirectory,
		[Parameter(Mandatory=$True)][System.Drawing.Font]$Font
	)
	# ChangeCredentials Form
	$ChangeCredsForm = New-Object System.Windows.Forms.Form
	$ChangeCredsForm.FormBorderStyle = "FixedDialog"
	$ChangeCredsForm.Size = "220,215"
	$ChangeCredsForm.Text = "Change Credentials"
	$ChangeCredsForm.Font = $Font
	$ChangeCredsForm.MaximizeBox = $False
	$ChangeCredsForm.StartPosition = "CenterScreen"
	
	# Prompt Radio Button
	$ChangeCredsFormRadioButtonPrompt = New-Object System.Windows.Forms.RadioButton
	$ChangeCredsFormRadioButtonPrompt.Text = "Prompt for Credentials"
	$ChangeCredsFormRadioButtonPrompt.Location = "5,5"
	$ChangeCredsFormRadioButtonPrompt.Size = "175,18"
	$ChangeCredsFormRadioButtonPrompt.Checked = $True
	$ChangeCredsFormRadioButtonPrompt.Add_Click({
		if ($ChangeCredsFormRadioButtonPrompt.Checked -eq $True) {
			$ChangeCredsFormComboboxPlugins.Enabled = $False
		} else {
			$ChangeCredsFormComboboxPlugins.Enabled = $True
		}
	})
	$ChangeCredsForm.Controls.Add($ChangeCredsFormRadioButtonPrompt)
	
	# Plugin Radio Button
	$ChangeCredsFormRadioButtonPlugin = New-Object System.Windows.Forms.RadioButton
	$ChangeCredsFormRadioButtonPlugin.Text = "Use a Plugin"
	$ChangeCredsFormRadioButtonPlugin.Location = "5,30"
	$ChangeCredsFormRadioButtonPlugin.Size = "100,18"
	$ChangeCredsFormRadioButtonPlugin.Checked = $False
	$ChangeCredsFormRadioButtonPlugin.Add_Click({
		if ($ChangeCredsFormRadioButtonPlugin.Checked -eq $True) {
			$ChangeCredsFormComboboxPlugins.Enabled = $True
		} else {
			$ChangeCredsFormComboboxPlugins.Enabled = $False
		}
	})
	$ChangeCredsForm.Controls.Add($ChangeCredsFormRadioButtonPlugin)
	
	# Plugins Drop Down Box
	$ChangeCredsFormComboboxPlugins = New-Object System.Windows.Forms.Combobox
	$ChangeCredsFormComboboxPlugins.Location = "15,55"
	$ChangeCredsFormComboboxPlugins.Size = "150,21"
	$ChangeCredsFormComboboxPlugins.DropDownStyle = "DropDownList"
	$ChangeCredsFormComboboxPlugins.Enabled = $False
	$ChangeCredsForm.Controls.Add($ChangeCredsFormComboboxPlugins)
	Get-ChildItem -Path "$ScriptDirectory\Plugins" -Filter "*Credential*.ps1" | ForEach-Object {
		$ChangeCredsFormComboboxPlugins.Items.Add($_.Name) | Out-Null
	}
	
	# Cancel Button
	$ChangeCredsFormButtonCancel = New-Object System.Windows.Forms.Button
	$ChangeCredsFormButtonCancel.Size = "75,23"
	$ChangeCredsFormButtonCancel.Location = "90,150"
	$ChangeCredsFormButtonCancel.Text = "Cancel"
	$ChangeCredsForm.CancelButton = $ChangeCredsFormButtonCancel
	$ChangeCredsForm.Controls.Add($ChangeCredsFormButtonCancel)
	
	# OK Button
	$ChangeCredsFormButtonOK = New-Object System.Windows.Forms.Button
	$ChangeCredsFormButtonOK.Size = "75,23"
	$ChangeCredsFormButtonOK.Location = "10,150"
	$ChangeCredsFormButtonOK.Text = "OK"
	$ChangeCredsFormButtonOK.Add_Click({
		$ChangeCredsForm.Close()
		$ChangeCredsForm.Dispose()
	})
	$ChangeCredsForm.Controls.Add($ChangeCredsFormButtonOK)
	
	$ChangeCredsForm.ShowDialog() | Out-Null
	
	if ($ChangeCredsFormRadioButtonPlugin.Checked -eq $True) {
		& "$ScriptDirectory\Plugins\$($ChangeCredsFormComboboxPlugins.SelectedItem)"
	} else {
		Get-Credential -Message "Enter credentials for use in Invoke-LiveResponse"
	}
}
#endregion Create Form for Change Credentials Click

#region Create Form for Options Menu
function OptionsMenu {
	[CmdletBinding()]Param(
		[Parameter(Mandatory=$True)][String]$ScriptDirectory,
		[Parameter(Mandatory=$True)][System.Drawing.Font]$Font
	)
	# Options Form
	$OptionsForm = New-Object System.Windows.Forms.Form
	$OptionsForm.FormBorderStyle = "FixedDialog"
	$OptionsForm.Size = "310,215"
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
	$OptionsFormNumericUpDownConcurrentJobs.Text = "2"
	$OptionsFormNumericUpDownConcurrentJobs.Enabled = $False
	$OptionsFormNumericUpDownConcurrentJobs.Maximum = 10
	$OptionsForm.Controls.Add($OptionsFormNumericUpDownConcurrentJobs)
	
	# WinRM Fix Setting
	$OptionsFormCheckboxWinRMFix = New-Object System.Windows.Forms.CheckBox
	$OptionsFormCheckboxWinRMFix.Size = "180,23"
	$OptionsFormCheckboxWinRMFix.Location = "5,90"
	$OptionsFormCheckboxWinRMFix.Text = "Fix WinRM if it isn't working"
	$OptionsFormCheckboxWinRMFix.Checked = $True
	$OptionsFormCheckboxWinRMFix.add_CheckStateChanged({
		if ($OptionsFormCheckboxWinRMFix.Checked -eq $True) {
			$OptionsFormCheckboxRevertWinRMFix.Enabled = $True
		} else {
			$OptionsFormCheckboxRevertWinRMFix.Enabled = $False
		}
	})
	$OptionsForm.Controls.Add($OptionsFormCheckboxWinRMFix)
	
	# Revert WinRM Fix Setting
	$OptionsFormCheckboxRevertWinRMFix = New-Object System.Windows.Forms.CheckBox
	$OptionsFormCheckboxRevertWinRMFix.Size = "220,23"
	$OptionsFormCheckboxRevertWinRMFix.Location = "25,120"
	$OptionsFormCheckboxRevertWinRMFix.Text = "Revert WinRM changes when done."
	$OptionsFormCheckboxRevertWinRMFix.Checked = $True
	$OptionsForm.Controls.Add($OptionsFormCheckboxRevertWinRMFix)

	# Save Button
	$OptionsFormButtonSave = New-Object System.Windows.Forms.Button
	$OptionsFormButtonSave.Size = "75,23"
	$OptionsFormButtonSave.Location = "45,150"
	$OptionsFormButtonSave.Text = "Save"
	$OptionsFormButtonSave.add_Click({
		if ($OptionsFormCheckboxSavePath.Checked -eq $True) {
			& "$ScriptDirectory\Invoke-LiveResponse.ps1" -Config -SavePath $OptionsFormTextboxSavePath.Text
		} else {
			& "$ScriptDirectory\Invoke-LiveResponse.ps1" -Config -SavePath "remove"
		}
		if ($OptionsFormCheckboxConcurrentJobs.Checked -eq $True) {
			& "$ScriptDirectory\Invoke-LiveResponse.ps1" -Config -ConcurrentJobs $OptionsFormNumericUpDownConcurrentJobs.Text
		} else {
			& "$ScriptDirectory\Invoke-LiveResponse.ps1" -Config -ConcurrentJobs "0"
		}
		if ($OptionsFormCheckboxWinRMFix.Checked -eq $True) {
			& "$ScriptDirectory\Invoke-LiveResponse.ps1" -Config -WinRMFix $True
		} else {
			& "$ScriptDirectory\Invoke-LiveResponse.ps1" -Config -WinRMFix $False
		}
		if ($OptionsFormCheckboxRevertWinRMFix.Checked -eq $True) {
			& "$ScriptDirectory\Invoke-LiveResponse.ps1" -Config -RevertWinRMFix $True
		} else {
			& "$ScriptDirectory\Invoke-LiveResponse.ps1" -Config -RevertWinRMFix $False
		}
		$OptionsForm.Close()
		$OptionsForm.Dispose()
	})
	$OptionsForm.Controls.Add($OptionsFormButtonSave)
	
	# Cancel Button
	$OptionsFormButtonCancel = New-Object System.Windows.Forms.Button
	$OptionsFormButtonCancel.Size = "75,23"
	$OptionsFormButtonCancel.Location = "130,150"
	$OptionsFormButtonCancel.Text = "Cancel"
	$OptionsForm.CancelButton = $OptionsFormButtonCancel
	$OptionsForm.Controls.Add($OptionsFormButtonCancel)
	
	# Load current configuraiton settings
	$Configuration = & "$ScriptDirectory\Invoke-LiveResponse.ps1" -Config
	
	# Set SavePath to current configuration
	if ($Configuration.SavePath) {
		$OptionsFormTextboxSavePath.Text = $Configuration.SavePath
		$OptionsFormCheckboxSavePath.Checked = $True
	}
	
	# Set ConcurrentJobs to current configuration
	if ($Configuration.ConcurrentJobs) {
		$OptionsFormNumericUpDownConcurrentJobs.Text = $Configuration.ConcurrentJobs
	}
	# Set WinRMFix to current configuration
	if ($Configuration.WinRMFix -eq "True") {
		$OptionsFormCheckboxWinRMFix.Checked = $True	
	} elseif ($Configuration.WinRMFix -eq "False") {
		$OptionsFormCheckboxWinRMFix.Checked = $False
	}
	
	# Set RevertWinRMFix to current configuration
	if ($Configuration.RevertWinRMFix -eq "True") {
		$OptionsFormCheckboxRevertWinRMFix.Checked = $True	
	} elseif ($Configuration.RevertWinRMFix -eq "False") {
		$OptionsFormCheckboxRevertWinRMFix.Checked = $False
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
	$AboutFormLabelVersion.Text = "Version: 1.3"
	$AboutForm.Controls.Add($AboutFormLabelVersion)
	
	# Link Label for Github
	$AboutFormLinkLabelGithub = New-Object System.Windows.Forms.LinkLabel
	$AboutFormLinkLabelGithub.Location = "5,95"
	$AboutFormLinkLabelGithub.Size = "200,15"
	$AboutFormLinkLabelGithub.Text = "Invoke-LiveResponse Wiki"
	$AboutFormLinkLabelGithub.LinkColor = "BLUE"
	$AboutFormLinkLabelGithub.ActiveLinkColor = "RED"
	$AboutFormLinkLabelGithub.Add_Click({
		[System.Diagnostics.Process]::Start("https://github.com/davidhowell-tx/Invoke-LiveResponse/wiki")
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
$MainForm.Size="710,370"
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

# "Collection Modules" Label
$MainFormLabelCollectionModules = New-Object System.Windows.Forms.Label
$MainFormLabelCollectionModules.Text="Collection Modules:"
$MainFormLabelCollectionModules.Location="5,25"
$MainFormLabelCollectionModules.Size="110,15"
$MainForm.Controls.Add($MainFormLabelCollectionModules)

# "Clear" Button for Collection Modules Listbox
$MainFormButtonClearCollectionModules = New-Object System.Windows.Forms.Button
$MainFormButtonClearCollectionModules.Text = "Clear"
$MainFormButtonClearCollectionModules.Location = "170,25"
$MainFormButtonClearCollectionModules.Size = "50,18"
$MainFormButtonClearCollectionModules.Add_Click({
	for ($i=0; $i -lt $MainFormListboxCollectionModules.Items.Count; $i++) {
		$MainFormListboxCollectionModules.SetItemChecked($i, $False)
	}
})
$MainForm.Controls.Add($MainFormButtonClearCollectionModules)

# "Collection Modules" Listbox
$MainFormListboxCollectionModules = New-Object System.Windows.Forms.CheckedListBox
$MainFormListboxCollectionModules.Location="12,45"
$MainFormListboxCollectionModules.Size="212,199"
$MainFormListboxCollectionModules.ScrollAlwaysVisible=$True
$MainFormListboxCollectionModules.CheckOnClick=$True
$MainFormListboxCollectionModules.Sorted=$True
$MainForm.Controls.Add($MainFormListboxCollectionModules)

# Right-Click Menu for Collection Modules Listbox
$MainFormContextMenuCollectionModuleInfo = New-Object System.Windows.Forms.ContextMenuStrip
$MainFormMenuItemCollectionModuleInfo = New-Object System.Windows.Forms.ToolStripMenuItem
$MainFormMenuItemCollectionModuleInfo.Text = "More Info"
$MainFormMenuItemCollectionModuleInfo.Add_Click({
	# Look up the Description for the Selected Collection Module	
	ForEach ($CollectionModule in $CollectionModuleList) {
		if ($CollectionModule.Name -eq $MainFormListboxCollectionModules.Items[$MainFormListboxCollectionModules.SelectedIndex]) {
			$CollectionModuleDescription = @()
			$CollectionModuleDescription += "Name: " + $CollectionModule.Name + "`n"
			$CollectionModuleDescription += "Description: " + $CollectionModule.Description + "`n"
			$CollectionModuleDescription += "Output Type: " + $CollectionModule.OutputType + "`n"
			$CollectionModuleDescription += "Binary Dependency: " + $CollectionModule.BinaryDependency + "`n"
			$CollectionModuleDescription += "Binary Name: " + $CollectionModule.BinaryName + "`n"
			[System.Windows.Forms.MessageBox]::Show($CollectionModuleDescription)
		}
	}
})
$MainFormContextMenuCollectionModuleInfo.Items.Add($MainFormMenuItemCollectionModuleInfo) | Out-Null
$MainFormListboxCollectionModules.ContextMenuStrip=$MainFormContextMenuCollectionModuleInfo

# "Module Group" Label
$MainFormLabelModuleGroup = New-Object System.Windows.Forms.Label
$MainFormLabelModuleGroup.Text = "Module Group:"
$MainFormLabelModuleGroup.Location = "5,250"
$MainFormLabelModuleGroup.Size = "130,15"
$MainForm.Controls.Add($MainFormLabelModuleGroup)

# Drop Down List to pick Module Group
$MainFormComboboxModuleGroups = New-Object System.Windows.Forms.Combobox
$MainFormComboboxModuleGroups.Location = "10,265"
$MainFormComboboxModuleGroups.Size = "212,21"
$MainFormComboboxModuleGroups.DropDownStyle = "DropDownList"
$MainFormComboboxModuleGroups.Add_SelectedIndexChanged({
	# First, uncheck all collection modules
	for ($i=0; $i -lt $MainFormListboxCollectionModules.Items.Count; $i++) {
		$MainFormListboxCollectionModules.SetItemChecked($i, $False)
	}
	
	# Now select all of the collection modules included in the selected collection group
	if ($MainFormComboboxModuleGroups.SelectedItem -ne $null -and $MainFormComboboxModuleGroups -ne "") {
		ForEach ($ModuleGroup in $ModuleGroupList) {
			if ($ModuleGroup.Name -eq $MainFormComboboxModuleGroups.SelectedItem) {
				$CollectionModules = $ModuleGroup.CollectionModules -split ", "
				ForEach ($CollectionModule in $CollectionModules) {
					for ($i=0; $i -lt $MainFormListboxCollectionModules.Items.Count; $i++) {
						if ($MainFormListboxCollectionModules.Items[$i] -eq $CollectionModule) { 
							$MainFormListboxCollectionModules.SetItemChecked($i, $True)
						}
					}
				}
			}
		}
	}
})
$MainForm.Controls.Add($MainFormComboboxModuleGroups)

# "Analysis Modules" Label
$MainFormLabelAnalysisModules = New-Object System.Windows.Forms.Label
$MainFormLabelAnalysisModules.Text="Analysis Modules:"
$MainFormLabelAnalysisModules.Location="235,25"
$MainFormLabelAnalysisModules.Size="110,15"
$MainForm.Controls.Add($MainFormLabelAnalysisModules)

# "Clear" Button for Analysis Modules Listbox
$MainFormButtonClearAnalysisModules = New-Object System.Windows.Forms.Button
$MainFormButtonClearAnalysisModules.Text = "Clear"
$MainFormButtonClearAnalysisModules.Location = "400,25"
$MainFormButtonClearAnalysisModules.Size = "50,18"
$MainFormButtonClearAnalysisModules.Add_Click({
	for ($i=0; $i -lt $MainFormListboxAnalysisModules.Items.Count; $i++) {
		$MainFormListboxAnalysisModules.SetItemChecked($i, $False)
	}
})
$MainForm.Controls.Add($MainFormButtonClearAnalysisModules)

# "Analysis Modules" Listbox
$MainFormListboxAnalysisModules = New-Object System.Windows.Forms.CheckedListBox
$MainFormListboxAnalysisModules.Location="242,45"
$MainFormListboxAnalysisModules.Size="212,199"
$MainFormListboxAnalysisModules.ScrollAlwaysVisible=$True
$MainFormListboxAnalysisModules.CheckOnClick=$True
$MainFormListboxAnalysisModules.Sorted=$True
$MainForm.Controls.Add($MainFormListboxAnalysisModules)

# Right-Click Menu for Analysis Modules Listbox
$MainFormContextMenuAnalysisModuleInfo = New-Object System.Windows.Forms.ContextMenuStrip
$MainFormMenuItemAnalysisModuleInfo = New-Object System.Windows.Forms.ToolStripMenuItem
$MainFormMenuItemAnalysisModuleInfo.Text = "More Info"
$MainFormMenuItemAnalysisModuleInfo.Add_Click({
	# Look up the Description for the Selected Analysis Module	
	ForEach ($AnalysisModule in $AnalysisModuleList) {
		if ($AnalysisModule.Name -eq $MainFormListboxAnalysisModules.Items[$MainFormListboxAnalysisModules.SelectedIndex]) {
			$AnalysisModuleDescription = @()
			$AnalysisModuleDescription += "Name: " + $AnalysisModule.Name + "`n"
			$AnalysisModuleDescription += "Description: " + $AnalysisModule.Description + "`n"
			[System.Windows.Forms.MessageBox]::Show($AnalysisModuleDescription)
		}
	}
})
$MainFormContextMenuAnalysisModuleInfo.Items.Add($MainFormMenuItemAnalysisModuleInfo) | Out-Null
$MainFormListboxAnalysisModules.ContextMenuStrip=$MainFormContextMenuAnalysisModuleInfo

# "Job Type" Label
$MainFormLabelJobType = New-Object System.Windows.Forms.Label
$MainFormLabelJobType.Text = "Job Type:"
$MainFormLabelJobType.Location = "235,250"
$MainFormLabelJobType.Size = "100,15"
$MainForm.Controls.Add($MainFormLabelJobType)

# "Live Response" Radio Button
$MainFormRadioButtonLiveResponse = New-Object System.Windows.Forms.RadioButton
$MainFormRadioButtonLiveResponse.Text = "Live Response"
$MainFormRadioButtonLiveResponse.Location = "250,270"
$MainFormRadioButtonLiveResponse.Size = "100,18"
$MainFormRadioButtonLiveResponse.Checked = $True
$MainForm.Controls.Add($MainFormRadioButtonLiveResponse)

# "Hunting" Radio Button
$MainFormRadioButtonHunting = New-Object System.Windows.Forms.RadioButton
$MainFormRadioButtonHunting.Text = "Hunting"
$MainFormRadioButtonHunting.Location = "360,270"
$MainFormRadioButtonHunting.Size = "100,18"
$MainForm.Controls.Add($MainFormRadioButtonHunting)

# "Targets" Label
$MainFormLabelTargets = New-Object System.Windows.Forms.Label
$MainFormLabelTargets.Text="Targets:"
$MainFormLabelTargets.Location="468,25"
$MainFormLabelTargets.Size="52,15"
$MainForm.Controls.Add($MainFormLabelTargets)

# Targets Listbox
$MainFormListboxTargets = New-Object System.Windows.Forms.ListBox
$MainFormListboxTargets.Location="468,45"
$MainFormListboxTargets.Size="219,147"
$MainFormListboxTargets.ScrollAlwaysVisible=$True
$MainForm.Controls.Add($MainFormListboxTargets)

# Button to Add a new target to targets listbox
$MainFormButtonAddTarget = New-Object System.Windows.Forms.Button
$MainFormButtonAddTarget.Text="Add"
$MainFormButtonAddTarget.Location="508,195"
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
$MainFormButtonRemoveTarget.Location="595,195"
$MainFormButtonRemoveTarget.Size="55,23"
$MainFormButtonRemoveTarget.Add_Click({ $MainFormListboxTargets.Items.Remove($MainFormListboxTargets.SelectedItem)})
$MainForm.Controls.Add($MainFormButtonRemoveTarget)

# Textbox to enter in target computer names
$MainFormTextboxAddTarget = New-Object System.Windows.Forms.TextBox
$MainFormTextboxAddTarget.Location="468,224"
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
$MainFormLabelCurrentUser.Location="510,250"
$MainFormLabelCurrentUser.Size="75,15"
$MainForm.Controls.Add($MainFormLabelCurrentUser)

# Label for current user name
$MainFormLabelUsername = New-Object System.Windows.Forms.Label
$MainFormLabelUsername.Text=$Env:USERNAME
$MainFormLabelUsername.Location="590,250"
$MainFormLabelUsername.Size="150,15"
$MainForm.Controls.Add($MainFormLabelUsername)

# Button to Change Credentials
$MainFormButtonCredential = New-Object System.Windows.Forms.Button
$MainFormButtonCredential.Text="Change Credentials"
$MainFormButtonCredential.Location="510,270"
$MainFormButtonCredential.Size="120,23"
# Run the Invoke-LiveResponseCredentials script when this button is clicked
$MainFormButtonCredential.Add_Click({
	[System.Management.Automation.PSCredential]$Credentials = ChangeCredentials -ScriptDirectory $ScriptDirectory -Font $Font
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
	$CollectionModulesSelected=$False
	# Verify there is at least one selected collection module
	for($i=0; $i -lt $MainFormListboxCollectionModules.Items.Count; $i++) {
		if ($MainFormListboxCollectionModules.GetItemChecked($i) -eq $True) {
			$CollectionModulesSelected=$True
		}
	}
	# No collection modules are selected, give a pop up error message
	if ($CollectionModulesSelected -eq $False) {
		[System.Windows.Forms.MessageBox]::Show("No Collection Modules Selected")
	} else {
		# Verify at least 1 target entered
		if ($MainFormListboxTargets.Items.Count -eq 0) {
			[System.Windows.Forms.MessageBox]::Show("No Targets Entered")
		} else {
			# Initialize selection arrays
			$ExecutingCollectionModuleList = @()
			$ExecutingTargetList = @()
			
			# Add the Selected collection modules and Targets to the Arrays, then execute Invoke-LiveResponse
			for ($i=0; $i -lt $MainFormListboxCollectionModules.Items.Count; $i++) {
				if ($MainFormListboxCollectionModules.GetItemChecked($i) -eq $True) {
					$ExecutingCollectionModuleList += $MainFormListboxCollectionModules.Items[$i].ToString()
				}
			}
			$ExecutingTargetList += $MainFormListboxTargets.Items
			$MainForm.Close()
			$MainForm.Dispose()
			
			if ($Credentials) {
				& "$ScriptDirectory\Invoke-LiveResponse.ps1" -ComputerName $ExecutingTargetList -CollectionModule $ExecutingCollectionModuleList -PSCredential $Credentials
			} else {
				& "$ScriptDirectory\Invoke-LiveResponse.ps1" -ComputerName $ExecutingTargetList -CollectionModule $ExecutingCollectionModuleList
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

# Query for a list of available collection modules
$CollectionModuleList = & "$ScriptDirectory\Invoke-LiveResponse.ps1" -ShowCollectionModules

# Add the collection modules to the collection Module Listbox in the GUI
ForEach ($CollectionModule in $CollectionModuleList) {
	$MainFormListboxCollectionModules.Items.Add($CollectionModule.Name) | Out-Null
}

# Query for a list of available analysis modules
$AnalysisModuleList = & "$ScriptDirectory\Invoke-LiveResponse.ps1" -ShowAnalysisModules

# Add the analysis modules to the analysis module listbox in the GUI
ForEach ($AnalysisModule in $AnalysisModuleList) {
	$MainFormListboxAnalysisModules.Items.Add($AnalysisModule.Name) | Out-Null
}

# Query for a list of available collection groups
$ModuleGroupList = & "$ScriptDirectory\Invoke-LiveResponse.ps1" -ShowModuleGroups

# Add the collection groups to the collection group combobox in the GUI
ForEach ($ModuleGroup in $ModuleGroupList) {
	$MainFormComboboxModuleGroups.Items.Add($ModuleGroup.Name) | Out-Null
}

# Launch the GUI
$MainForm.ShowDialog() | Out-Null