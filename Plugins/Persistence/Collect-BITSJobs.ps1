<#

.SYNOPSIS
    Plugin-Name: Collect-BITSJobs.ps1
    
.Description
    Collects BITS jobs details for all users on the machine to
    determine if BITS jobs are being used for persistence or as
    part of additional compromise.

.EXAMPLE

    Power-Response Execution

    Set ComputerName Test-PC
    Run

.NOTES
    Author: Drew Schmitt
    Date Created: 09/03/2019
    Twitter: @5ynax
    
    Last Modified By: 
    Last Modified Date: 
    Twitter:
  
#>

param (

    )

process{

    #Get BITS Jobs information for all users (Will be successful on Windows 10 only)

    try {

        Get-BitsTransfer -AllUsers | Select *
    
    } catch {

        Write-Warning "Could not collect BITS Jobs Info."
    }
}