<#

.SYNOPSIS
    Plugin-Name: Retrieve-Jumplists.ps1
    
.Description

    This plugin will retrieve jumplist files from a remote host and move them to a specified
    output directory based on the the output path provided from Power-Response. By default,
    this plugin will retrieve all jumplist files in the %UserProfile\AppData\Roaming\Microsoft
    \Windows\Recent\AutomaticDestinations directory. Jumplists are recovered from all user 
    profiles.
    
.EXAMPLE

    Power-Response Execution

    Set ComputerName Test-PC
    Run

    
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
    [System.Management.Automation.Runspaces.PSSession]$Session

    )

process{

    # Set $Output for where to store recovered prefetch files
    $Output= (Get-PRPath -ComputerName $Session.ComputerName -Directory ('Jumplists_{0:yyyyMMdd}' -f (Get-Date)))

    # Create jumplists subdirectory in $global:PowerResponse.OutputPath for storing jumplists
    If (-not (Test-Path $Output)) {
       
        New-Item -Type Directory -Path $Output | Out-Null
    }   

    #Get all user accounts and store them in variable
    $UserAccts = Invoke-Command -Session $Session -ScriptBlock {Get-ChildItem "C:\Users\"}

    #Loop through each user and collect jumplists
    foreach ($User in $UserAccts){

        #Create Subdirectories for each user account in $Output
        if (!(Test-Path $Output\$User)){

            New-Item -Type Directory -Path $Output\$User | Out-Null
        }

        #Collect Jumplist for specific user
        $JumpFiles = Invoke-Command -Session $Session -ScriptBlock {Get-ChildItem "C:\users\$($args[0])\AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations\" -ErrorAction SilentlyContinue} -ArgumentList $User

        foreach ($File in $JumpFiles){

            #Get Jumplist File Attributes
            $CreationTime = Invoke-Command -Session $Session -ScriptBlock {(Get-Item "C:\users\$($args[0])\AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations\$($args[1])").CreationTime} -ArgumentList $User,$File
            
            #Copy specified jumplist file to $Output
            Copy-Item "C:\users\$User\AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations\$File" -Destination "$Output\$User" -FromSession $Session -Force -ErrorAction SilentlyContinue

            #Set original creation time on copied prefetch file
            (Get-Item "$Output\$User\$File").CreationTime = $CreationTime          
        }
    }

    #Remove empty directories from $Output
    $JumpDirs = Get-ChildItem $Output -directory -recurse | Where { (Get-ChildItem $_.fullName).count -eq 0 } | Select -Expandproperty FullName
    $JumpDirs | Foreach-Object { Remove-Item $_ }
}

