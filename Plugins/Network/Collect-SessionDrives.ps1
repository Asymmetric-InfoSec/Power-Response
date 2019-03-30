<#

.SYNOPSIS
    Plugin-Name: Collect-SessionDrives.ps1
    
.Description

    Collects mounted drive and share information from remote hosts 

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

    # Get Share Information

    Get-PSDrive | Select Name, Provider, Root, Description, Used, Free, PSComputerName

}