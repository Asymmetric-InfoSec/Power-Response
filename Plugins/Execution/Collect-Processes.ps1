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
    
    Last Modified By: Gavin Prentice
    Last Modified Date: 3/28/2019
    Twitter: @valrkey
  
#>

param (


    )

process {

    # Collect process data
    Get-WmiObject win32_process | Select ParentProcessID, ProcessID, SessionID, Name, ExecutablePath, Commandline, ThreadCount, Handle, Handlecount
    

}