<#

.SYNOPSIS
    Plugin-Name: Collect-StartupList
    
.Description
    This plugin collects all startup items from the remote host for analysis.

.EXAMPLE
    Stand Alone Execution

    .\Collect-StartupList.ps1 -ComputerName Test-PC

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

    [Parameter(Mandatory=$true,Position=0)]
    [string[]]$ComputerName

    )

process{


    foreach ($Computer in $ComputerName) {

        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock("Get-CimInstance Win32_StartupCommand")
    
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock

    }
}