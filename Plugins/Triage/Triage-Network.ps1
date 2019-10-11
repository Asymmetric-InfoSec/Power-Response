<#

.SYNOPSIS
    Plugin-Name: Triage-Network.ps1
    
.Description

    Grabs relevant Windows artifacts and data and performs analysis to 
    speed up the investigation process. This plugin runs the following
    plugins to gather information:

    Invoke-PRPlugin -Name Collect-ArpCache.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-DNSCache.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-InterfaceDetails.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-NetworkConnections.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-NetworkProfiles.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-NetworkRoutes.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-SessionDrives.ps1 -Session $Session

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
    # Begin plugin logic
    Invoke-PRPlugin -Name Collect-ArpCache.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-DNSCache.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-InterfaceDetails.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-NetworkConnections.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-NetworkProfiles.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-NetworkRoutes.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-SessionDrives.ps1 -Session $Session
    # End plugin logic
}
