<#

.SYNOPSIS
    Plugin-Name: Collect-NetworkRoutes.ps1
    
.Description

    Collects network routing information from remote hosts 

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

    # Get Routing Information

    try {

        Get-NetRoute

    } catch { 

        Write-Warning "Could not collect network route information."

    }
}