<#

.SYNOPSIS
    Plugin-Name: Collect-WindowsEvents-Security.ps1
    
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
    .\Collect-WindowsEvents-Security.ps1 -ComputerName Test-PC -StartDate 12/23/2018

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

    [Parameter(Mandatory=$true, Position=0)]
    [string[]]$ComputerName,

    #If no date is supplied, the default is the current date minus 90 days (average dwell time of an adversary)
    [Parameter(Mandatory=$false, Position=1)]
    [DateTime]$StartDate=(Get-Date).AddDays(-90)

    )

process {

#Security Event Log IDs to Retrieve (Security)
$SecurityEvents = @(

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
        4964  #Special groups have been assigned to a new logon 

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

        }
    }

}