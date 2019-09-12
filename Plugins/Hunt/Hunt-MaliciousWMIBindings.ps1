<#

.SYNOPSIS
    Plugin-Name: Hunt-MaliciousWMIBindings.ps1
    
.Description

    Hunts for malicious WMI bindings and performs analysis to discover anomalies

.EXAMPLE

    Set ComputerName <list of computers>
    Set HuntName WMIBindingsHunt
    Run

.NOTES
    Author: Drew Schmitt
    Date Created: 07/03/2019
    Twitter: @5ynax
    
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
    
    Invoke-PRPlugin -Name 'Collect-WMIBindings' -Session $Session -HuntName $HuntName
}