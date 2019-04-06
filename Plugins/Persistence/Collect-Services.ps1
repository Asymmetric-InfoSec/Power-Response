<#

.SYNOPSIS
    Plugin-Name: Collect-Services.ps1
    
.Description

    Collects service information for the remote host

.EXAMPLE

    Power-Response Execution

    Set ComputerName Test-PC
    Run

.NOTES
    Author: Drew Schmitt
    Date Created: 2/2/2019
    Twitter: @5ynax
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param (

    )

process{

    # Get Service Paths via WMI Object
    Get-CimInstance win32_service | Select ProcessID, Name, DisplayName, Pathname, ServiceType, StartMode, Status

}