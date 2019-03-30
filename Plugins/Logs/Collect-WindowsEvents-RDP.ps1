<#

.SYNOPSIS
    Plugin-Name: Collect-WindowsEvents-RDP.ps1
    
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

    #RDP Event Log IDs to Retrieve (Microsoft-Windows-TerminalServices-RDPClient/Operational.evtx)
    $RDP_TC_RDPClient_Events = @(

            1024, #Destination Hostname (From Source/Initiating System - system RDP-ing from)
            1102  #Destination IP Address (From Source/Initiating System - system RDP-ing from)

    )

    #RDP Event Log IDs to Retrieve (Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational.evtx)
    $RDP_TC_RCM_Events = @(

            1149 #Source IP/Logon Username (On destination system-machine being RDP'd to)

        )

    #RDP Event Log IDs to Retrieve (Microsoft-Windows-TerminalServices-LocalSessionManager/Operational.evtx)
    $RDP_TC_LSM_Events = @(

            21, #Source IP/Logon Username
            22, #Source IP/Logon Username
            25, #Source IP/Logon Username
            41  #Source IP/Logon Username
        )

    #RDP Event Log IDs to Retrieve (Microsoft-Windows-RemoteDesktopServices-RdpCoreTS/Operational.evtx)
    $RDP_RdpTS_Events = @(

            98, #Successful Connections
            131 #Connection Attempts (Source IP/Logon UserName)

        )

    #Get Remote Desktop Event Logs
    Get-WinEvent -FilterHashtable @{LogName="Microsoft-Windows-TerminalServices-RDPClient/Operational"; StartTime=$StartDate; ID=$RDP_TC_RDPClient_Events} -ErrorAction SilentlyContinue
    Get-WinEvent -FilterHashtable @{LogName="Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational"; StartTime=$StartDate; ID=$RDP_TC_RCM_Events} -ErrorAction SilentlyContinue
    Get-WinEvent -FilterHashtable @{LogName="Microsoft-Windows-TerminalServices-LocalSessionManager/Operational"; StartTime=$StartDate; ID=$RDP_TC_LSM_Events} -ErrorAction SilentlyContinue
    Get-WinEvent -FilterHashtable @{LogName="Microsoft-Windows-RemoteDesktopServices-RdpCoreTS/Operational"; StartTime=$StartDate; ID=$RDP_RdpTS_Events} -ErrorAction SilentlyContinue
}