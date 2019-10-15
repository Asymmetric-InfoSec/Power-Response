<#

.SYNOPSIS
    Plugin-Name: Scope-Files.ps1
    
.Description
    Performs scoping based on a list of files (names only) provided via string array
    or CSV input file. The output will return True or False based on
    whether or not the file was discovered on the system.

    Note: The CSV import file must have a column header of 'File'
    
    Note: This plugin is meant to look for file names only, if you know the
    whole file path of a file, utilize Scope-Paths.ps1

.EXAMPLE
   
    Power-Response Execution

    Set ComputerName Test-PC
    Set File Power-Response.ps1
    run
    
    OR

    Set ComputerName Test-PC
    Set FileList C:\Tools\ItemPaths.csv
    run

.NOTES
    Author: Drew Schmitt
    Date Created: 9/26/2019
    Twitter: @5ynax
    
    Last Modified By: 
    Last Modified Date: 
    Twitter: 
  
#>

[cmdletbinding(DefaultParameterSetName="File")]

param(

    [Parameter(ParameterSetName = "File",Position = 0,Mandatory = $true)]
    [String[]]$File,

    [Parameter(ParameterSetName = "FileList",Position = 0,Mandatory = $true)]
    [String]$FileList,

    [Parameter(ParameterSetName = "File",Position = 1,Mandatory = $false)]
    [Parameter(ParameterSetName = "FileList",Position = 1,Mandatory = $false)]
    [String]$FileStartPath='C:\',

    [Parameter(ParameterSetName = "File",Position = 2,Mandatory = $true)]
    [Parameter(ParameterSetName = "FileList",Position = 2,Mandatory = $true)]
    [String]$ScopeName,

    [Parameter(ParameterSetName = "File",Position = 3,Mandatory = $true)]
    [Parameter(ParameterSetName = "FileList",Position = 3,Mandatory = $true)]
    [System.Management.Automation.Runspaces.PSSession[]]$Session

    )

process{

    #$Output = (Get-PRPath -ScopeName $ScopeName)
    $Output = "C:\Tools\Power-Response\Output\$ScopeName"

    #Get seconds for unique naming
    $Seconds = (Get-Date -UFormat %s).Split('.')[0]

    #Create output directory if needed
    if (!(Test-Path $Output)){

       $null = New-Item -Type Directory -Path $Output
    }

    #Generate files list based on parameter set
    switch ($PSCmdlet.ParameterSetName){

            "File" {[String[]]$Files = $File}
            "FileList"{[String[]]$Files = (Import-CSV -Path $FileList | Select-Object -ExpandProperty 'File')}

    }

    foreach ($FileItem in $Files){

        $ScriptBlock = {

            # Determine if file is found on system
            $FileEvalPath = Get-ChildItem -Path $Using:FileStartPath -Recurse -Name -Include $Using:FileItem -ErrorAction SilentlyContinue

            # Append eval results to CSV
            if ($FileEvalPath){

                $FilePathArray += ($FileEvalPath -Join "`n")

                # return PSCustomObject for recording in CSV - includes path of discovered child object
                $OutHash =@{ Host = $env:COMPUTERNAME; File = "$Using:FileItem"; Detected = "True"; Path = $FilePathArray}
                return [PSCustomObject]$OutHash
                
            } else {

                # return PSCustomObject for recording in CSV
                $OutHash =@{ Host = $env:COMPUTERNAME; File = "$Using:FileItem"; Detected = "False"; Path = $null}
                return [PSCustomObject]$OutHash
            }      
        }

        #Generate output fules from scoping data collected (1 csv output file per file scoped)
        $OutputPath = ('{0}\Scope_{1}_{2}.csv' -f $Output,$FileItem,$Seconds)
        Invoke-Command -Session $Session -ScriptBlock $ScriptBlock | Export-CSV -Path $OutputPath -Append -NoTypeInformation

    }   
}