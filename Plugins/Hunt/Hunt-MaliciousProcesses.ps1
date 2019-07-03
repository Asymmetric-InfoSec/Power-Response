<#

.SYNOPSIS
    Plugin-Name: Hunt-MaliciousProcesses.ps1
    
.Description

    Hunts for malicious processes and performs analysis to discover anomalies

.EXAMPLE

    Set ComputerName <list of computers>
    Set HuntName ProcessesHunt
    Run

.NOTES
    Author: Drew Schmitt
    Date Created: 07-03-2019
    Twitter: 
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param (
    [Parameter(Mandatory=$true,Position=0)]
    [System.Management.Automation.Runspaces.PSSession[]]$Session,

    [Parameter(Mandatory=$true,Position=1)]
    [String]$HuntName
)

process {
    
    Invoke-PRPlugin -Name 'Collect-Processes' -Session $Session -HuntName $HuntName
}
