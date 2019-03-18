<#

.SYNOPSIS
    Plugin-Name: Collect-NetworkRoutes.ps1
    
.Description

    Collects network routing information from remote hosts 

.EXAMPLE

    Stand Alone Execution:

    .\Collect-NetworkRoutes.ps1 -ComputerName Test-PC

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

    [Parameter(Mandatory=$true,Position=0)]
    [string[]]$ComputerName

    )

process {

    foreach ($Computer in $ComputerName) {

        # Get Routing Information

        $ScriptBlock_Route = $ExecutionContext.InvokeCommand.NewScriptBlock('Get-NetRoute')
    
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock_Route -SessionOption (New-PSSessionOption -NoMachineProfile)

    }
}