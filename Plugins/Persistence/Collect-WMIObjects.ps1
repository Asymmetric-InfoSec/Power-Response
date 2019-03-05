<#

.SYNOPSIS
    Plugin-Name: Collect-WMIObjects.ps1
    
.Description
    This plugin collects WMI event filters, consumers, and bindigs for a remote 
    machine.

.EXAMPLE

    Stand Alone Execution

    .\Collect-WMIObjects.ps1 -ComputerName Test-PC

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

    [Parameter(Mandatory=$true,Position=0)]
    [string[]]$ComputerName

    )

process{


    #Loop through machines in $ComputerName to obtain data for each machine (if multiple machines are specified)
    foreach ($Computer in $ComputerName) {

        # Collect WMI Event Filters
        $ScriptBlock_Filter = $ExecutionContext.InvokeCommand.NewScriptBlock("Get-WMIObject -Namespace root\Subscription -Class __EventFilter")
    
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock_Filter | Out-PRFile -Append Filters

        # Collect WMI Event Consumers
        $ScriptBlock_Consumer = $ExecutionContext.InvokeCommand.NewScriptBlock("Get-WMIObject -Namespace root\Subscription -Class __EventConsumer")
    
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock_Consumer | Out-PRFile -Append Consumers

        # Collect WMI Event to Consumer Bindings
        $ScriptBlock_Binding = $ExecutionContext.InvokeCommand.NewScriptBlock("Get-WMIObject -Namespace root\Subscription -Class __FilterToConsumerBinding")
    
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock_Binding | Out-PRFile -Append Bindings


    }


}