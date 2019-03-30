<#

.SYNOPSIS
    Plugin-Name: Collect-RecentItems.ps1
    
.Description
    Collects listing of shortcuts from Recent Items (%UserProfile\AppData\Roaming\Microsoft\Windows\Recent)

.EXAMPLE

    Power-Response Execution

    set ComputerName Test-PC
    run

.NOTES
    Author: Drew Schmitt
    Date Created: 3/7/2019
    Twitter: @5ynax
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param (

    )

process {

    # Get list of users that exist on this process

    $Users = Get-ChildItem "C:\Users\"

    #For each user, get contents of recent files (lnk files)

    foreach ($User in $Users){

        $RecentItems = Get-ChildItem "C:\Users\$User\AppData\Roaming\Microsoft\Windows\Recent" -ErrorAction SilentlyContinue

        foreach ($Item in $RecentItems) {

            $OutHash = @{

                "User" = $User
                "Name" = $Item.Name
                "Mode" = $Item.Mode
                "CreationTime" = $Item.CreationTimeUtc
                "ModificationTime" = $Item.LastWriteTimeUtc
            }

            [PSCustomObject]$OutHash | Select User, Name, Mode, CreationTime, ModificationTime
        }
    }
} 