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
    [String]$EradicateName,

    [Parameter(ParameterSetName="Path",Mandatory=$true,Position=2)]
    [Parameter(ParameterSetName="PathList",Mandatory=$true,Position=2)]
    [System.Management.Automation.Runspaces.PSSession[]]$Session

)

process{

    $Output = ('{0}\{1}' -f (Get-PRPath -Output),$EradicateName)

    #Get seconds for unique naming
    $Seconds = (Get-Date -UFormat %s).Split('.')[0]

    #Create output directory if needed
    if (!(Test-Path $Output)){

       $null = New-Item -Type Directory -Path $Output
    }

    switch ($PSCmdlet.ParameterSetName){

        "Path" {[String[]]$Paths = $Path}
        "PathList"{[String[]]$Paths = (Import-CSV -Path $PathList | Select-Object -ExpandProperty 'Path')}

    }

    foreach ($PathItem in $Paths) {

        $Scriptblock = {

            try {

                $null = Remove-Item -Path $Using:PathItem -Recurse -Force -ErrorAction Stop
                $Outhash = @{ Host=$ENV:ComputerName; Path=$Using:PathItem; Eradicated=$true}

            } catch {

                $Outhash = @{ Host=$ENV:ComputerName; Path=$Using:PathItem; Eradicated=$false }

            }

            return [PSCustomObject]$Outhash | Select Host, Eradicated, Path
        }

        #Generate output from data collected 
        $OutputPath = ('{0}\Scope_{1}_{2}.csv' -f $Output,($PathItem -Replace "\\","%5c" -Replace ":","%3a"),$Seconds)
        Invoke-Command -Session $Session -ScriptBlock $ScriptBlock | Export-CSV -Path $OutputPath -Append -NoTypeInformation
    }   
}
