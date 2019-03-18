<#

.SYNOPSIS
    Plugin-Name: Collect-NetworkProfiles.ps1
    
.Description

    Collects network profile information from remote hosts

.EXAMPLE

    Stand Alone Execution:

    .\Collect-NetworkProfiles.ps1 -ComputerName Test-PC

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

        # Get Network Connection Profile(s)

        $ScriptBlock_NetProfile = $ExecutionContext.InvokeCommand.NewScriptBlock('Get-NetConnectionProfile')
    
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock_NetProfile -SessionOption (New-PSSessionOption -NoMachineProfile)

    }
}