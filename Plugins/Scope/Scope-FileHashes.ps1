<#

.SYNOPSIS
    Plugin-Name: Scope-FileHashes.ps1
    
.Description
    Performs scoping based on a list of hashes provided via string array
    or CSV input file. The output will return True or False based on
    whether or not it was discovered on the system.

    Note: The CSV import file must have a column header of 'FileHash'

.EXAMPLE
   
    Power-Response Execution

    Set ComputerName Test-PC
    Set FileHash '7E9589CBC52B198B38CC76566BBF0178'
    run
    
    OR

    Set ComputerName Test-PC
    Set RegistryKeyList C:\Tools\FileHashes.csv
    run

.NOTES
    Author: Drew Schmitt
    Date Created: 10/15/2019
    Twitter: @5ynax
    
    Last Modified By: 
    Last Modified Date: 
    Twitter: 
  
#>

[cmdletbinding(DefaultParameterSetName="FileHash")]

param(

    [Parameter(ParameterSetName = "FileHash", Position = 0, Mandatory = $true)]
    [String[]]$FileHash,

    [Parameter(ParameterSetName = "FileHashList", Position = 0, Mandatory = $true)]
    [String]$FileHashList,

    [Parameter(ParameterSetName = "FileHash",Position = 1,Mandatory = $false)]
    [Parameter(ParameterSetName = "FileHashList",Position = 1,Mandatory = $false)]
    [String[]]$StartingDirectory = 'C:',

    [Parameter(ParameterSetName = "FileHash",Position = 2,Mandatory = $false)]
    [Parameter(ParameterSetName = "FileHashList",Position = 2,Mandatory = $false)]
    [String]$HashAlgorithm = 'MD5',

    [Parameter(ParameterSetName = "FileHash",Position = 3,Mandatory = $false)]
    [Parameter(ParameterSetName = "FileHashList",Position = 3,Mandatory = $false)]
    [Switch]$Recurse = $false,

    [Parameter(ParameterSetName = "FileHash",Position = 4,Mandatory = $true)]
    [Parameter(ParameterSetName = "FileHashList",Position = 4,Mandatory = $true)]
    [String]$ScopeName,

    [Parameter(ParameterSetName = "FileHash",Position = 5,Mandatory = $true)]
    [Parameter(ParameterSetName = "FileHashList",Position = 5,Mandatory = $true)]
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

    #Generate based on parameter set
    switch ($PSCmdlet.ParameterSetName){

        "FileHash" {[String[]]$FileHashes = $FileHash}
        "FileHashList"{[String[]]$FileHashes = (Import-CSV -Path $FileHashList | Select-Object -ExpandProperty 'FileHash')}

    }

    foreach ($FileHashItem in $FileHashes){
        
        $ScriptBlock = {

            foreach ($PathItem in $Using:StartingDirectory) {

                if ($Using:Recurse) {

                $HashEval = Get-ChildItem -Path $Using:StartingDirectory -Recurse -Force | Get-FileHash -Algorithm $Using:HashAlgorithm | Where-Object Hash -eq $Using:FileHashItem

                # return PSCustomObject for recording in CSV
                $OutHash =@{Host = $env:COMPUTERNAME; Detected = [Boolean]$HashEval; Algorithm = $HashEval.Algorithm; Hash = $HashEval.Hash ; Path = $HashEval.Path}
                return [PSCustomObject]$OutHash

                }

                if (!$Using:Recurse){

                    $HashEval = Get-ChildItem -Path $Using:StartingDirectory -Force | Get-FileHash -Algorithm $Using:HashAlgorithm | Where-Object Hash -eq $Using:FileHashItem

                    # return PSCustomObject for recording in CSV
                    $OutHash =@{Host = $env:COMPUTERNAME; Detected = [Boolean]$HashEval; Algorithm = $Using:Algorithm; Hash = $HashEval.Hash ; Path = ($HashEval.Path -Join "`n")}
                    return [PSCustomObject]$OutHash

                }
            }
        }
        
        #Generate output fules from scoping data collected
        $OutputPath = ('{0}\Scope_{1}_{2}.csv' -f $Output,$FileHashItem,$Seconds)
        Invoke-Command -Session $Session -ScriptBlock $ScriptBlock -ErrorAction SilentlyContinue | Export-CSV -Path $OutputPath -Append -NoTypeInformation

    }
}
