<#

.SYNOPSIS
    Plugin-Name: Collect-Process_Dlls
    
.Description

    Gets modules (processes and dlls) currently being used on the remote machine and includes path

.EXAMPLE

    Stand Alone:

    .\Collect-Process_Dlls -ComputerName Test-PC

    Power-Response:

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

    [Parameter(Mandatory=$true,Position=0)]
    [string[]]$ComputerName

    )

process{

    foreach ($Computer in $ComputerName) {

        #Run Autorunsc on the remote host and collect ASEP data
        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock('(Get-Process).Modules')
    
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock


    }


}