<#

.SYNOPSIS
    Plugin-Name: Analyze-MaliciousScheduledTaskInfo.ps1
    
.Description
	This plugin performs analysis on data retrieved from Hunt-MaliciousScheduledTaskInfo

.EXAMPLE


.NOTES
    Author: Drew Schmitt
    Date Created: 7/8/2019
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
    $AnalysisDir = ("{0}\{1}\Persistence\ScheduledTaskInfo\Analysis" -f (Get-PRPath -Output),$HuntName)
    $DataLocation = ("{0}\{1}\Persistence\ScheduledTaskInfo\*Collect-ScheduledTaskInfo*.csv" -f (Get-PRPath -Output),$HuntName)
    $Seconds = ((Get-Date -UFormat %s).Split('.')[0])
    $ExportPath = ("{0}\{1}" -f $AnalysisDir,$Seconds)
    
    #Create Analysis Directory
    New-Item -Type Directory -Path $AnalysisDir -Force | Out-Null

    #Build an array of hashtables for analysis queries and relevant attributes
    $Queries = @(

        @{
            Name = 'Stack_URI_Execute'
            Query = @"
            SELECT
                COUNT(URI, Execute) as ct,
                URI,
                Execute
            INTO
                <File>
            FROM
                $DataLocation
            GROUP BY
                URI,
                Execute
            ORDER BY
                ct ASC    
"@
        },

        @{
            Name = 'Stack_URI_Execute_Arguments'
            Query = @"
            SELECT
                COUNT(URI, Execute, Arguments) as ct,
                URI,
                Execute,
                Arguments
            INTO
                <File>
            FROM
                $DataLocation
            GROUP BY
                URI,
                Execute,
                Arguments
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