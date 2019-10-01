<#

.SYNOPSIS
    Plugin-Name: Eradicate-Files.ps1
    
.Description
    This plugin allows for incident responders to eradicate files from
    known compromised systems. This plugin can take an explicit list of
    file paths or a CSV list of different paths to eradicate from the 
    target machines.

    Note: If using a CSV of paths, the header must be 'Path'

.EXAMPLE

    Power-Response Execution

    Set ComputerName Test-PC
    Set FilePath C:\Tools\MaliciousDoc.txt
    Run

    Set ComputerName Test-PC
    Set FileListPath C:\Tools\Paths.csv
    Run

.NOTES
    Author: Drew Schmitt
    Date Created: 9/26/2019
    Twitter: @5ynax
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>
[cmdletbinding(DefaultParameterSetName="FilePath")]

param (

    [Parameter(ParameterSetName="FilePath",Mandatory=$true,Position=0)]
    [String[]]$FilePath,

    [Parameter(ParameterSetName="FileListPath",Mandatory=$true,Position=0)]
    [String]$FileListPath,

    [Parameter(ParameterSetName="FilePath",Mandatory=$true,Position=1)]
    [Parameter(ParameterSetName="FileListPath",Mandatory=$true,Position=1)]
    [System.Management.Automation.Runspaces.PSSession[]]$Session

    )

process{

    switch ($PSCmdlet.ParameterSetName){

        "FilePath" {[String[]]$Paths = $FilePath}
        "FileListPath"{[String[]]$Paths = (Import-CSV -Path $FileListPath | Select-Object -ExpandProperty 'Path')}

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