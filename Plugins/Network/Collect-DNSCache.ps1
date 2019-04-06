<#

.SYNOPSIS
    Plugin-Name: Collect-DNSCache.ps1
    
.Description

    Collects DNS Cache details from remote hosts

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

    # Get-DNSClientCache

    Get-DNSClientCache

}