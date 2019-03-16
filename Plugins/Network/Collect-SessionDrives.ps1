<#

.SYNOPSIS
    Plugin-Name: Collect-SessionDrives.ps1
    
.Description

    Collects mounted drive and share information from remote hosts 

.EXAMPLE

    Stand Alone Execution:

    .\Collect-SessionDrives.ps1 -ComputerName Test-PC

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

        # Get Share Information

        $ScriptBlock_PSDrive = $ExecutionContext.InvokeCommand.NewScriptBlock('Get-PSDrive')
    
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock_PSDrive -SessionOption (New-PSSessionOption -NoMachineProfile)

    }
}