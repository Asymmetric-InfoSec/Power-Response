<#

.SYNOPSIS
    Plugin-Name: Collect-RecentItems.ps1
    
.Description
    Collects shortcuts from Recent Items (%UserProfile\AppData\Roaming\Microsoft\Windows\Recent)

.EXAMPLE
    Stand Alone Execution

    .\Collect-RecentItems.ps1 -ComputerName Test-PC

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

    [Parameter(Mandatory=$true,Position=0)]
    [string[]]$ComputerName
    
    )

process {

    foreach ($Comptuer in $ComputerName){

        # Create persistent Powershell Session

        $Session = New-PSSession -ComputerName $Computer -SessionOption (New-PSSessionOption -NoMachineProfile)

        # Get list of users that exist on this process

        Invoke-Command -Session $Session -Scriptblock{

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

        $Session | Remove-PSSession   

    }

}