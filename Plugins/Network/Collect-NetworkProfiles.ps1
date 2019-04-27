<#

.SYNOPSIS
    Plugin-Name: Collect-NetworkProfiles.ps1
    
.Description

    Collects network profile information from remote hosts

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

    # Get Network Connection Profile(s)

    try {

        Get-NetConnectionProfile

    } catch {

        Write-Warning "Could not collection Net Connection information."
    }
}