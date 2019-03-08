<#

.SYNOPSIS
    Plugin-Name: Collect-ScheduledTasks.ps1
    
.Description
    This plugin is used to collect scheduled task configuration files from
    a remote host. By default, the plugin will recursively copy all files from
    C:\Windows\System32\Tasks, however, the plugin can also perform targeted
    extraction by specifying a scheduled task name using the -TaskName parameter

.EXAMPLE

    Stand Alone Execution

    .\Collect-ScheduledTasks.ps1 -ComputerName Test-PC

    Power-Response Execution

    Set ComputerName Test-PC
    Run

    OR

    Set ComputerName Test-PC
    Set TaskName TestTask
    Run

.NOTES
    Author: Drew Schmitt
    Date Created: 2/8/2019
    Twitter: @5ynax
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param (

    [Parameter(Mandatory=$true,Position=0)]
    [string[]]$ComputerName,
    [Parameter(Mandatory=$false,Position=1)]
    [string]$TaskName

    )

process{

    # Set $Output for where to store recovered scheduled task files
    $Output= ("{0}\ScheduledTasks" -f $global:PowerResponse.OutputPath)

    # Create Subdirectory in $global:PowerResponse.OutputPath for storing scheduled tasks
    If (-not (Test-Path $Output)) {
        New-Item -Type Directory -Path $Output | Out-Null
    }   

    foreach ($Computer in $ComputerName) {

        # Create session on remote host
        $Session = New-PSSession -ComputerName "$Computer" -SessionOption (New-PSSessionOption -NoMachineProfile)

        if ($TaskName){

             # Copy specified task into $Output
            Copy-Item "C:\Windows\System32\Tasks\$TaskName" -Destination "$Output\" -FromSession $Session -Force -ErrorAction SilentlyContinue

        } else {

            # Recursively copy directory contents into $Output
            Copy-Item "C:\Windows\System32\Tasks\" -Recurse -Destination "$Output\" -FromSession $Session -Force -ErrorAction SilentlyContinue


        }

        #Close PS Remoting Session
        $Session | Remove-PSSession
    
    }

}