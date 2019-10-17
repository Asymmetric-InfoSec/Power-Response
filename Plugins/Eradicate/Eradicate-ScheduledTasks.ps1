<#

.SYNOPSIS
    Plugin-Name: Eradicate-ScheduledTasks.ps1
    
.Description
    This plugin allows for incident responders to eradicate scheduled tasks from
    known compromised systems. This plugin can take an explicit list of
    paths or a CSV list of different paths to eradicate from the 
    target machines.

    Note: If using a CSV of paths, the header must be 'ScheduledTask'

.EXAMPLE

    Power-Response Execution

    Set ComputerName Test-PC
    Set ScheduledTask MaliciousTask
    Run

    Set ComputerName Test-PC
    Set PathList C:\Tools\MaliciousTasks.csv
    Run

.NOTES
    Author: Drew Schmitt
    Date Created: 10/17/2019
    Twitter: @5ynax
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

[cmdletbinding(DefaultParameterSetName="ScheduledTask")]

param (

    [Parameter(ParameterSetName="ScheduledTask",Mandatory=$true,Position=0)]
    [String[]]$ScheduledTask,

    [Parameter(ParameterSetName="ScheduledTaskList",Mandatory=$true,Position=0)]
    [String]$ScheduledTaskList,

    [Parameter(ParameterSetName="ScheduledTask",Mandatory=$false,Position=1)]
    [Parameter(ParameterSetName="ScheduledTaskList",Mandatory=$false,Position=1)]
    [String]$TaskPath = '\*',

    [Parameter(ParameterSetName="ScheduledTask",Mandatory=$true,Position=2)]
    [Parameter(ParameterSetName="ScheduledTaskList",Mandatory=$true,Position=2)]
    [String]$EradicateName,

    [Parameter(ParameterSetName="ScheduledTask",Mandatory=$true,Position=3)]
    [Parameter(ParameterSetName="ScheduledTaskList",Mandatory=$true,Position=3)]
    [System.Management.Automation.Runspaces.PSSession[]]$Session

)

process { 

    $Output = ('{0}\{1}' -f (Get-PRPath -Output),$EradicateName)

    #Get seconds for unique naming
    $Seconds = (Get-Date -UFormat %s).Split('.')[0]

    #Create output directory if needed
    if (!(Test-Path $Output)){

       $null = New-Item -Type Directory -Path $Output
    }

    switch ($PSCmdlet.ParameterSetName){

        "ScheduledTask" {[String[]]$ScheduledTasks = $ScheduledTask}
        "ScheduledTaskList"{[String[]]$ScheduledTasks = (Import-CSV -Path $ScheduledTaskList | Select-Object -ExpandProperty 'ScheduledTask')}

    }

     foreach ($ScheduledTaskItem in $ScheduledTasks) {

        $Scriptblock = {

            #Test for scheduled tasks cmdlet support (Win 7 does not have these cmdlets)
            $CmdletTest = Get-Command 'Get-ScheduledTask' -ErrorAction SilentlyContinue

            if ($CmdletTest) {

                try {

                    $ScheduledTaskInfo = Get-ScheduledTask -TaskName $Using:ScheduledTaskItem -TaskPath $Using:TaskPath -ErrorAction Stop
                    $null = Stop-ScheduledTask -TaskName $Using:ScheduledTaskItem
                    $null = Unregister-ScheduledTask -TaskName $Using:ScheduledTaskItem -Confirm:$false
                    $Outhash = @{ Host=$ENV:ComputerName; Eradicated=$true; Task=$ScheduledTaskInfo.TaskName; Path=$ScheduledTaskInfo.TaskPath; TaskAction=$ScheduledTaskInfo.Actions.Execute; Notes='' }

                } catch {

                    $Outhash = @{ Host=$ENV:ComputerName; Eradicated=$false; Task=$Using:ScheduledTaskItem; Path=''; TaskAction=''; Notes='There was a problem stopping or unregistering the scheduled task' }

                }
            }

            if (!CmdletTest) {

                try {
                    $Path = (('C:\Windows\System32\Tasks\{0}' -f $Using:TaskPath) -Replace '\\\\','\' -Replace '\*','')
                    $null = Get-ChildItem -Path $Path -Recurse -File -Force -Include "*$Using:ScheduledTaskItem" -ErrorAction Stop | Remove-Item -Force -ErrorAction Stop
                    $Outhash = @{ Host=$ENV:ComputerName; Eradicated=$true; Task=$Using:ScheduledTaskItem; Path=''; TaskAction=''; Notes='Scheduled Task file removed manually' }

                } catch {

                    $Outhash = @{ Host=$ENV:ComputerName; Eradicated=$false; Task=$Using:ScheduledTaskItem; Path=''; TaskAction=''; Notes='There was a problem manually removing the scheduled task file' }

                }
            }

            return [PSCustomObject]$Outhash | Select Host, Eradicated, Task, Path, TaskAction, Notes
        }

        #Generate output from data collected 
        $OutputPath = ('{0}\Scope_{1}_{2}.csv' -f $Output,$ScheduledTaskItem,$Seconds)
        Invoke-Command -Session $Session -ScriptBlock $ScriptBlock | Export-CSV -Path $OutputPath -Append -NoTypeInformation
    }
} 
