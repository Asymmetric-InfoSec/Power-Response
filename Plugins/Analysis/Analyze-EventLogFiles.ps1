<#

.SYNOPSIS
    Plugin-Name: Analyze-EventLogFiles.ps1
    
.Description
    Analyzes recovered event logs from the remote system(s).
    There are checks built in to not analyze twice. By default, the plugin will look for 
    results from the current date. You can specify the analysis date with the
    $AnalyzeDate parameter. When using the $AnalyzeDate parameter, you must put your
    date in the format of yyyyMMdd.

    Dependencies
    EvtxECmd.exe (From Eric Zimmerman's Tools. Stored in the Power-Response Bin directory)

.EXAMPLE
    
    Power-Response Execution

    For current date Analysis just execute 'run'

    To specify a date

    set AnalyzeDate 20190309
    run

.NOTES
    Author: Drew Schmitt
    Date Created: 5/23/2019
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
    $TestBin = Test-Path ("{0}\EvtxExplorer\EvtxECmd.exe" -f (Get-PRPath -Bin))

    if (!$TestBin){

        Throw "EvtxECmd not found in {0}. Place executable in binary directory and try again." -f (Get-PRPath -Bin)
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

    #Hashtables for the different log types to be processed

    $SecurityLog = @{

        LogName = "Security.evtx"
        ProcessedEvents = 1102,4624,4625,4634,4647,4648,4672,4688,4697,4698,4699,4700,4701,4702,4719,4720,4722,4724,4728,4732,4735,4738,4756,4765,4766,4768,4769,4771,4776,4778,4779,4798,4799,4964
        OutputName = 'SecurityEvents.csv'
    }

     $SystemLog = @{

        LogName = "System.evtx"
        ProcessedEvents = 10000,10001,1001,10100,104,1056,20001,20002,20003,24576,24577,24579,7030,7034,7035,7036,7040,7045
        OutputName = 'SystemEvents.csv'
    }

     $ApplicationLog = @{

        LogName = "Application.evtx"
        ProcessedEvents = 1000,1001,1002,1033,1034,11707,11708,11724
        OutputName = 'ApplicationEvents.csv'
    }

     $WinFirewallLog = @{

        LogName = "Microsoft-Windows-Windows Firewall With Advanced Security%254Firewall.evtx"
        ProcessedEvents = 2003
        OutputName = 'WindowsFirewallEvents.csv'
    }

     $PowerShellLog = @{

        LogName = "Microsoft-Windows-PowerShell%254Operational.evtx"
        ProcessedEvents = 4104,4105,4106
        OutputName = 'PowerShellEvents.csv'
    }

     $WMILog = @{

        LogName = "Microsoft-Windows-WMI-Activity%254Operational.evtx"
        ProcessedEvents = 5857,5858,5859,5860,5861
        OutputName = 'WMIEvents.csv'
    }

     $RDP_TC_RDPClientLog = @{

        LogName = "Microsoft-Windows-TerminalServices-RDPClient%254Operational.evtx"
        ProcessedEvents = 1024,1102
        OutputName = 'RDPClientEvents.csv'
    }

     $RDP_TC_RCMLog = @{

        LogName = "Microsoft-Windows-TerminalServices-RemoteConnectionManager%254Operational.evtx"
        ProcessedEvents = 1149
        OutputName = 'RDPConnManagerEvents.csv'
    }

     $RDP_TC_LSMLog = @{

        LogName = "Microsoft-Windows-TerminalServices-LocalSessionManager%254Operational.evtx"
        ProcessedEvents = 21,22,25,41
        OutputName = 'RDPLocalSessionManEvents.csv'
    }

     $RDP_RdpTSLog = @{

        LogName = "Microsoft-Windows-RemoteDesktopServices-RdpCoreTS%254Operational.evtx"
        ProcessedEvents = 98,131
        OutputName = 'RDPCoreTSEvents.csv'
    }

     $SchedTasksLog = @{

        LogName = "Microsoft-Windows-TaskScheduler%254Operational.evtx"
        ProcessedEvents = 106,140,141,200,201
        OutputName = 'ScheduledTaskEvents.csv'
    }

    $MachineLogs = @($SecurityLog, $SystemLog, $ApplicationLog, $WinFirewallLog, $PowerShellLog, $WMILog, $RDP_TC_RDPClientLog, $RDP_TC_RCMLog, $RDP_TC_LSMLog, $RDP_RdpTSLog, $SchedTasksLog)

    #Loop through and analyze prefetch files, while skipping if the analysis directory exists
    foreach ($Machine in $Machines){

        #Path to verify for existence before processing prefetch
        $EvtxPath = ("{0}\{1}\Logs\EventLogFiles_{2}") -f (Get-PRPath -Output), $Machine, $AnalysisDate

        #Determine if prefetch output directory exists
        if (Test-Path $EvtxPath){

            #Verify that prefetch has not already been analyzed
            $EvtxProcessed = ("{0}\{1}\Logs\EventLogFiles_{2}\Analysis") -f (Get-PRPath -Output), $Machine, $AnalysisDate

            if (!(Test-Path $EvtxProcessed)) {

                #Create Analysis Directory
                New-Item -Type Directory -Path $EvtxProcessed | Out-Null

                $EvtxDataExtracted = ("{0}\{1}" -f $EvtxPath,$Machine)

                if (!(Test-Path $EvtxDataExtracted)){

                    #Decompress zipped archive
                    $Command = ("& '{0}\{1}' x '{2}\{3}_EventLogFiles.zip' -o{2}") -f (Get-PRPath -Bin),(Split-Path $Installexe -Leaf),$EvtxPath,$Machine

                    Invoke-Expression -Command $Command | Out-Null
                }

                #Loop through and process each log in MachineLogs
                foreach ($Log in $MachineLogs){

                    #Process and store in analysis directory
                    $Command = ("& '{0}\EvtxExplorer\EvtxECmd.exe' -f {1}\{2}\C\Windows\System32\winevt\Logs\{3} --csv {4} --csvf {5} --inc {6}") -f ((Get-PRPath -Bin),$EvtxPath,$Machine,$Log.LogName,$EvtxProcessed,$Log.OutputName,($Log.ProcessedEvents -join ','))

                    Invoke-Expression -Command $Command | Out-File -FilePath ("{0}\EvtxECmd_Log.txt" -f $EvtxProcessed) -Append

                }

            } else {

                #Prevent additional processing of prefetch already analyzed
                continue
            }
        }

    }
}