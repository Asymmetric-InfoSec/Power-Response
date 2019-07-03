<#

.SYNOPSIS
    Plugin-Name: Collect-ScheduledTaskInfo.ps1
    
.Description
    Collects scheduled task information from the remote host. This plugin
    does not collect the scheduled task files themselves

    To collect the scheduled task configuration files use the Collect-ScheduledTasks
    plugin.

.EXAMPLE

    Power-Response Execution

    Set ComputerName Test-PC
    Run

.NOTES
    Author: Drew Schmitt
    Date Created: 2/8/2019
    Twitter: @5ynax
    
    Last Modified By: Drew Schmitt
    Last Modified Date: 7/3/2019
    Twitter: @5ynax
  
#>

param (

    )

process{

    #Get Scheduled Task Information (Will be successful on Windows 10 only)

    try {

        $Tasks = Get-ScheduledTask

        foreach ($Task in $Tasks) {

            $TaskInfo = @{

                Date = $Task.Date
                Enabled = $Task.Settings.Enabled
                HiddenTask = $Task.Settings.Hidden
                TaskName = $Task.TaskName
                Author = $Task.Author
                Description = $Task.Description
                TaskPath = $Task.TaskPath
                URI = $Task.URI
                Execute = $Task.Actions.Execute
                Arguments = $Task.Actions.Arguments
                Principal = $Task.Principal.DisplayName
                PrincipalId = $Task.Principal.Id
                LogonType = $Task.Principal.LogonType
                UserId = $Task.Principal.UserId
                SidType = $Task.Principal.ProcessTokenSidType
                RequiredPrivilege = $Task.Principal.RequiredPrivilege
                AllowDemandStart = $Task.Settings.AllowDemandStart
                RunOnlyIfIdle = $Task.Settings.RunOnlyIfIdle
                RunOnlyIfNetworkAvailable = $Task.Settings.RunOnlyIfNetworkAvailable
                WakeToRun = $Task.Settings.WakeToRun
                Version = $Task.Version

            }

            [PSCustomObject]$TaskInfo | Select Date,Enabled,HiddenTask,TaskName,Version,Author,Description,TaskPAth,URI,Execute,Arguments,Principal,PrincipalId,LogonType,UserId,SidType,RequiredPrivilege,AllowDemandStart,RunOnlyIfIdle,RunOnlyIfNetworkAvailable,WakeToRun

        }
    
    } catch {

        Write-Warning "Could not collect scheduled task info."
    }
}