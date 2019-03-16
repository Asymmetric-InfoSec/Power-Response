<#

.SYNOPSIS
    Plugin-Name: Collect-DNSCache.ps1
    
.Description

    Collects DNS Cache details from remote hosts

.EXAMPLE

    Stand Alone Execution:

    .\Collect-DNSCache.ps1 -ComputerName Test-PC

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

        # Get-DNSClientCache

        $ScriptBlock_DNSClientCache = $ExecutionContext.InvokeCommand.NewScriptBlock('Get-DNSClientCache')
    
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock_DNSClientCache -SessionOption (New-PSSessionOption -NoMachineProfile)

    }
}