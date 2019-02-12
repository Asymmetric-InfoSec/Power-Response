<#

.SYNOPSIS
    Plugin-Name: Collect-SystemInfo.ps1
    
.Description

    Collects important system information for a remote host using the Get-ComputerInfo
    PowerShell CMDLET

.EXAMPLE

    Stand Alone Execution

    .\Collect-SystemInfo.ps1 -ComputerName Test-PC

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

    [Parameter(Mandatory=$true,Position=0)]
    [string[]]$ComputerName

    )

process{

    foreach ($Computer in $ComputerName) {

        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock("Get-ComputerInfo | Select CsName, CsDNSHostName, CsPartOfDomain, CsDomain, LogonServer, OsArchitecture, CsProcessors, CsNumberofProcessors, CsNumberofLogicalProcessors, CsPhysicallyInstalledMemory, CstotalPhysicalMemory, OsName, WindowsCurrentVersion, OsVersion, WindowsVersion, OsBuildNumber, OsServicePackMajorVersion, OsServicePackMinorVersion, WindowsInstallDateFromRegistry, OsCountryCode, OsLocalDateTime, OsLocale, TimeZone, OsBootDevice, OsSystemDrive, WindowsSystemRoot, OsUptime, HyperVisorPresent, DeviceGuardServicesRunning, CSManufacturer, CsModel")

        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock

    }


}