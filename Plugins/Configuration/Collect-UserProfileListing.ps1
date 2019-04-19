<#

.SYNOPSIS
    Plugin-Name: Collect-UserProfileListing.ps1
    
.Description
    Retrieves details regarding the user profiles on the remote machine and
    metadata details to determine what user profiles exist on each remote 
    machine.

.EXAMPLE
    
    Power-Response Execution

    run

.NOTES
    Author: Drew Schmitt
    Date Created: 4/11/2019
    Twitter: @5ynax
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param (

)

process {

    $UserProfileListing = Get-ChildItem 'C:\Users'

    foreach ($UserProfile in $UserProfileListing) {

        $ProfileHash = @{

            Name = $UserProfile.Name
            CreationTimeUTC = $UserProfile.CreationTimeUTC
            LastWriteTimeUTC = $UserProfile.LastWriteTimeUTC
            LastAccessTimeUTC = $UserProfile.LastAccessTimeUTC
        }

        [PSCustomObject]$ProfileHash | Select Name, CreationTimeUTC, LastWriteTimeUTC, LastAccessTimeUTC
    }
}