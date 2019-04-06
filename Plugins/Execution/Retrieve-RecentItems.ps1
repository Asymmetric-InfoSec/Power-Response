<#

.SYNOPSIS
    Plugin-Name: Retrieve-RecentItems.ps1
    
.Description
    Collects shortcuts (lnk files) from Recent Items (%UserProfile\AppData\Roaming\Microsoft\Windows\Recent)

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

    [Parameter(Mandatory=$true,Position=0)]
    [System.Management.Automation.Runspaces.PSSession]$Session,

    [Parameter(Mandatory=$false,Position=1)]
    [string[]]$RecentItemName
    
    )

process {

    #Set $Output for where to store recovered prefetch files
    $Output= (Get-PROutputPath -ComputerName $Session.ComputerName -Directory 'RecentItems')

    #Create Subdirectory in $global:PowerResponse.OutputPath for storing prefetch
    If (-not (Test-Path $Output)) {
        New-Item -Type Directory -Path $Output | Out-Null
    }   

    #Get list of users that exist on this process

    $Users = Invoke-Command -Session $Session -Scriptblock{Get-ChildItem "C:\Users\" | ? {@("Public","Default") -NotContains $_.name}}

    #For each user, create directory for storing recent files

    foreach ($User in $Users){

        $UserOutput = "$Output\$User"

        #Create User subdirectory 
        if (-not (Test-Path $UserOutput)) {
            
            New-Item -Type Directory -Path $UserOutput | Out-Null

        }

        #Get all recent files for user
        if (!$RecentItemName){

            $RecentItemName = Invoke-Command -Session $Session -ScriptBlock {Get-ChildItem "C:\Users\$($args[0])\AppData\Roaming\Microsoft\Windows\Recent" | ? {!$_.PSISContainer}} -ArgumentList $User -ErrorAction SilentlyContinue

        }

        foreach ($File in $RecentItemName){

            #Get recent items file Attributes
            $CreationTime = Invoke-Command -Session $Session -ScriptBlock {(Get-Item "C:\Users\$($args[0])\AppData\Roaming\Microsoft\Windows\Recent\$($args[1])").CreationTime} -ArgumentList $User,$File

            #Copy specified file to $Output
            Copy-Item "C:\Users\$User\AppData\Roaming\Microsoft\Windows\Recent\$File" -Destination "$UserOutput\" -FromSession $Session -Force -ErrorAction SilentlyContinue

            #Set original creation time on copied recent items lnk file
            (Get-Item "$UserOutput\$File").CreationTime = $CreationTime
        }
    }
}