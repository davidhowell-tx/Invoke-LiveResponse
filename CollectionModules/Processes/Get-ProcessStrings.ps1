<#
.SYNOPSIS
	Outputs all printable strings from the user-mode memory of a process.

.DESCRIPTION
	Get-ProcessStrings reads every committed memory allocation that is 	not a guard page and returns all printable strings.
	By default,	Get-ProcessStrings ignores MEM_IMAGE allocations (most commonly allocated when modules are loaded) but they can be included with the -IncludeImages switch.

.NOTES
	All code, including dependency functions, by Matthew Graeber (@mattifestation) http://www.exploit-monday.com/
	Very few modifications performed by David Howell to convert this into a module for Invoke-LiveResponse
	License: BSD 3-Clause

OUTPUT txt
INPUT [Int32]ProcessID, [UInt16]MinimumLength, [Switch]IncludeImages
#>
[CmdletBinding()]
Param(
	[Parameter(Position=0,Mandatory=$True)]
	[ValidateScript({Get-Process -Id $_})]
	[Int32]
	$ProcessID,
	
	[Parameter(Position=1, Mandatory=$False)]
	[UInt16]
	$MinimumLength = 5,

	[Switch]
	$IncludeImages
)

Begin {
	#region Add Dependency Functions
	function New-InMemoryModule {
		<#
		.SYNOPSIS
			Creates an in-memory assembly and module
		 
		.DESCRIPTION
			When defining custom enums, structs, and unmanaged functions, it is necessary to associate to an assembly module.
			This helper function creates an in-memory module that can be passed to the 'enum', 'struct', and Add-Win32Type functions.
			
		.PARAMETER ModuleName
			Specifies the desired name for the in-memory assembly and module. If
			ModuleName is not provided, it will default to a GUID.
		#>
		Param(
			[Parameter(Position=0)]
			[ValidateNotNullOrEmpty()]
			[String]
			$ModuleName = [Guid]::NewGuid().ToString()
		)

		$LoadedAssemblies = [AppDomain]::CurrentDomain.GetAssemblies()

		foreach ($Assembly in $LoadedAssemblies) {
			if ($Assembly.FullName -and ($Assembly.FullName.Split(',')[0] -eq $ModuleName)) {
				return $Assembly
			}
		}

		$DynAssembly = New-Object Reflection.AssemblyName($ModuleName)
		$Domain = [AppDomain]::CurrentDomain
		$AssemblyBuilder = $Domain.DefineDynamicAssembly($DynAssembly, 'Run')
		$ModuleBuilder = $AssemblyBuilder.DefineDynamicModule($ModuleName, $False)

		return $ModuleBuilder
	}

	function func {
		Param(
			[Parameter(Position=0,Mandatory=$True)]
			[String]
			$DllName,

			[Parameter(Position=1,Mandatory=$True)]
			[string]
			$FunctionName,

			[Parameter(Position=2, Mandatory=$True)]
			[Type]
			$ReturnType,

			[Parameter(Position=3)]
			[Type[]]
			$ParameterTypes,

			[Parameter(Position=4)]
			[Runtime.InteropServices.CallingConvention]
			$NativeCallingConvention,

			[Parameter(Position=5)]
			[Runtime.InteropServices.CharSet]
			$Charset,

			[String]
			$EntryPoint,

			[Switch]
			$SetLastError
		)
		$Properties = @{
			DllName = $DllName
			FunctionName = $FunctionName
			ReturnType = $ReturnType
		}

		if ($ParameterTypes) {
			$Properties['ParameterTypes'] = $ParameterTypes
		}
		if ($NativeCallingConvention) {
			$Properties['NativeCallingConvention'] = $NativeCallingConvention
		}
		if ($Charset) {
			$Properties['Charset'] = $Charset
		}
		if ($SetLastError) {
			$Properties['SetLastError'] = $SetLastError
		}
		if ($EntryPoint) {
			$Properties['EntryPoint'] = $EntryPoint
		}

		New-Object PSObject -Property $Properties
	}
	
	function psenum {
		<#
		.SYNOPSIS
			Creates an in-memory enumeration for use in your PowerShell session.

		.DESCRIPTION
			The 'psenum' function facilitates the creation of enums entirely in memory using as close to a "C style" as PowerShell will allow.
		
		.PARAMETER Module
			The in-memory module that will host the enum. Use New-InMemoryModule to define an in-memory module.

		.PARAMETER FullName
			The fully-qualified name of the enum.
		
		.PARAMETER Type
			The type of each enum element.
		
		.PARAMETER EnumElements
			A hashtable of enum elements.
		
		.PARAMETER Bitfield
			Specifies that the enum should be treated as a bitfield.
		#>

		[OutputType([Type])]
		Param(
			[Parameter(Position=0,Mandatory=$True)]
			[ValidateScript({($_ -is [Reflection.Emit.ModuleBuilder]) -or ($_ -is [Reflection.Assembly]) -or ($_ -is [System.Reflection.RuntimeAssembly])})]
			$Module,

			[Parameter(Position = 1, Mandatory = $True)]
			[ValidateNotNullOrEmpty()]
			[String]
			$FullName,

			[Parameter(Position = 2, Mandatory = $True)]
			[Type]
			$Type,

			[Parameter(Position = 3, Mandatory = $True)]
			[ValidateNotNullOrEmpty()]
			[Hashtable]
			$EnumElements,

			[Switch]
			$Bitfield
		)

		if ($Module -is [Reflection.Assembly]) {
			return ($Module.GetType($FullName))
		}

		$EnumType = $Type -as [Type]

		$EnumBuilder = $Module.DefineEnum($FullName, 'Public', $EnumType)

		if ($Bitfield) {
			$FlagsConstructor = [FlagsAttribute].GetConstructor(@())
			$FlagsCustomAttribute = New-Object Reflection.Emit.CustomAttributeBuilder($FlagsConstructor, @())
			$EnumBuilder.SetCustomAttribute($FlagsCustomAttribute)
		}

		foreach ($Key in $EnumElements.Keys) {
			# Apply the specified enum type to each element
			$null = $EnumBuilder.DefineLiteral($Key, $EnumElements[$Key] -as $EnumType)
		}

		$EnumBuilder.CreateType()
	}
	
	function field {
		Param(
			[Parameter(Position = 0, Mandatory = $True)]
			[UInt16]
			$Position,

			[Parameter(Position = 1, Mandatory = $True)]
			[Type]
			$Type,

			[Parameter(Position = 2)]
			[UInt16]
			$Offset,

			[Object[]]
			$MarshalAs
		)

		@{
			Position = $Position
			Type = $Type -as [Type]
			Offset = $Offset
			MarshalAs = $MarshalAs
		}
	}

	function struct {
		<#
		.SYNOPSIS
			Creates an in-memory struct for use in your PowerShell session.

		.DESCRIPTION
			The 'struct' function facilitates the creation of structs entirely in memory using as close to a "C style" as PowerShell will allow.
			Struct fields are specified using a hashtable where each field of the struct is comprosed of the order in which it should be defined, its .NET type, and optionally, its offset and special marshaling attributes.
			One of the features of 'struct' is that after your struct is defined, it will come with a built-in GetSize method as well as an explicit converter so that you can easily cast an IntPtr to the struct without relying upon calling SizeOf and/or PtrToStructure in the Marshal class.
		
		.PARAMETER Module
			The in-memory module that will host the struct. Use New-InMemoryModule to define an in-memory module.
		
		.PARAMETER FullName
			The fully-qualified name of the struct.
		
		.PARAMETER StructFields
			A hashtable of fields. Use the 'field' helper function to ease defining each field.
		
		.PARAMETER PackingSize
			Specifies the memory alignment of fields.
		
		.PARAMETER ExplicitLayout
			Indicates that an explicit offset for each field will be specified.
		#>

		[OutputType([Type])]
		Param(
			[Parameter(Position = 1, Mandatory = $True)]
			[ValidateScript({($_ -is [Reflection.Emit.ModuleBuilder]) -or ($_ -is [Reflection.Assembly])})]
			$Module,

			[Parameter(Position = 2, Mandatory = $True)]
			[ValidateNotNullOrEmpty()]
			[String]
			$FullName,

			[Parameter(Position = 3, Mandatory = $True)]
			[ValidateNotNullOrEmpty()]
			[Hashtable]
			$StructFields,

			[Reflection.Emit.PackingSize]
			$PackingSize = [Reflection.Emit.PackingSize]::Unspecified,

			[Switch]
			$ExplicitLayout
		)

		if ($Module -is [Reflection.Assembly]) {
			return ($Module.GetType($FullName))
		}

		[Reflection.TypeAttributes] $StructAttributes = 'AnsiClass,
		Class,
		Public,
		Sealed,
		BeforeFieldInit'

		if ($ExplicitLayout) {
			$StructAttributes = $StructAttributes -bor [Reflection.TypeAttributes]::ExplicitLayout
		} else {
			$StructAttributes = $StructAttributes -bor [Reflection.TypeAttributes]::SequentialLayout
		}

		$StructBuilder = $Module.DefineType($FullName, $StructAttributes, [ValueType], $PackingSize)
		$ConstructorInfo = [Runtime.InteropServices.MarshalAsAttribute].GetConstructors()[0]
		$SizeConst = @([Runtime.InteropServices.MarshalAsAttribute].GetField('SizeConst'))

		$Fields = New-Object Hashtable[]($StructFields.Count)

		# Sort each field according to the orders specified
		# Unfortunately, PSv2 doesn't have the luxury of the hashtable [Ordered] accelerator.
		foreach ($Field in $StructFields.Keys) {
			$Index = $StructFields[$Field]['Position']
			$Fields[$Index] = @{FieldName = $Field; Properties = $StructFields[$Field]}
		}

		foreach ($Field in $Fields) {
			$FieldName = $Field['FieldName']
			$FieldProp = $Field['Properties']

			$Offset = $FieldProp['Offset']
			$Type = $FieldProp['Type']
			$MarshalAs = $FieldProp['MarshalAs']

			$NewField = $StructBuilder.DefineField($FieldName, $Type, 'Public')

			if ($MarshalAs) {
				$UnmanagedType = $MarshalAs[0] -as ([Runtime.InteropServices.UnmanagedType])
				if ($MarshalAs[1]) {
					$Size = $MarshalAs[1]
					$AttribBuilder = New-Object Reflection.Emit.CustomAttributeBuilder($ConstructorInfo,
					$UnmanagedType, $SizeConst, @($Size))
				} else{
					$AttribBuilder = New-Object Reflection.Emit.CustomAttributeBuilder($ConstructorInfo, [Object[]] @($UnmanagedType))
				}
				$NewField.SetCustomAttribute($AttribBuilder)
			}

			if ($ExplicitLayout) { 
				$NewField.SetOffset($Offset)
			}
		}

		# Make the struct aware of its own size. No more having to call [Runtime.InteropServices.Marshal]::SizeOf!
		$SizeMethod = $StructBuilder.DefineMethod('GetSize','Public, Static',[Int],[Type[]] @())
		$ILGenerator = $SizeMethod.GetILGenerator()
		# Thanks for the help, Jason Shirk!
		$ILGenerator.Emit([Reflection.Emit.OpCodes]::Ldtoken, $StructBuilder)
		$ILGenerator.Emit([Reflection.Emit.OpCodes]::Call,
		[Type].GetMethod('GetTypeFromHandle'))
		$ILGenerator.Emit([Reflection.Emit.OpCodes]::Call,
		[Runtime.InteropServices.Marshal].GetMethod('SizeOf', [Type[]] @([Type])))
		$ILGenerator.Emit([Reflection.Emit.OpCodes]::Ret)

		# Allow for explicit casting from an IntPtr. No more having to call [Runtime.InteropServices.Marshal]::PtrToStructure!
		$ImplicitConverter = $StructBuilder.DefineMethod('op_Implicit','PrivateScope, Public, Static, HideBySig, SpecialName',$StructBuilder,[Type[]] @([IntPtr]))
		$ILGenerator2 = $ImplicitConverter.GetILGenerator()
		$ILGenerator2.Emit([Reflection.Emit.OpCodes]::Nop)
		$ILGenerator2.Emit([Reflection.Emit.OpCodes]::Ldarg_0)
		$ILGenerator2.Emit([Reflection.Emit.OpCodes]::Ldtoken, $StructBuilder)
		$ILGenerator2.Emit([Reflection.Emit.OpCodes]::Call,
		[Type].GetMethod('GetTypeFromHandle'))
		$ILGenerator2.Emit([Reflection.Emit.OpCodes]::Call,
		[Runtime.InteropServices.Marshal].GetMethod('PtrToStructure', [Type[]] @([IntPtr], [Type])))
		$ILGenerator2.Emit([Reflection.Emit.OpCodes]::Unbox_Any, $StructBuilder)
		$ILGenerator2.Emit([Reflection.Emit.OpCodes]::Ret)

		$StructBuilder.CreateType()
	}
	
	function Add-Win32Type {
		<#
		.SYNOPSIS
			Creates a .NET type for an unmanaged Win32 function.
		 
		.DESCRIPTION
			Add-Win32Type enables you to easily interact with unmanaged (i.e. Win32 unmanaged) functions in PowerShell.
			After providing	Add-Win32Type with a function signature, a .NET type is created using reflection (i.e. csc.exe is never called like with Add-Type).
			The 'func' helper function can be used to reduce typing when defining multiple function definitions.

		.PARAMETER DllName
			The name of the DLL.
			
		.PARAMETER FunctionName
			The name of the target function.

		.PARAMETER EntryPoint
			The DLL export function name. This argument should be specified if the specified function name is different than the name of the exported function.

		.PARAMETER ReturnType
			The return type of the function.

		.PARAMETER ParameterTypes
			The function parameters.

		.PARAMETER NativeCallingConvention
			Specifies the native calling convention of the function. Defaults to stdcall.

		.PARAMETER Charset
			If you need to explicitly call an 'A' or 'W' Win32 function, you can specify the character set.

		.PARAMETER SetLastError
			Indicates whether the callee calls the SetLastError Win32 API function before returning from the attributed method.

		.PARAMETER Module
			The in-memory module that will host the functions. Use New-InMemoryModule to define an in-memory module.

		.PARAMETER Namespace
			An optional namespace to prepend to the type. Add-Win32Type defaults to a namespace consisting only of the name of the DLL.
		#>

		[OutputType([Hashtable])]
		Param(
			[Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)]
			[String]
			$DllName,

			[Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)]
			[String]
			$FunctionName,

			[Parameter(ValueFromPipelineByPropertyName = $True)]
			[String]
			$EntryPoint,

			[Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)]
			[Type]
			$ReturnType,

			[Parameter(ValueFromPipelineByPropertyName = $True)]
			[Type[]]
			$ParameterTypes,

			[Parameter(ValueFromPipelineByPropertyName = $True)]
			[Runtime.InteropServices.CallingConvention]
			$NativeCallingConvention = [Runtime.InteropServices.CallingConvention]::StdCall,

			[Parameter(ValueFromPipelineByPropertyName = $True)]
			[Runtime.InteropServices.CharSet]
			$Charset = [Runtime.InteropServices.CharSet]::Auto,

			[Parameter(ValueFromPipelineByPropertyName = $True)]
			[Switch]
			$SetLastError,

			[Parameter(Mandatory = $True)]
			[ValidateScript({($_ -is [Reflection.Emit.ModuleBuilder]) -or ($_ -is [Reflection.Assembly])})]
			$Module,

			[ValidateNotNull()]
			[String]
			$Namespace = ''
		)

		BEGIN {
			$TypeHash = New-Object System.Collections.Hashtable
		} PROCESS {
			if ($Module -is [Reflection.Assembly]) {
				if ($Namespace) {
					$TypeHash[$DllName] = $Module.GetType("$Namespace.$DllName")
				} else {
					$TypeHash[$DllName] = $Module.GetType($DllName)
				}
			} else {
				# Define one type for each DLL
				if (!$TypeHash.ContainsKey($DllName)) {
					if ($Namespace) {
						$TypeHash[$DllName] = $Module.DefineType("$Namespace.$DllName", 'Public,BeforeFieldInit')
					} else {
						$TypeHash[$DllName] = $Module.DefineType($DllName, 'Public,BeforeFieldInit')
					}
				}

			$Method = $TypeHash[$DllName].DefineMethod($FunctionName,'Public,Static,PinvokeImpl',$ReturnType,$ParameterTypes)

			# Make each ByRef parameter an Out parameter
			$i = 1
			foreach($Parameter in $ParameterTypes) {
				if ($Parameter.IsByRef) {
					[void] $Method.DefineParameter($i, 'Out', $null)
				}
				$i++
			}

			$DllImport = [Runtime.InteropServices.DllImportAttribute]
			$SetLastErrorField = $DllImport.GetField('SetLastError')
			$CallingConventionField = $DllImport.GetField('CallingConvention')
			$CharsetField = $DllImport.GetField('CharSet')
			$EntryPointField = $DllImport.GetField('EntryPoint')
			if ($SetLastError) { 
				$SLEValue = $True 
			} else { 
				$SLEValue = $False
			}

			if ($PSBoundParameters['EntryPoint']) { 
				$ExportedFuncName = $EntryPoint
			} else { 
				$ExportedFuncName = $FunctionName
			}

		# Equivalent to C# version of [DllImport(DllName)]
			$Constructor = [Runtime.InteropServices.DllImportAttribute].GetConstructor([String])
			$DllImportAttribute = New-Object Reflection.Emit.CustomAttributeBuilder($Constructor,$DllName, [Reflection.PropertyInfo[]] @(), [Object[]] @(),[Reflection.FieldInfo[]] @($SetLastErrorField,$CallingConventionField,$CharsetField,$EntryPointField),[Object[]] @($SLEValue,([Runtime.InteropServices.CallingConvention] $NativeCallingConvention),([Runtime.InteropServices.CharSet] $Charset),$ExportedFuncName))

			$Method.SetCustomAttribute($DllImportAttribute)
			}
		} END {
			if ($Module -is [Reflection.Assembly]) {
				return $TypeHash
			}

			$ReturnTypes = @{}

			foreach ($Key in $TypeHash.Keys) {
				$Type = $TypeHash[$Key].CreateType()
				$ReturnTypes[$Key] = $Type
			}

			return $ReturnTypes
		}
	}

	function Get-SystemInfo {
		<#
		.SYNOPSIS
			A wrapper for kernel32!GetSystemInfo
		#>
		$Mod = New-InMemoryModule -ModuleName SysInfo

		$ProcessorType = psenum -Module $Mod -FullName SYSINFO.PROCESSOR_ARCH -Type UInt16 -EnumElements @{ 
			PROCESSOR_ARCHITECTURE_INTEL = 0
			PROCESSOR_ARCHITECTURE_MIPS = 1
			PROCESSOR_ARCHITECTURE_ALPHA = 2
			PROCESSOR_ARCHITECTURE_PPC = 3
			PROCESSOR_ARCHITECTURE_SHX = 4
			PROCESSOR_ARCHITECTURE_ARM = 5
			PROCESSOR_ARCHITECTURE_IA64 = 6
			PROCESSOR_ARCHITECTURE_ALPHA64 = 7
			PROCESSOR_ARCHITECTURE_AMD64 = 9
			PROCESSOR_ARCHITECTURE_UNKNOWN = 0xFFFF
		}

		$SYSTEM_INFO = struct $Mod SYSINFO.SYSTEM_INFO @{
			ProcessorArchitecture = field 0 $ProcessorType
			Reserved = field 1 Int16
			PageSize = field 2 Int32
			MinimumApplicationAddress = field 3 IntPtr
			MaximumApplicationAddress = field 4 IntPtr
			ActiveProcessorMask = field 5 IntPtr
			NumberOfProcessors = field 6 Int32
			ProcessorType = field 7 Int32
			AllocationGranularity = field 8 Int32
			ProcessorLevel = field 9 Int16
			ProcessorRevision = field 10 Int16
		}

		$FunctionDefinitions = @(
			(func kernel32 GetSystemInfo ([Void]) @($SYSTEM_INFO.MakeByRefType()))
		)

		$Types = $FunctionDefinitions | Add-Win32Type -Module $Mod -Namespace 'Win32SysInfo'
		$Kernel32 = $Types['kernel32']

		$SysInfo = [Activator]::CreateInstance($SYSTEM_INFO)
		$Kernel32::GetSystemInfo([Ref] $SysInfo)

		$SysInfo
	}

	function Get-ProcessMemoryInfo {
		<#
		.SYNOPSIS
			Retrieve virtual memory information for every unique set of pages in user memory. This function is similar to the !vadump WinDbg command.

		.PARAMETER ProcessID
			Specifies the process ID.
		#>
		Param (
			[Parameter(ParameterSetName='InMemory',Position=0,Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
			[Alias('Id')]
			[ValidateScript({Get-Process -Id $_})]
			[Int]
			$ProcessID
		)
		$SysInfo = Get-SystemInfo
		$MemoryInfo = Get-VirtualMemoryInfo -ProcessID $ProcessID -ModuleBaseAddress ([IntPtr]::Zero) -PageSize $SysInfo.PageSize
		$MemoryInfo

		while (($MemoryInfo.BaseAddress + $MemoryInfo.RegionSize) -lt $SysInfo.MaximumApplicationAddress) {
			$BaseAllocation = [IntPtr] ($MemoryInfo.BaseAddress + $MemoryInfo.RegionSize)
			$MemoryInfo = Get-VirtualMemoryInfo -ProcessID $ProcessID -ModuleBaseAddress $BaseAllocation -PageSize $SysInfo.PageSize

			if ($MemoryInfo.State -eq 0) {
				break
			}
			$MemoryInfo
		}
	}
	
	function Get-VirtualMemoryInfo {
		<#
		.SYNOPSIS
			A wrapper for kernel32!VirtualQueryEx
		
		.PARAMETER ProcessID
			Specifies the process ID.
		
		.PARAMETER ModuleBaseAddress
			Specifies the address of the memory to be queried.
		
		.PARAMETER PageSize
			Specifies the system page size. Defaults to 0x1000 if one is not specified.
		#>

		Param (
			[Parameter(Position=0,Mandatory=$True)]
			[ValidateScript({Get-Process -Id $_})]
			[Int]
			$ProcessID,

			[Parameter(Position=1,Mandatory=$True)]
			[IntPtr]
			$ModuleBaseAddress,

			[Int]
			$PageSize = 0x1000
		)

		$Mod = New-InMemoryModule -ModuleName MemUtils

		$MemProtection = psenum $Mod MEMUTIL.MEM_PROTECT Int32 @{
			PAGE_EXECUTE =           0x00000010
			PAGE_EXECUTE_READ =      0x00000020
			PAGE_EXECUTE_READWRITE = 0x00000040
			PAGE_EXECUTE_WRITECOPY = 0x00000080
			PAGE_NOACCESS =          0x00000001
			PAGE_READONLY =          0x00000002
			PAGE_READWRITE =         0x00000004
			PAGE_WRITECOPY =         0x00000008
			PAGE_GUARD =             0x00000100
			PAGE_NOCACHE =           0x00000200
			PAGE_WRITECOMBINE =      0x00000400
		} -Bitfield

		$MemState = psenum $Mod MEMUTIL.MEM_STATE Int32 @{
			MEM_COMMIT =  0x00001000
			MEM_FREE =    0x00010000
			MEM_RESERVE = 0x00002000
		} -Bitfield

		$MemType = psenum $Mod MEMUTIL.MEM_TYPE Int32 @{
			MEM_IMAGE =   0x01000000
			MEM_MAPPED =  0x00040000
			MEM_PRIVATE = 0x00020000
		} -Bitfield

		if ([IntPtr]::Size -eq 4) {
			$MEMORY_BASIC_INFORMATION = struct $Mod MEMUTIL.MEMORY_BASIC_INFORMATION @{
				BaseAddress = field 0 Int32
				AllocationBase = field 1 Int32
				AllocationProtect = field 2 $MemProtection
				RegionSize = field 3 Int32
				State = field 4 $MemState
				Protect = field 5 $MemProtection
				Type = field 6 $MemType
			}
		} else {
			$MEMORY_BASIC_INFORMATION = struct $Mod MEMUTIL.MEMORY_BASIC_INFORMATION @{
				BaseAddress = field 0 Int64
				AllocationBase = field 1 Int64
				AllocationProtect = field 2 $MemProtection
				Alignment1 = field 3 Int32
				RegionSize = field 4 Int64
				State = field 5 $MemState
				Protect = field 6 $MemProtection
				Type = field 7 $MemType
				Alignment2 = field 8 Int32
			}
		}

		$FunctionDefinitions = @(
			(func kernel32 VirtualQueryEx ([Int32]) @([IntPtr], [IntPtr], $MEMORY_BASIC_INFORMATION.MakeByRefType(), [Int]) -SetLastError),
			(func kernel32 OpenProcess ([IntPtr]) @([UInt32], [Bool], [UInt32]) -SetLastError),
			(func kernel32 CloseHandle ([Bool]) @([IntPtr]) -SetLastError)
		)

		$Types = $FunctionDefinitions | Add-Win32Type -Module $Mod -Namespace 'Win32MemUtils'
		$Kernel32 = $Types['kernel32']

		# Get handle to the process
		$hProcess = $Kernel32::OpenProcess(0x400, $False, $ProcessID) # PROCESS_QUERY_INFORMATION (0x00000400)

		if (-not $hProcess) {
			throw "Unable to get a process handle for process ID: $ProcessID"
		}

		$MemoryInfo = New-Object $MEMORY_BASIC_INFORMATION
		$BytesRead = $Kernel32::VirtualQueryEx($hProcess, $ModuleBaseAddress, [Ref] $MemoryInfo, $PageSize)

		$null = $Kernel32::CloseHandle($hProcess)

		$Fields = @{
			BaseAddress = $MemoryInfo.BaseAddress
			AllocationBase = $MemoryInfo.AllocationBase
			AllocationProtect = $MemoryInfo.AllocationProtect
			RegionSize = $MemoryInfo.RegionSize
			State = $MemoryInfo.State
			Protect = $MemoryInfo.Protect
			Type = $MemoryInfo.Type
		}

		$Result = New-Object PSObject -Property $Fields
		$Result.PSObject.TypeNames.Insert(0, 'MEM.INFO')

		$Result
	}
	
	#endregion Add Dependency Functions
	
	$Mod = New-InMemoryModule -ModuleName ProcessStrings

	$FunctionDefinitions = @(
		(func kernel32 OpenProcess ([IntPtr]) @([UInt32], [Bool], [UInt32]) -SetLastError),
		(func kernel32 ReadProcessMemory ([Bool]) @([IntPtr], [IntPtr], [Byte[]], [Int], [Int].MakeByRefType()) -SetLastError),
		(func kernel32 CloseHandle ([Bool]) @([IntPtr]) -SetLastError)
	)

	$Types = $FunctionDefinitions | Add-Win32Type -Module $Mod -Namespace 'Win32ProcessStrings'
	$Kernel32 = $Types['kernel32']
} PROCESS {
	$hProcess = $Kernel32::OpenProcess(0x10, $False, $ProcessID) # PROCESS_VM_READ (0x00000010)

	Get-ProcessMemoryInfo -ProcessID $ProcessID | Where-Object { $_.State -eq 'MEM_COMMIT' } | ForEach-Object {
		$Allocation = $_
		$ReadAllocation = $True
		if (($Allocation.Type -eq 'MEM_IMAGE') -and (-not $IncludeImages)) {
			$ReadAllocation = $False
		}
		# Do not attempt to read guard pages
		if ($Allocation.Protect.ToString().Contains('PAGE_GUARD')) {
			$ReadAllocation = $False
		}

		if ($ReadAllocation) {
			$Bytes = New-Object Byte[]($Allocation.RegionSize)

			$BytesRead = 0
			$Result = $Kernel32::ReadProcessMemory($hProcess, $Allocation.BaseAddress, $Bytes, $Allocation.RegionSize, [Ref] $BytesRead)

			if ((-not $Result) -or ($BytesRead -ne $Allocation.RegionSize)) {
				Write-Warning "Unable to read 0x$($Allocation.BaseAddress.ToString('X16')) from PID $ProcessID. Size: 0x$($Allocation.RegionSize.ToString('X8'))"
			} else {
				# This hack will get the raw ascii chars. The System.Text.UnicodeEncoding object will replace some unprintable chars with question marks.
				$ArrayPtr = [Runtime.InteropServices.Marshal]::UnsafeAddrOfPinnedArrayElement($Bytes, 0)
				$RawString = [Runtime.InteropServices.Marshal]::PtrToStringAnsi($ArrayPtr, $Bytes.Length)
				$Regex = [Regex] "[\x20-\x7E]{$MinimumLength,}"
				$Regex.Matches($RawString) | ForEach-Object {
					$_.Value
				}

				$Encoder = New-Object System.Text.UnicodeEncoding
				$RawString = $Encoder.GetString($Bytes, 0, $Bytes.Length)
				$Regex = [Regex] "[\u0020-\u007E]{$MinimumLength,}"
				$Regex.Matches($RawString) | ForEach-Object {
					$_.Value
				}
			}
		$Bytes = $null
		}
	}
	$null = $Kernel32::CloseHandle($hProcess)
} END {}