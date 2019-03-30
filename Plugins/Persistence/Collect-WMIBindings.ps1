<#

.SYNOPSIS
    Plugin-Name: Collect-WMIBindings.ps1
    
.Description
    This plugin collects WMI event bindigs from a remote 
    machine.

.EXAMPLE

    Power-Response Execution

    Set ComputerName Test-PC
    Run

.NOTES
    Author: Drew Schmitt
    Date Created: 2/9/2019
    Twitter: @5ynax
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param (

    )

process{

    # Collect WMI Event to Consumer Bindings
    Get-WMIObject -Namespace root\Subscription -Class __FilterToConsumerBinding

}