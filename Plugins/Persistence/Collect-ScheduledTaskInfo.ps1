<#

.SYNOPSIS
    Plugin-Name: Collect-ScheduledTaskInfo.ps1
    
.Description
    Collects scheduled task information from the remote host. This plugin
    does not collect the scheduled task files themselves

    To collect the scheduled task configuration files use the Collect-ScheduledTasks
    plugin.

.EXAMPLE

    Stand Alone Execution:

    .\Collect-ScheduledTaskInfo.ps1 -ComputerName Test-PC

    Power-Response Execution

    Set ComputerName Test-PC
    Run

.NOTES
    Author: Drew Schmitt
    Date Created: 2/8/2019
    Twitter: @%ynax
    
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

        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock("Get-ScheduledTask | Get-ScheduledTaskInfo | Select LastRuntime, NextRunTime, TaskName, TaskPath, LastTaskResult, NumberOfMissedRuns")
    
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock

    }

}