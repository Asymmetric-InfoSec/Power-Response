<#

.SYNOPSIS
    Plugin-Name: Eradicate-Files.ps1
    
.Description
    This plugin allows for incident responders to eradicate files and/or directories from
    known compromised systems. This plugin can take an explicit list of
    paths or a CSV list of different paths to eradicate from the 
    target machines.

    Note: If using a CSV of paths, the header must be 'Path'

.EXAMPLE

    Power-Response Execution

    Set ComputerName Test-PC
    Set Path C:\Tools\MaliciousDoc.txt
    Run

    Set ComputerName Test-PC
    Set PathList C:\Tools\Paths.csv
    Run

.NOTES
    Author: Drew Schmitt
    Date Created: 9/26/2019
    Twitter: @5ynax
    
    Last Modified By: Drew Schmitt
    Last Modified Date: 10/16/2019
    Twitter: @5ynax
  
#>
[cmdletbinding(DefaultParameterSetName="Path")]

param (

    [Parameter(ParameterSetName="Path",Mandatory=$true,Position=0)]
    [String[]]$Path,

    [Parameter(ParameterSetName="PathList",Mandatory=$true,Position=0)]
    [String]$PathList,

    [Parameter(ParameterSetName="Path",Mandatory=$true,Position=1)]
    [Parameter(ParameterSetName="PathList",Mandatory=$true,Position=1)]
    [System.Management.Automation.Runspaces.PSSession[]]$Session

)

process{

    switch ($PSCmdlet.ParameterSetName){

        "Path" {[String[]]$Paths = $Path}
        "PathList"{[String[]]$Paths = (Import-CSV -Path $PathList | Select-Object -ExpandProperty 'Path')}

    }

    $Scriptblock = {
        $Error.Clear()

        Remove-Item -Path $Using:Paths -Recurse -Force -ErrorAction SilentlyContinue

        foreach ($ErrorInstance in $Error){
            $RemoteComputer = $env:ComputerName
            $RemoteMessage = ('{0}: {1}' -f $RemoteComputer,$ErrorInstance) 
            $RemoteMessage
        }  
    }
            
    [String[]]$Messages = Invoke-Command -Session $Session -Scriptblock $Scriptblock

    foreach ($Message in $Messages){

        Write-PRWarning -Message $Message
    }  
}