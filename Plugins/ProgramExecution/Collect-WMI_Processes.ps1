<#

.SYNOPSIS
    Plugin-Name: Collect-WMI_Processes
    
.Description

    Collects processes from a remote machine for analysis using the Get-WMIObject win32_process class.

.EXAMPLE

    Stand Alone Execution:

    .\Collect-WMI_Processes.ps1 -ComputerName Test-PC
    
    Power-Response Exection:

    Set ComputerName Test-PC
    Run

.NOTES
    Author: Drew Schmitt
    Date Created: 2/2/2019
    Twitter: 
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param (

    [Parameter(Mandatory=$true,Position=0)]
    [string[]]$ComputerName

    )

process {

    foreach ($Computer in $ComputerName) {

    #Run command on the remote host and collect process data
    $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock('Get-WmiObject win32_process | Select ParentProcessID, ProcessID, SessionID, Name, ExecutablePath, Commandline, ThreadCount, Handle, Handlecount')
    
    Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock

    }

}