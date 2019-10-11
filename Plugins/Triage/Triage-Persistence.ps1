<#

.SYNOPSIS
    Plugin-Name: Triage-Persistence.ps1
    
.Description

    Grabs relevant Windows artifacts and data and performs analysis to 
    speed up the investigation process. This plugin runs the following
    plugins to gather information:

    Invoke-PRPlugin -Name Collect-RunKeys.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-ScheduledTaskInfo.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-ScheduledTaskDetails.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-Services.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-StartupDirList.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-StartupList.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-WMIBindings.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-WMIConsumers.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-WMIFilters.ps1 -Session $Session

.EXAMPLE

    Power-Response Execution

    set computername test-pc
    run

.NOTES
    Author: Drew Schmitt
    Date Created: 5/10/2019
    Twitter: @5ynax
    
    Last Modified By: Gavin Prentice
    Last Modified Date: 10/11/2019
    Twitter: @Valrkey
  
#>

param (

    [Parameter(Mandatory=$true,Position=0)]
    [System.Management.Automation.Runspaces.PSSession[]]$Session

    )

process{
    # Begin plugin logic
    Invoke-PRPlugin -Name Collect-RunKeys.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-ScheduledTaskInfo.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-ScheduledTaskDetails.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-Services.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-StartupDirList.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-StartupList.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-WMIBindings.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-WMIConsumers.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-WMIFilters.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-LocalUsers.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-UserProfileListing.ps1 -Session $Session
    # End plugin logic
}
