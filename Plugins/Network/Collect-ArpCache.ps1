<#

.SYNOPSIS
    Plugin-Name: Collect-ArpCache.ps1
    
.Description

    Collects arp cache information from remote hosts 

.EXAMPLE

    Power-Response Execution:

    Set ComputerName Test-PC
    Run

.NOTES
    Author: Drew Schmitt
    Date Created: 3/16/2019
    Twitter: @5ynax
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param (

    
    )

process {

    # Get ARP Information - Win 10 Cmdlet
    try {

        Get-NetNeighbor

    } catch {

        Write-Warning "Arp Cache information could not be collected."
    }
    

}
