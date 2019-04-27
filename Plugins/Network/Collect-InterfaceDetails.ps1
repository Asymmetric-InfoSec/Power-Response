<#

.SYNOPSIS
    Plugin-Name: Collect-InterfaceDetails.ps1
    
.Description

    Collects network interface details from remote hosts

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

    # Get Interface Information - Win 10 Cmdlet

    try {

        Get-NetIPConfiguration

    } catch {

        Write-Warning "Interface Details could not be collected."
    }

    

}