<#

.SYNOPSIS
    Plugin-Name: Collect-ScheduledTaskDetails.ps1
    
.Description
    Collects scheduled task details from the remote host (run times, last task result, etc.). This plugin
    does not collect the scheduled task files themselves

    To collect the scheduled task configuration files use the Collect-ScheduledTasks
    plugin.

.EXAMPLE

    Power-Response Execution

    Set ComputerName Test-PC
    Run

.NOTES
    Author: Drew Schmitt
    Date Created: 07/03/2019
    Twitter: @5ynax
    
    Last Modified By: 
    Last Modified Date: 
    Twitter:
  
#>

param (

    )

process{

    #Get Scheduled Task Information (Will be successful on Windows 10 only)

    try {

        Get-ScheduledTask | Get-ScheduledTaskInfo | Select LastRuntime, NextRunTime, TaskName, TaskPath, LastTaskResult, NumberOfMissedRuns
    
    } catch {

        Write-Warning "Could not collect scheduled task info."
    }
}