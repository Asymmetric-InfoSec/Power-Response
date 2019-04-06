<#

.SYNOPSIS
    Plugin-Name: Collect-LocalUsers.ps1
    
.Description

    Gets local user accounts and group membership on a system.

.EXAMPLE

    Power-Response:

    Set ComputerName Test-PC
    Run


.NOTES
    Author: Gavin Prentice
    Date Created: 2/2/2019
    Twitter: @valrkey

    Last Modified By: Drew Schmitt
    Last Modified Date: 3/29/2019
    Twitter: @5ynax
  
#>

param (
   
)

process {

    # Collect the local and network user data from the remote systems
    $Groups = Get-LocalGroup

    foreach ($Group in $Groups){

        $Members = Get-LocalGroupMember -Group $Group

        foreach ($Member in $Members){

            $MemberHash = @{

                Group = $Group
                User = $Member.Name
                Class = $Member.ObjectClass
                Source = $Member.PrincipalSource

            }

            [PSCustomObject]$MemberHash | Select Group, User, Class, Source
        }
    }
}
    
