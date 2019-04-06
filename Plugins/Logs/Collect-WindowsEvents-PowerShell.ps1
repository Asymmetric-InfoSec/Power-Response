<#

.SYNOPSIS
    Plugin-Name: Collect-WindowsEvents-PowerShell.ps1
    
.Description
    This plugin retrieves Windows event log entries based on the list of entries located
    in the body of the script. Events that are not interesting can be ignored by 
    commenting them out. Additional event types can be added to the list. The desired 
    output for this plugin is CSV so that the events can be analyzed using filters.
    Event IDs were gathered from multiple sources and some may not be relevant in all
    scenarios. Make sure to validate the event IDs that you will be collecting.

    Note: This plugin is designed for Windows Vista and Higher. Event IDs may be 
    Different for XP and Server 2003 machines. I did my best to add in details on what
    each event is for ease of tuning.

    Note: If you plan to use this plugin with all event logs enabled there will be noise.
    I would recommend tuning the event logs lists below to make sure they are applicable
    to your scenario. Running this wide open is not a bad idea, but may be more difficult 
    for newer analysts to quickly sift through the contents. I would recommend running,
    finding a pivot point, and then search for events around your pivot point.

.EXAMPLE
    .\Collect-WindowsEvents-PowerShell.ps1 -ComputerName Test-PC -StartDate 12/23/2018

    Power-Response Execution

    Set ComputerName Test-PC
    Set StartDate 12/23/2018 
    Run

.NOTES
    Author: Drew Schmitt
    Date Created: 03/05/2018
    Twitter:  @5ynax
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param (

    )

process {

    $StartDate=(Get-Date).AddDays(-90)

    #PowerShell Event Log IDs to Retrieve (Microsoft-Windows-PowerShell/Operational.evtx)
    $PowerShellEvents = @(

            4104, #Script contents
            4105, #Script start
            4106  #Script stop

        )

    #Get Windows PowerShell Event Logs
    Get-WinEvent -FilterHashTable @{LogName="Microsoft-Windows-PowerShell/Operational"; StartTime=$StartDate; ID=$PowerShellEvents} -ErrorAction SilentlyContinue

}