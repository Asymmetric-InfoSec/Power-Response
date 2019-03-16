<#

.SYNOPSIS
    Plugin-Name: Collect-InterfaceDetails.ps1
    
.Description

    Collects network interface details from remote hosts

.EXAMPLE

    Stand Alone Execution:

    .\Collect-InterfaceDetails.ps1 -ComputerName Test-PC

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

        # Get Interface Information

        $ScriptBlock_NetConfig = $ExecutionContext.InvokeCommand.NewScriptBlock('Get-NetIPConfiguration')
    
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock_NetConfig -SessionOption (New-PSSessionOption -NoMachineProfile)

    }
}