<#

.SYNOPSIS
    Plugin-Name: Analyze-Amcache.ps1
    
.Description
    Analyzes recovered amcache hives for all hosts that you have collected data from.
    There are checks built in to not analyze twice. By default, the plugin will look for 
    results from the current date. You can specify the analysis date with the
    $AnalyzeDate parameter. When using the $AnalyzeDate parameter, you must put your
    date in the format of yyyyMMdd.

    Dependencies
    AmcacheParser.exe (From Eric Zimmerman's Tools. stored in the Power-Response Bin directory)

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

    [Parameter(Mandatory=$true,Position=0)]
    [System.Management.Automation.Runspaces.PSSession]$Session,

    [Parameter(Mandatory=$false,Position=1)]
    [DateTime]$AnalyzeDate= (Get-Date)

    )

process{

    #Verify that 7za executables are located in (Get-PRPath -Bin)

    $7za32 = ("{0}\7za_x86.exe" -f (Get-PRPath -Bin))
    $7za64 = ("{0}\7za_x64.exe" -f (Get-PRPath -Bin))

    $7z64bitTestPath = Get-Item -Path $7za64 -ErrorAction SilentlyContinue
    $7z32bitTestPath = Get-Item -Path $7za32 -ErrorAction SilentlyContinue

    if (!$7z64bitTestPath) {

        Throw "64 bit version of 7za.exe not detected in Bin. Place 64bit executable in Bin directory and try again."

    } elseif (!$7z32bitTestPath) {

        Throw "32 bit version of 7za.exe not detected in Bin. Place 32bit executable in Bin directory and try again."
    }

    #Verify that analysis bin dependencies are met
    $TestBin = Test-Path ("{0}\AmcacheParser.exe" -f (Get-PRPath -Bin))

    if (!$TestBin){

        Throw "AmcacheParser not found in {0}. Place executable in binary directory and try again." -f (Get-PRPath -Bin)
    }

     #Determine system architecture and select proper 7za.exe and Velociraptor executables
    try {
     
        $Architecture = (Get-WmiObject -Class Win32_OperatingSystem -Property OSArchitecture -ErrorAction Stop).OSArchitecture
    
        if ($Architecture -eq "64-bit") {

            $Installexe = $7za64

        } elseif ($Architecture -eq "32-bit") {

            $Installexe = $7za32

        } else {
        
            Write-Error ("Unknown system architecture ({0}) detected. Data was not gathered.)" -f $Architecture)
            Continue
        }

    } catch {
    
     Write-Error ("Unable to determine system architecture. Data was not gathered.")
        Exit
    }

    #Format String Properly for use
    $AnalysisDate = ('{0:yyyyMMdd}' -f $AnalyzeDate)

    #Build list of hosts that have been analyzed with Power-Response
    $Machines = Get-ChildItem (Get-PRPath -Output)

    #Loop through and analyze amcache files, while skipping if the analysis directory exists
    foreach ($Machine in $Machines){

        #Path to verify for existence before processing amcache
        $AmcachePath = ("{0}\{1}\Execution\Amcache_{2}\") -f (Get-PRPath -Output), $Machine, $AnalysisDate

        #Determine if amcache output directory exists
        if (Test-Path $AmcachePath){

            #Verify that amcache has not already been analyzed
            $AmcacheProcessed = "$AmcachePath\Analysis\"

            if (!(Test-Path $AmcacheProcessed)) {

                #Create Analysis Directory
                New-Item -Type Directory -Path $AmcacheProcessed | Out-Null

                #Decompress zipped archive
                $Command = ("& '{0}\{1}' x {2}\{3}_Amcache.zip -o{2}") -f (Get-PRPath -Bin),(Split-Path $Installexe -Leaf),$AmcachePath,$Machine

                Invoke-Expression -Command $Command | Out-Null 

                #Process and store in analysis directory
                $Command = ("& '{0}\AmcacheParser.exe' -f {1}\{2}\c\windows\appcompat\Programs\Amcache.hve --csv {3}") -f (Get-PRPath -Bin),$AmcachePath,$Machine,$AmcacheProcessed

                Invoke-Expression -Command $Command | Out-Null

            } else {

                #Prevent additional processing of amcache already analyzed
                continue
            }
        }
    }
}