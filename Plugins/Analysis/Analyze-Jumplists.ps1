<#

.SYNOPSIS
    Plugin-Name: Analyze-Jumplists.ps1
    
.Description
    Analyzes recovered jumplist files for all hosts that you have collected data from.
    There are checks built in to not analyze twice. By default, the plugin will look for 
    jumplist results from the current date. You can specify the analysis date with the
    $AnalyzeDate parameter. When using the $AnalyzeDate parameter, you must put your
    date in the format of yyyyMMdd.

    Dependencies
    JLECmd.exe (From Eric Zimmerman's Tools. stored in the Power-Response Bin directory)

.EXAMPLE
    
    Power-Response Execution

    For current date Analysis just execute 'run'

    To specify a date

    set AnalyzeDate 20190309
    run

.NOTES
    Author: Drew Schmitt
    Date Created: 4/11/2019
    Twitter: @5ynax
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param (
    [Parameter(Mandatory=$false,Position=0)]
    [System.Management.Automation.Runspaces.PSSession[]]$Session,

    [Parameter(Mandatory=$false,Position=1)]
    [DateTime]$AnalyzeDate= (Get-Date)

    )

process{

    #Format String Properly for use
    $AnalysisDate = ('{0:yyyyMMdd}' -f $AnalyzeDate)

    #Verify that bin dependencies are met
    $TestBin = Test-Path ("{0}\JLECmd.exe" -f (Get-PRPath -Bin))

    if (!$TestBin){

        Throw "JLECmd not found in {0}. Place executable in binary directory and try again." -f (Get-PRPath -Bin)
    }

    #Build list of hosts that have been analyzed with Power-Response
    $Machines = Get-ChildItem (Get-PRPath -Output)

    #Loop through and analyze files, while skipping if the analysis directory exists
    foreach ($Machine in $Machines){

        #Path to verify for existence before processing 
        $JumpItemsPath = ("{0}\{1}\Execution\Jumplists_{2}\") -f (Get-PRPath -Output),$Machine,$AnalysisDate

        if (Test-Path $JumpItemsPath) {
        
            #Get Users that have jumplist data collected
            $Users = Get-ChildItem $JumpItemsPath

            foreach ($User in $Users){

                #Path to data
                $JumpItemsData = "$JumpItemsPath\$User"

                #Determine if output directory exists
                if (Test-Path $JumpItemsData){

                    #Verify that prefetch has not already been analyzed
                    $JumpItemsProcessed = "$JumpItemsData\Analysis\"

                    if (!(Test-Path $JumpItemsProcessed)) {

                        #Create Analysis Directory
                        New-Item -Type Directory -Path $JumpItemsProcessed | Out-Null

                        #Process data and store in analysis directory
                        $Command = ("{0}\JLECmd.exe -d {1} --csv {2}") -f (Get-PRPath -Bin),$JumpItemsData,$JumpItemsProcessed

                        Invoke-Expression -Command $Command | Out-Null

                    } else {

                        #Prevent additional processing of data already analyzed
                        continue
                    }
                }
            }
        }
    }
}
