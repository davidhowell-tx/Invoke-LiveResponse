
# Modules

Modules are standalone PowerShell scripts that, when run alone, returns specific results back from the system.

For example, if I were to run the Get-Netstat.ps1 script, it should return a list of listening ports and network connections.

## Output Type

The best modules collect information and format it within a Custom PowerShell Object. When returned, these custom objects are easy to format, and thusly easy to analyze.

You can create a new custom object like so:
$TempObject = New-Object PSObject

You can add fields to the object like so:
$TempObect | Add-Member -MemberType NoteProperty -Name NAMEOFFIELD -Value VALUE


# Field Standardization

In order for analysis scripts to be able to perform propertly, the field names used in the results need to be consistent. For example, when considering files and processes and time there can be multiply categories, such as execution time, or created time, written time, etc.
If all time fields are stored as "time" it will be more difficult to analyze the time fields on the spot and place them in the corrrect category. Below are suggested values, but these are not always appropriate.

## Times
Times are a tricky subject. There are a number of different formats in which times are returned. In PowerShell it is best to stick to formats that can be bound to a DateTime object. In regards to analysis of results in a CSV file, it is best to output the date/time in a sortable format.

### Converting to a DateTime Object
You can convert a normal string into a DateTime object if it is in the correct format. This can be done by setting the string to a variable and forcing the DateTime object, like so:
[DateTime]$TempDateTimeObject = "08/30/2007"

Here is a list of known working formats:
#### Known working formats
* MM/dd/yyyy
  * defaults the time field to 00:00:00
* MM/dd/yyyy hh:mm
  * defaults the seconds field to 00
* MM/dd/yyyy hh:mm:ss
* yyyy/MM/dd
  * defaults the time field to 00:00:00
* yyyy/MM/dd hh:mm
  * defaults the seconds field to 00
* yyyy/MM/dd hh:mm:ss

##### Abbreviations
MM - 2 digit month
dd - 2 digit day
yyyy - 4 digit year
hh - 2 digit hours
mm - 2 digit minutes
ss - 2 digit seconds

### Convert Windows FileTime to DateTime Object:

Windows often stores timestamps in an Unsigned 64-bit integer. 

[DateTime]::FromFileTime(130927855875955286)

### Convert DateTime object to sortable time
Once you have a DateTime object, you want to format the output of the datetime into a sortable string. This will make it optimal for analysis in a CSV file.

You can use the builtin format string "s" to convert to a sortable date and time.  This will put the date in the format yyyy-MM-ddThh:mm:ss
[DateTime]$DateTimeVariable.ToString("s")

### Convert DateTime object to UTC time and format as sortable
By default, PowerShell converts DateTime objects to the timezone set on your computer.  For standardization purposes you may want to convert times to UTC.  
You can use the datetime object to do this, and use the format string "u". This will put the date in the format yyyy-MM-ddThh:mm:ssZ
[DateTime]$DateTimeVariable.ToUniversalTime().ToString("u")

## Files, Processes and Times
| Field Name    | Field Desecription              | Example Values |
| ------------- | ------------------------------- | -------------- |
| file_name     | name of the file or process     | explorer.exe   |
| file_path     | path to the file or process     | C:\Windows     |
| time_created  | time the file was created       | 2015-08-30T11:20:24Z |
| time_accessed | a time the file was accessed    | 2015-08-30T11:20:24Z |
| time_written  | a time the file was written     | 2015-08-30T11:20:24Z |
| time_executed | a time the file was executed    | 2015-08-30T11:20:24Z |
| process_id    | the process ID for the executing process |             |
| md5           | md5 hash of the file/process    | 332FEAB1435662FC6C672E25BEB37BE3 |
| sha1          | sha1 hash of the file/process   | 5A49D7390EE87519B9D69D3E4AA66CA066CC8255 |
| sha256        | sha256 hash of the file/process | 6BED1A3A956A859EF4420FEB2466C040800EAF01EF53214EF9DAB53AEFF1CFF0 |

## Network Connections
| Field Name | Field Description                        | Example Values |
| ---------- | ---------------------------------------- | -------------- |
| src_ip     | source ip address of the connection      | 192.168.100.54 |
| src_port   | source port of the connection            | 52394 |
| dest_ip    | destination ip address of the connection | 74.125.127.99 |
| dest_port  | destination port of the connection       | 443 |
| protocol   | protocol used for the connection         | TCP, UDP, HTTP |
| status     | status of the network connection         | Established, Listening, close_wait, time_wait |

# Log Entries
| Field Name     | Field Description              | Example Values |
| -------------- | ------------------------------ | -------------- |
| time_generated | the time the log was generated |                |
| event_id       | the id number of the event     |                |

## Generic Fields
| Field Name   | Field Description        | Example Values |
| ------------ | ------------------------ | -------------- |
| username     | user's logon name        |                |
| computername | hostname of the computer |                | 