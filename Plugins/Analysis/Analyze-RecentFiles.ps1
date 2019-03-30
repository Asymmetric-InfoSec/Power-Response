<#

.SYNOPSIS
    Plugin-Name: Analyze-RecentItems.ps1
    
.Description
    Analyzes recovered lnk files from recent items for all hosts that you have collected data from.
    There are checks built in to not analyze twice. By default, the plugin will look for 
    recent items results from the current date. You can specify the analysis date with the
    $AnalyzeDate parameter. When using the $AnalyzeDate parameter, you must put your
    date in the format of yyyyMMdd.

    Dependencies
    LECmd.exe (From Eric Zimmerman's Tools. stored in the Power-Response Bin directory)

.EXAMPLE
    
    Power-Response Execution

    For current date Analysis just execute 'run'

    To specify a date

    set AnalyzeDate 20190309
    run

.NOTES
    Author: Drew Schmitt
    Date Created: 3/12/2019
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
    $AnalysisDate = ($AnalyzeDate.ToString('yyyy-MM-dd'))

    #Verify that bin dependencies are met
    $TestBin = Test-Path ("{0}\LECmd.exe" -f $global:PowerResponse.Config.Path.Bin)

    if (!$TestBin){

        Throw "LECmd not found in {0}. Place executable in binary directory and try again." -f $global:PowerResponse.Config.Path.Bin
    }

    #Build list of hosts that have been analyzed with Power-Response
    $Machines = Get-ChildItem $global:PowerResponse.OutputPath

    #Loop through and analyze prefetch files, while skipping if the analysis directory exists
    foreach ($Machine in $Machines){
        #Path to verify for existence before processing prefetch
        $RecentItemsPath = ("{0}\{1}\{2}\RecentItems\") -f $global:PowerResponse.OutputPath,$Machine,$AnalysisDate
        
        #Get Users that have recent items data collected
        $Users = Get-ChildItem $RecentItemsPath

        foreach ($User in $Users){

            #Path to data
            $RecentItemsData = "$RecentItemsPath\$User"

            #Determine if prefetch output directory exists
            if (Test-Path $RecentItemsData){

                #Verify that prefetch has not already been analyzed
                $RecentItemsProcessed = "$RecentItemsData\Analysis\"

                if (!(Test-Path $RecentItemsProcessed)) {

                    #Create Analysis Directory
                    New-Item -Type Directory -Path $RecentItemsProcessed | Out-Null

                    #Process Prefetch and store in analysis directory
                    $Command = ("{0}\LECmd.exe -d {1} --csv {2}") -f $global:PowerResponse.Config.Path.Bin,$RecentItemsData,$RecentItemsProcessed

                    Invoke-Expression -Command $Command | Out-Null

                } else {

                    #Prevent additional processing of prefetch already analyzed
                    continue
                }
            }
        }
    }
}

