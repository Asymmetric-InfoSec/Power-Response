<#

.SYNOPSIS
    Plugin-Name: Hunt-MaliciousPrefetchListing.ps1
    
.Description

    Hunts for malicious listing in C:\Windows\Prefetch and performs analysis to discover anomalies

.EXAMPLE

    Set ComputerName <list of computers>
    Set HuntName PrefetchListingHunt
    Run

.NOTES
    Author: Drew Schmitt
    Date Created: 07/03/2019
    Twitter: @5ynax 
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param (
    [Parameter(Mandatory=$true,Position=0)]
    [System.Management.Automation.Runspaces.PSSession[]]$Session,

    [Parameter(Mandatory=$true,Position=1)]
    [String]$HuntName
)

process {
    
    Invoke-PRPlugin -Name 'Collect-PrefetchListing' -Session $Session -HuntName $HuntName
}