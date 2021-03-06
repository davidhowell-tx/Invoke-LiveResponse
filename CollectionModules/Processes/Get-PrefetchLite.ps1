<#
.SYNOPSIS
	Parses a small amount of data from prefetch files.

.DESCRIPTION
	This script intentionally parses only the execution count and last execution time(s) from a prefetch file to have a quick processing time.

.NOTES
	Author: David Howell
	Last Modified: 02/01/2016
	For a script that parses more information from the Prefetch, please see the following link:
	https://github.com/davidhowell-tx/PS-WindowsForensics/blob/master/Prefetch/Invoke-PrefetchParser.ps1
	
OUTPUT csv
#>

$ASCIIEncoding = New-Object System.Text.ASCIIEncoding
$UnicodeEncoding = New-Object System.Text.UnicodeEncoding

$PrefetchArray = @()

function Invoke-MAMDecompress {
	<#
	.SYNOPSIS
		Uses .NET Reflection to P/Invoke the Decompress classes necessary for MAM compression.
	#>
	$Domain = [AppDomain]::CurrentDomain
	$DynAssembly = New-Object System.Reflection.AssemblyName("DynamicAssembly")
	$AssemblyBuilder = $Domain.DefineDynamicAssembly($DynAssembly, [System.Reflection.Emit.AssemblyBuilderAccess]::Run)
	$ModuleBuilder = $AssemblyBuilder.DefineDynamicModule("ntdll", $False)
	$TypeBuilder = $ModuleBuilder.DefineType("ntdll", "Public, Class")
	
	#region RtlGetCompressionWorkSpaceSize
	# Define the RtlGetCompressionWorkSpaceSize Method
	$RtlGetCompressionWorkSpaceSizeMethod = $TypeBuilder.DefineMethod(
		"RtlGetCompressionWorkSpaceSize", # Method Name
		[System.Reflection.MethodAttributes] "Public, Static", # Method Attributes
		[UInt32], # Method Return Type
		[Type[]] @(
			[UInt16], # compressionFormat
			[UInt32], # compressBufferWorkSpaceSize
			[UInt32] # compressFragmentWorkSpaceSize
		)
	) # Method Parameters

	# Import DLL
	$RtlGetCompressionWorkSpaceSizeDllImport = [System.Runtime.InteropServices.DllImportAttribute].GetConstructor(@([String]))

	# Define Fields
	$RtlGetCompressionWorkSpaceSizeFieldArray = [System.Reflection.FieldInfo[]] @(
		[System.Runtime.InteropServices.DllImportAttribute].GetField("EntryPoint")
	)

	# Define Values for the fields
	$RtlGetCompressionWorkSpaceSizeFieldValueArray = [Object[]] @(
		"RtlGetCompressionWorkSpaceSize"
	)

	# Create a Custom Attribute and add to our Method
	$RtlGetCompressionWorkSpaceSizeCustomAttribute = New-Object System.Reflection.Emit.CustomAttributeBuilder(
		$RtlGetCompressionWorkSpaceSizeDllImport,
		@("ntdll.dll"),
		$RtlGetCompressionWorkSpaceSizeFieldArray,
		$RtlGetCompressionWorkSpaceSizeFieldValueArray
	)
	$RtlGetCompressionWorkSpaceSizeMethod.SetCustomAttribute($RtlGetCompressionWorkSpaceSizeCustomAttribute)
	#endregion RtlGetCompressionWorkSpaceSize
	
	#region RtlDecompressBufferEx
	$RtlDecompressBufferExMethod = $TypeBuilder.DefineMethod(
		"RtlDecompressBufferEx", # Method Name
		[System.Reflection.MethodAttributes] "Public, Static", # Method Attributes
		[UInt32], # Method Return Type
		[Type[]] @(
			[UInt16], # compressionFormat
			[Byte[]], # uncompressedBuffer
			[Int], # uncompressedBufferSize
			[Byte[]], # compressedBuffer
			[Int], # compressedBufferSize
			[Int], # finalUncompressedSize
			[Byte[]] # workSpace
		)
	) # Method Parameters
	
	# Import DLL
	$RtlDecompressBufferExDllImport = [System.Runtime.InteropServices.DllImportAttribute].GetConstructor(@([String]))

	# Define Fields
	$RtlDecompressBufferExFieldArray = [System.Reflection.FieldInfo[]] @(
	[System.Runtime.InteropServices.DllImportAttribute].GetField("EntryPoint")
	)

	# Define Values for the fields
	$RtlDecompressBufferExFieldValueArray = [Object[]] @(
	"RtlDecompressBufferEx"
	)

	# Create a Custom Attribute and add to our Method
	$RtlDecompressBufferExCustomAttribute = New-Object System.Reflection.Emit.CustomAttributeBuilder(
	$RtlDecompressBufferExDllImport,
	@("ntdll.dll"),
	$RtlDecompressBufferExFieldArray,
	$RtlDecompressBufferExFieldValueArray
	)
	$RtlDecompressBufferExMethod.SetCustomAttribute($RtlDecompressBufferExCustomAttribute)
	#endregion RtlDecompressBufferEx
	
	# Create the Type within our Module
	$Ntdll = $TypeBuilder.CreateType()
}

Get-ChildItem -Path "$($Env:windir)\Prefetch" -Filter *.pf -Force | Select-Object -ExpandProperty FullName | ForEach-Object {
	# Open a FileStream to read the file, and a BinaryReader so we can read chunks and parse the data
	$FileStream = New-Object System.IO.FileStream -ArgumentList ($_, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
	$BinReader = New-Object System.IO.BinaryReader $FileStream
	
	# Create a Custom Object to store prefetch info
	$TempObject = "" | Select-Object -Property Name, Hash, LastExecutionTime, NumberOfExecutions
	
	##################################
	# Parse File Information Section #
	##################################
	
	# First 4 Bytes - Version Indicator
	$Version = [System.BitConverter]::ToString($BinReader.ReadBytes(4)) -replace "-",""
	
	# Next 4 Bytes are "SCCA" Signature
	$ASCIIEncoding.GetString($BinReader.ReadBytes(4)) | Out-Null

	# Next 4 Bytes are of unknown purpose
	# Value is 0x0F000000 for WinXP or 0x11000000 for Win7/8
	[System.BitConverter]::ToString($BinReader.ReadBytes(4)) -replace "-","" | Out-Null
	
	# 4 Bytes - size of the Prefetch file
	$TempObject | Add-Member -MemberType NoteProperty -Name "PrefetchSize" -Value ([System.BitConverter]::ToUInt32($BinReader.ReadBytes(4),0))

	# 60 bytes - Unicode encoded executable name
	$TempObject.Name = $UnicodeEncoding.GetString($BinReader.ReadBytes(60))

	# 4 bytes - the prefetch hash in little endian hexadecimal
	[Char[]]$LittleEndianHash = [System.BitConverter]::ToString($BinReader.ReadBytes(4)) -replace "-",""
	$TempObject.Hash = "$($LittleEndianHash[6])$($LittleEndianHash[7])$($LittleEndianHash[4])$($LittleEndianHash[5])$($LittleEndianHash[2])$($LittleEndianHash[3])$($LittleEndianHash[0])$($LittleEndianHash[1])"

	# 4 bytes - unknown purpose
	$BinReader.ReadBytes(4) | Out-Null
	
	# Use Version Indicator to determine prefetch structure type and switch to the appropriate processing
	switch ($Version) {
		# Windows XP Structure
		"11000000" {
			$BinReader.ReadBytes(36) | Out-Null
			# 8 bytes - Last Execution Time
			$TempObject.LastExecutionTime = [DateTime]::FromFileTime([System.BitConverter]::ToUInt64($BinReader.ReadBytes(8),0)).ToString("G")
			# 16 bytes - Unknown
			$BinReader.ReadBytes(16) | Out-Null
			# 4 bytes - Execution Count
			$TempObject.NumberOfExecutions = [System.BitConverter]::ToUInt32($BinReader.ReadBytes(4),0)
		}
		
		# Windows 7 Structure
		"17000000" {
			$BinReader.ReadBytes(44) | Out-Null
			# 8 bytes - Last Execution Time
			$TempObject.LastExecutionTime = [DateTime]::FromFileTime([System.BitConverter]::ToUInt64($BinReader.ReadBytes(8),0)).ToString("G")
			# 16 bytes - Unknown
			$BinReader.ReadBytes(16) | Out-Null
			# 4 bytes - Execution Count
			$TempObject.NumberOfExecutions = [System.BitConverter]::ToUInt32($BinReader.ReadBytes(4),0)
		}
		
		# Windows 8 Structure
		"1A000000" {
			# Remove LastExecutionTime since there are 8 instead of 1
			$TempObject.PSObject.Properties.Remove("LastExecutionTime")
			$BinReader.ReadBytes(44) | Out-Null
			
			# Loop through the 8 possible Date/Time values and add them if it isn't marked as zeros
			for ($i=1; $i -le 8; $i++) {
				$TimeValue = [System.BitConverter]::ToUInt64($BinReader.ReadBytes(8),0)
				if ($TimeValue -ne 0) {
					$TempObject | Add-Member -MemberType NoteProperty -Name "LastExecutionTime_$($i)" -Value ([DateTime]::FromFileTime($TimeValue))
				}
				Remove-Variable TimeValue -ErrorAction SilentlyContinue
			}

			# 16 bytes - Unknown
			$BinReader.ReadBytes(16) | Out-Null
			# 4 bytes - Execution Count
			$TempObject.NumberOfExecutions = [System.BitConverter]::ToUInt32($BinReader.ReadBytes(4),0)
		}
		
		# Windows 10 Structure
		"1E000000" {
			# Remove LastExecutionTime since there are 8 instead of 1
			$TempObject.PSObject.Properties.Remove("LastExecutionTime")
			$BinReader.ReadBytes(44) | Out-Null
			
			# Loop through the 8 possible Date/Time values and add them if it isn't marked as zeros
			for ($i=1; $i -le 8; $i++) {
				$TimeValue = [System.BitConverter]::ToUInt64($BinReader.ReadBytes(8),0)
				if ($TimeValue -ne 0) {
					$TempObject | Add-Member -MemberType NoteProperty -Name "LastExecutionTime_$($i)" -Value ([DateTime]::FromFileTime($TimeValue))
				}
				Remove-Variable TimeValue -ErrorAction SilentlyContinue
			}
			
			# 16 bytes - Unknown
			$BinReader.ReadBytes(16) | Out-Null
			
			# 4 bytes - Execution Count
			$TempObject.NumberOfExecutions = [System.BitConverter]::ToUInt32($BinReader.ReadBytes(4),0)
		}
	}
	$PrefetchArray += $TempObject
}
return $PrefetchArray