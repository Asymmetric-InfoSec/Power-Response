<#

.SYNOPSIS
    Plugin-Name: Triage-Execution.ps1
    
.Description

    Grabs relevant Windows artifacts and data and performs analysis to 
    speed up the investigation process. This plugin runs the following
    plugins to gather information:

    Invoke-PRPlugin -Name Collect-PrefetchListing.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-ProcessDLLs.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-Processes.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-RecentItemsListing.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-UserAssist.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrieve-Handles.ps1 -Session $Session


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

process {
    # Plugin Execution
    Invoke-PRPlugin -Name Collect-PrefetchListing.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-ProcessDLLs.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-Processes.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-RecentItemsListing.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-UserAssist.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrieve-Handles.ps1 -Session $Session
}
