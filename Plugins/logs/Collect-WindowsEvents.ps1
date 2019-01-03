<#

.SYNOPSIS
    Plugin-Name: Collect-WindowsEvents.ps1
    
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
    .\Get-WindowsEvents.ps1 -ComputerName Test-PC -StartDate 12/23/2018

    Power-Response Execution

    Set ComputerName Test-PC
    Set StartDate 12/23/2018 
    Run

.NOTES
    Author: 5yn@x
    Date Created: December 23rd, 2018
    Twitter:  @5ynax
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param (

    [Parameter(Mandatory=$true, Position=0)]
    [string[]]$ComputerName,

    #If no date is supplied, the default is the current date minus 90 days (average dwell time of an adversary)
    [Parameter(Mandatory=$false, Position=1)]
    [DateTime]$StartDate=(Get-Date).AddDays(-90)

    )

process {

#Security Event Log IDs to Retrieve (Security)
$SecurityEvents = @(

        4720, #A user account was created 
        4722, #A user account was enabled 
        4724, #An attempt was made to reset an account's passowrd 
        4738, #A user account was changed
        4732, #A member was added to a security-enabled local group
        1102, #The audit log was cleared 
        4719, #System Audit policy was changed 
        4765, #SID History was added to an account 
        4766, #An attempt to add SID History to an account failed 
        4964, #Special groups have been assigned to a new logon 
        4624, #Successful logon
        4625, #Failed logon
        4634, #Successful logoff (Not always reliable)
        4647, #User initiated logoff (For interactive sessions)
        4648, #Logon using explicit credentials (runas)
        4672, #Account logon with superuser rights (Administrator)
        4735, #A security-enabled local group was changed
        4728, #A member was added to a security-enabled global group
        4756, #A member was added to a security-enabled universal group
        4778, #Session connected or reconnected (RDP)
        4779, #Session disconnected (RDP)
        4776, #Successful/Failed account authentication (NTLM)
        4768, #Ticket Granting Ticket was granted (Successful Logon - Kerberos)
        4769, #Service Ticket Requested (access to server resource - Kerberos)
        4771, #Pre-Authentication Failed (failed logon - Kerberos)
        4798, #A user's local group membership was enumerated
        4799, #A security-enabled local group membership was enumerated
        5140, #A network share was accessed (may be noisy)
        5145, #Shared object access (Detailed file share auditing - not enabled by default)
        4698, #Scheduled task created
        4702, #Scheduled task updated
        4699, #Scheduled task deleted
        4700, #Scheduled task enabled
        4701, #Scheduled task disabled
        4697, #A service was installed on the system
        4688, #New process created/Process exited (only applicable if you have process logging enabled - may be noisy)
        1102, #The audit log was cleared 
        4624, #Successful logon
        4625, #Failed logon
        4634, #Successful logoff (Not always reliable)
        4647, #User initiated logoff (For interactive sessions)
        4648, #Logon using explicit credentials (runas)
        4672, #Account logon with superuser rights (Administrator)
        4688, #New process created/Process exited (only applicable if you have process logging enabled - may be noisy)
        4697, #A service was installed on the system
        4698, #Scheduled task created
        4699, #Scheduled task deleted
        4700, #Scheduled task enabled
        4701, #Scheduled task disabled
        4702, #Scheduled task updated
        4719, #System Audit policy was changed 
        4720, #A user account was created 
        4722, #A user account was enabled 
        4724, #An attempt was made to reset an account's passowrd 
        4728, #A member was added to a security-enabled global group
        4732, #A member was added to a security-enabled local group
        4735, #A security-enabled local group was changed
        4738, #A user account was changed
        4756, #A member was added to a security-enabled universal group
        4765, #SID History was added to an account 
        4766, #An attempt to add SID History to an account failed 
        4768, #Ticket Granting Ticket was granted (Successful Logon - Kerberos)
        4769, #Service Ticket Requested (access to server resource - Kerberos)
        4771, #Pre-Authentication Failed (failed logon - Kerberos)
        4776, #Successful/Failed account authentication (NTLM)
        4778, #Session connected or reconnected (RDP)
        4779, #Session disconnected (RDP)
        4798, #A user's local group membership was enumerated
        4799, #A security-enabled local group membership was enumerated
        4964, #Special groups have been assigned to a new logon 
        5140, #A network share was accessed (may be noisy)
        5145  #Shared object access (Detailed file share auditing - not enabled by default)

    )

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

#Application Event Log IDs to Retrieve (Application)
$ApplicationEvents = @(

        1000,  #Application errors and hangs (may be noisy)
        1001,  #Application errors and hangs (may be noisy)
        1002,  #Application errors and hangs (may be noisy)
        1033,  #Installation completed (with success/failure status)
        1034,  #Application removal completed (with success/failure status)
        11707, #Installation completed successfully
        11708, #Installation operation failed
        11724  #Application removal completed successfully

    )

#Windows Firewall Event Log IDs to Retrieve (Microsoft-Windows-Windows Firewall With Advanced Security/Firewall.evtx)
$WinFirewallEvents = @(

        2003 #Windows firewall profile has been changed

    )

#PowerShell Event Log IDs to Retrieve (Microsoft-Windows-PowerShell/Operational.evtx)
$PowerShellEvents = @(

        4104, #Script contents
        4105, #Script start
        4106  #Script stop

    )

#WMI Event Log IDs to Retrieve (Microsoft-Windows-WMI-Activity/Operational.evtx)
$WMI_Events = @(

        5857, #Record filter/consumer activity
        5858, #Record filter/consumer activity
        5859, #Record filter/consumer activity
        5860, #Record filter/consumer activity
        5861  #New permanent event consumer creation

    )

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

#Scheduled Tasks Event Log IDs to Retireve (Microsoft-Windows-Task Scheduler/Operational.evtx)
$Sched_Tasks_Events = @(

        106, #Scheluded task created
        140, #Scheduled task updated
        141, #Scheduled task deleted
        200, #Scheduled task executed
        201  #Scheduled task completed

    )

#Get-WinEvent does not support string arrays for the ComputerName parameter, looping through computers in ComputerName parameter to allow compatibility with Import-Computers.ps1 plugin

foreach ($Computer in $ComputerName) {

        #Verify Computer is online prior to processing

        if (-not (Test-Connection -ComputerName $Computer -Count 1 -Quiet)) {
        Write-Error ("{0} appears to be offline, event logs were not collected" -f $Computer)
        continue
        
        #If online, collect event logs for $Computer
        } else {

        #Get Windows Security Event Logs
        Get-WinEvent -FilterHashtable @{LogName="Security"; StartTime=$StartDate; ID=$SecurityEvents} -ComputerName $Computer -ErrorAction SilentlyContinue

        #Get Windows System Event Logs
        Get-WinEvent -FilterHashtable @{LogName="System"; StartTime=$StartDate; ID=$SystemEvents} -ComputerName $Computer -ErrorAction SilentlyContinue

        #Get Windows Application Event Logs
        Get-WinEvent -FilterHashtable @{LogName="Security"; StartTime=$StartDate; ID=$SecurityEvents} -ComputerName $Computer -ErrorAction SilentlyContinue

        #Get Windows Firewall Event Logs
        Get-WinEvent -FilterHashTable @{LogName="Microsoft-Windows-Windows Firewall With Advanced Security/Firewall"; StartTime=$StartDate; ID=$WinFirewallEvents} -ComputerName $Computer -ErrorAction SilentlyContinue

        #Get Windows PowerShell Event Logs
        Get-WinEvent -FilterHashTable @{LogName="Microsoft-Windows-PowerShell/Operational"; StartTime=$StartDate; ID=$PowerShellEvents} -ComputerName $Computer -ErrorAction SilentlyContinue

        #Get WMI Event Logs 
        Get-WinEvent -FilterHashtable @{LogName="Microsoft-Windows-WMI-Activity/Operational"; StartTime=$StartDate; ID=$WMI_Events} -ComputerName $Computer -ErrorAction SilentlyContinue

        #Get Remote Desktop Event Logs
        Get-WinEvent -FilterHashtable @{LogName="Microsoft-Windows-TerminalServices-RDPClient/Operational"; StartTime=$StartDate; ID=$RDP_TC_RDPClient_Events} -ComputerName $Computer -ErrorAction SilentlyContinue
        Get-WinEvent -FilterHashtable @{LogName="Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational"; StartTime=$StartDate; ID=$RDP_TC_RCM_Events} -ComputerName $Computer -ErrorAction SilentlyContinue
        Get-WinEvent -FilterHashtable @{LogName="Microsoft-Windows-TerminalServices-LocalSessionManager/Operational"; StartTime=$StartDate; ID=$RDP_TC_LSM_Events} -ComputerName $Computer -ErrorAction SilentlyContinue
        Get-WinEvent -FilterHashtable @{LogName="Microsoft-Windows-RemoteDesktopServices-RdpCoreTS/Operational"; StartTime=$StartDate; ID=$RDP_RdpTS_Events} -ComputerName $Computer -ErrorAction SilentlyContinue

        #Get Scheduled Tasks Event Logs
        Get-WinEvent -FilterHashtable @{LogName="Microsoft-Windows-TaskScheduler/Operational"; StartTime=$StartDate; ID=$Sched_Tasks_Events} -ComputerName $Computer -ErrorAction SilentlyContinue

        }
    }

}