<#

.SYNOPSIS
    Plugin-Name: Collect-StartupList.ps1
    
.Description

	Collects the list of startup directory contents for each user and all users (public)
	to use as part of an investigation to determine if there are persistence
    mechanisms established via the startup directory

.EXAMPLE

	Power-Response Execution

	Set ComputerName Test-PC
	run

.NOTES
    Author: Drew Schmitt
    Date Created: 4/3/2019
    Twitter: @5ynax
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param(

)

process {

	# Get list of users that exist on this process

    $Users = Get-ChildItem "C:\Users\"

    #For each user, get contents of Downloads directory

    foreach ($User in $Users){

        $StartupItems = Get-ChildItem "C:\Users\$User\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup" -ErrorAction SilentlyContinue

        foreach ($Item in $StartupItems) {

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

    # All users startup contents

    $AllUsersStartup = Get-ChildItem "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup" -ErrorAction SilentlyContinue

    foreach ($Item in $AllUsersStartup) {

        $OutHash = @{

            "User" = "All Users"
            "Name" = $Item.Name
            "Mode" = $Item.Mode
            "CreationTime" = $Item.CreationTimeUtc
            "ModificationTime" = $Item.LastWriteTimeUtc
        }

        [PSCustomObject]$OutHash | Select User, Name, Mode, CreationTime, ModificationTime
    }
}