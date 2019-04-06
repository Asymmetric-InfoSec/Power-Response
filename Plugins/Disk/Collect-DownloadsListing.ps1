<#

.SYNOPSIS
    Plugin-Name: Collect-DownloadsListing.ps1
    
.Description

	Collects the Downloads directory contents (listing only) for each user
	to use as part of an investigation to determine if a document was downloaded 
	or saved from the internet or an email attachment.

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

        $DownloadItems = Get-ChildItem "C:\Users\$User\Downloads" -ErrorAction SilentlyContinue

        foreach ($Item in $DownloadItems) {

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