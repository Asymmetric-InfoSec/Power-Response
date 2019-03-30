<#

.SYNOPSIS
    Plugin-Name: Collect-WindowsEvents-System.ps1
    
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

    [DateTime]$StartDate=(Get-Date).AddDays(-90)

    #System Event Log IDs to Retrieve (System)
    $SystemEvents = @(

            10000,
            10001,
            1001,  #Windows Error Reporting (May be noisy)
            10100,
            104,   #Audit Log Cleared
            1056,  #DHCP credentials not configured
            20001, #Device installation
            20002,
            20003,
            24576, #Successful driver installation
            24577, #Encryption of volume started
            24579, #Encryption of volume completed
            7030,  #A service was marked as an interactive service
            7034,  #Service crashed unexpectedly
            7035,  #Service sent a start/stop control
            7036,  #Service started or stopped
            7040,  #Service start type changed (Boot | On Request | Disabled)
            7045   #A service was installed on the system

        )

    #Get Windows System Event Logs
    Get-WinEvent -FilterHashtable @{LogName="System"; StartTime=$StartDate; ID=$SystemEvents} -ErrorAction SilentlyContinue

}