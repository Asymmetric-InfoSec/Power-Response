<#

.SYNOPSIS
    Plugin-Name: Check-Status.ps1
    
.Description
    This plugin provides an easy method of verifying if a machine or several 
    machines are online prior to beginning your investigation. The ComputerName 
    parameter will accept a string or string array value containing machines
    to be checked and verified as being online.

.EXAMPLE

    .\Check-Status -ComputerName Test-PC

    Power-Response Execution

    Set ComputerName Test-PC
    run

.NOTES
    Author: 5yn@x
    Date Created: 12/28/2018
    Twitter: @5ynax
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param (

    [Parameter(Mandatory=$true,Position=0)]
    [string[]]$ComputerName

    )

process{

    foreach ($Computer in $ComputerName) {

        if (-not (Test-Connection -ComputerName $Computer -Count 1 -Quiet)) {
        
            Write-Error ("{0} appears to be offline" -f $Computer)

        } else {

            Write-Host ("{0} is online and ready for data collection" -f $Computer) -Foregroundcolor Green

        }

    }

}