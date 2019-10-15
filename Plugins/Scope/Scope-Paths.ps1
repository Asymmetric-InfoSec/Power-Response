<#

.SYNOPSIS
    Plugin-Name: Scope-Paths.ps1
    
.Description
    Performs scoping based on a list of paths provided via string array
    or CSV input file. The output will return True or False based on
    whether or not the file was discovered on the system.

    Note: The CSV import file must have a column header of 'Path'

.EXAMPLE
   
    Power-Response Execution

    Set ComputerName Test-PC
    Set Path <Path>
    run
    
    OR

    Set ComputerName Test-PC
    Set PathList C:\Tools\ItemPaths.csv
    run

.NOTES
    Author: Drew Schmitt
    Date Created: 9/26/2019
    Twitter: @5ynax
    
    Last Modified By: 
    Last Modified Date: 
    Twitter: 
  
#>

[cmdletbinding(DefaultParameterSetName="Path")]

param (

    [Parameter(ParameterSetName = "Path", Position = 0, Mandatory = $true)]
    [String[]]$Path,

    [Parameter(ParameterSetName = "PathList", Position = 0, Mandatory = $true)]
    [String]$PathList,

    [Parameter(ParameterSetName = "Path",Position = 1,Mandatory = $true)]
    [Parameter(ParameterSetName = "PathList",Position = 1,Mandatory = $true)]
    [String]$ScopeName,

    [Parameter(ParameterSetName = "Path",Position = 2,Mandatory = $true)]
    [Parameter(ParameterSetName = "PathList",Position = 2,Mandatory = $true)]
    [System.Management.Automation.Runspaces.PSSession[]]$Session
)

process {

    $Output = ('{0}\{1}' -f (Get-PRPath -Output),$ScopeName)

    #Get seconds for unique naming
    $Seconds = (Get-Date -UFormat %s).Split('.')[0]

    #Create output directory if needed
    if (!(Test-Path -Path $Output)){

        $null = New-Item -Type Directory -Path $Output
    }

    #Generate list based on parameter set
    switch ($PSCmdlet.ParameterSetName){

        "Path" {[String[]]$Paths = $Path}
        "PathList"{[String[]]$Paths = (Import-CSV -Path $PathList | Select-Object -ExpandProperty 'Path')}

    }

    foreach ($PathItem in $Paths){
        
        $ScriptBlock = {
            
            # Determine if found on system
            $PathEval = (Test-Path -Path $Using:PathItem)
            
            # Return PSCustomObject for recording in CSV - includes path of discovered child object
            # Apprend results to csv
            $OutHash =@{ Host = $env:COMPUTERNAME; Path = "$Using:PathItem"; Detected = [Boolean]$PathEval}
            return [PSCustomObject]$OutHash
                    
        }
        
        #Generate output fules from scoping data collected
        $OutputPath = ('{0}\Scope_{1}_{2}.csv' -f $Output,($PathItem -Replace "\\","_" -Replace ":",""),$Seconds)
        Invoke-Command -Session $Session -ScriptBlock $ScriptBlock | Export-CSV -Path $OutputPath -Append -NoTypeInformation

    }   
}
