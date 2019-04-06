<#

.SYNOPSIS
    Plugin-Name: Collect-StartupList.ps1
    
.Description
    This plugin collects all startup items from the remote host for analysis.

.EXAMPLE

    Power-Response Execution

    set ComputerName Test-PC
    run

.NOTES
    Author: Drew Schmitt
    Date Created: 3/2/2019
    Twitter: @5ynax
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param (

    )

process{

    # Get Startup List on remote host

    Get-CimInstance Win32_StartupCommand
    
}