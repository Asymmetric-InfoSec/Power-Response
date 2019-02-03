<#

.SYNOPSIS
    Plugin-Name: Collect-Services
    
.Description

    Collects service information for the remote host

.EXAMPLE

    Stand Alone Execution:

    .\Collect-Services.ps1 -ComputerName Test-CS

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

    [Parameter(Mandatory=$true,Position=0)]
    [string[]]$ComputerName

    )

process{

    foreach ($Computer in $ComputerName) {

        # Get Service Paths via WMI Object
        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock('Get-CimInstance win32_service | Select ProcessID, Name, DisplayName, Pathname, ServiceType, StartMode, Status')
    
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock

    }

}