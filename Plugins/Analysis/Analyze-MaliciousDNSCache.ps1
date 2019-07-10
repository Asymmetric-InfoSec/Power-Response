<#

.SYNOPSIS
    Plugin-Name: Analyze-MaliciousDNSCache.ps1
    
.Description
	This plugin performs analysis on data retrieved from Hunt-MaliciousDNSCache

.EXAMPLE


.NOTES
    Author: Drew Schmitt
    Date Created: 7/9/2019
    Twitter: @5ynax
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param (

    [Parameter(Mandatory=$true,Position=0)]
    [System.Management.Automation.Runspaces.PSSession[]]$Session,

    [Parameter(Mandatory=$true,Position=1)]
    [String]$HuntName

)

process {

	#Verify if binary dependencies are satisfied
    $LogParserDeps = Test-Path ("{0}\LogParser" -f (Get-PRPath -Bin))

    if (!$LogParserDeps){

        throw ("LogParser Deps not found in {0}. Place executables/dlls in binary directory and try again." -f (Get-PRPath -Bin))
    }

    #Persistent Variable Definitions
    $AnalysisDir = ("{0}\{1}\Network\DNSCache\Analysis" -f (Get-PRPath -Output),$HuntName)
    $DataLocation = ("{0}\{1}\Network\DNSCache\*Collect-DNSCache*.csv" -f (Get-PRPath -Output),$HuntName)
    $Seconds = ((Get-Date -UFormat %s).Split('.')[0])
    $ExportPath = ("{0}\{1}" -f $AnalysisDir,$Seconds)
    
    #Create Analysis Directory
    New-Item -Type Directory -Path $AnalysisDir -Force | Out-Null

    #Build an array of hashtables for analysis queries and relevant attributes
    $Queries = @(

        @{
            Name = 'Stack_Name_Data'
            Query = @"
            SELECT
                COUNT(Name, Data) as ct,
                Name,
                Data
            INTO
                <File>
            FROM
                $DataLocation
            GROUP BY
                Name,
                Data
            ORDER BY
                ct ASC    
"@
        },

        @{
            Name = 'Stack_Name_TTL'
            Query = @"
            SELECT
                COUNT(Name, TTL) as ct,
                Name,
                TTL
            INTO
                <File>
            FROM
                $DataLocation
            GROUP BY
                Name,
                TTL
            ORDER BY
                ct ASC    
"@
        },

        @{
            Name = 'Stack_Name_DataLength'
            Query = @"
            SELECT
                COUNT(Name, DataLength) as ct,
                Name,
                DataLength
            INTO
                <File>
            FROM
                $DataLocation
            GROUP BY
                Name,
                DataLength
            ORDER BY
                ct ASC    
"@
        }
    )

    #Perform Analysis and store results in analysis directory
    foreach ($Query in $Queries){
        $ExportName = ("{0}_{1}.csv" -f $ExportPath,($Query.Name))
        $Command = ("& '{0}\LogParser\LogParser.exe' -i:csv -o:csv -stats:off `"{1}`" " -f (Get-PRPath -Bin),($Query.Query -replace ('<File>',$ExportName)))
        Invoke-Expression -Command $Command | Out-Null
    }
}