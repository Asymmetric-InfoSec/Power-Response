<#

.SYNOPSIS
    Plugin-Name: Collect-SystemInfo.ps1
    
.Description

    Collects important system information for a remote host using the Get-ComputerInfo
    PowerShell CMDLET

.EXAMPLE

    Power-Response Execution

    Set ComputerName Test-PC
    Run

.NOTES
    Author: Drew Schmitt
    Date Created: 2/8/2019
    Twitter: @5ynax
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param (

    )

process{

    #Gets system information for remote host 
    
    Get-ComputerInfo | Select CsName, CsDNSHostName, CsPartOfDomain, CsDomain, LogonServer, OsArchitecture, CsProcessors, CsNumberofProcessors, CsNumberofLogicalProcessors, CsPhysicallyInstalledMemory, CstotalPhysicalMemory, OsName, WindowsCurrentVersion, OsVersion, WindowsVersion, OsBuildNumber, OsServicePackMajorVersion, OsServicePackMinorVersion, WindowsInstallDateFromRegistry, OsCountryCode, OsLocalDateTime, OsLocale, TimeZone, OsBootDevice, OsSystemDrive, WindowsSystemRoot, OsUptime, HyperVisorPresent, DeviceGuardServicesRunning, CSManufacturer, CsModel

}