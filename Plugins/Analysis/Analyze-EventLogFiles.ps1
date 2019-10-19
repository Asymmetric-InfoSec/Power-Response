<#

.SYNOPSIS
    Plugin-Name: Analyze-EventLogFiles.ps1
    
.Description
    Analyzes recovered event logs from the remote system(s).
    There are checks built in to not analyze twice. By default, the plugin will look for 
    results from the current date. 

    Dependencies
    EvtxECmd.exe (From Eric Zimmerman's Tools. Stored in the Power-Response Bin directory)

.EXAMPLE
    
    Power-Response Execution
    run

.NOTES
    Author: Drew Schmitt
    Date Created: 5/23/2019
    Twitter: @5ynax
    
    Last Modified By: Drew Schmitt
    Last Modified Date: 10/04/2019
    Twitter: @5ynax
  
#>

param (

    [Parameter(Mandatory=$true,Position=0)]
    [System.Management.Automation.Runspaces.PSSession[]]$Session

)

process{

     # Get the plugin name
    $PluginName = $MyInvocation.MyCommand.Name -Replace '.+-' -Replace '\..+'

    # Get encryption password
    $EncryptPassword = Get-PRConfig -Property 'EncryptPassword'

    # Get system architecture
    $Architecture = Get-CimInstance -Class 'Win32_OperatingSystem' -Property 'OSArchitecture' | Select-Object -ExpandProperty 'OSArchitecture'

    # Define $Dependency tracking structure
    $Dependency = [Ordered]@{
        SevenZip = @{
            Command = '& "<DEPENDENCYPATH>" x -p{0} <ZIPPATH> -o<OUTPUTPATH>' -f $EncryptPassword
            Path = @{
                '32-bit' = Join-Path -Path (Get-PRPath -Bin) -ChildPath '7za_x86.exe'
                '64-bit' = Join-Path -Path (Get-PRPath -Bin) -ChildPath '7za_x64.exe'
            }
        }
        EvtxECmd = @{
            Command = '& "<DEPENDENCYPATH>" -f "<ARTIFACTPATH>" --csv "<ANALYSISFOLDERPATH>" --csvf "<ANALYSISFILENAME>" --inc "<EVENTIDLIST>"'
            Path = @{
                '32-bit' = Join-Path -Path ("$(Get-PRPath -Bin)\EvtxExplorer") -ChildPath 'EvtxECmd.exe'
                '64-bit' = Join-Path -Path ("$(Get-PRPath -Bin)\EvtxExplorer") -ChildPath 'EvtxECmd.exe'
            }
            Logs = @{

                Security = @{

                    LogName = "Security.evtx"
                    ProcessedEvents = 1102,4624,4625,4634,4647,4648,4672,4688,4697,4698,4699,4700,4701,4702,4719,4720,4722,4724,4728,4732,4735,4738,4756,4765,4766,4768,4769,4771,4776,4778,4779,4798,4799,4964
                }
                System = @{

                    LogName = "System.evtx"
                    ProcessedEvents = 10000,10001,1001,10100,104,1056,20001,20002,20003,24576,24577,24579,7030,7034,7035,7036,7040,7045
                }
                Application = @{

                    LogName = "Application.evtx"
                    ProcessedEvents = 1000,1001,1002,1033,1034,11707,11708,11724
                }
                WinFirewall = @{

                    LogName = "Microsoft-Windows-Windows Firewall With Advanced Security%4Firewall.evtx"
                    ProcessedEvents = 2003
                }
                PowerShell = @{

                    LogName = "Microsoft-Windows-PowerShell%4Operational.evtx"
                    ProcessedEvents = 4104,4105,4106
                }
                WMI = @{

                    LogName = "Microsoft-Windows-WMI-Activity%4Operational.evtx"
                    ProcessedEvents = 5857,5858,5859,5860,5861
                }
                RDP_TC_RDPClient = @{

                    LogName = "Microsoft-Windows-TerminalServices-RDPClient%4Operational.evtx"
                    ProcessedEvents = 1024,1102
                }
                RDP_TC_RCM = @{

                    LogName = "Microsoft-Windows-TerminalServices-RemoteConnectionManager%4Operational.evtx"
                    ProcessedEvents = 1149
                }
                RDP_TC_LSM = @{

                    LogName = "Microsoft-Windows-TerminalServices-LocalSessionManager%4Operational.evtx"
                    ProcessedEvents = 21,22,25,41
                }
                RDP_RdpTS = @{

                    LogName = "Microsoft-Windows-RemoteDesktopServices-RdpCoreTS%4Operational.evtx"
                    ProcessedEvents = 98,131
                }
                SchedTasks = @{

                    LogName = "Microsoft-Windows-TaskScheduler%4Operational.evtx"
                    ProcessedEvents = 106,140,141,200,201
                }
            }
        }
    }

    # Verify the each $Dependency exe exists
    $Dependency | Select-Object -ExpandProperty 'Keys' -PipelineVariable 'Dep' | Foreach-Object { $Dependency.$Dep.Path.GetEnumerator() | Where-Object { !(Test-Path -Path $PSItem.Value -PathType 'Leaf') } | Foreach-Object { throw ('{0} version of {1} not detected in Bin. Place {0} executable in Bin directory and try again.' -f $PSItem.Key,$Dep) } }

    # Figure out which folders to process
    $ToProcess = Get-ChildItem -Recurse -Force -Path (Get-PRPath -Output) | Where-Object { $PSItem.Name -Match $PluginName -and $PSItem.Name -NotMatch 'Analysis' -and $PSItem.PSIsContainer } | Where-Object { !(Get-ChildItem -Path $PSItem.FullName | Where-Object { $PSItem.Name -Match 'Analysis' }) }

    foreach ($ArtifactDirectory in $ToProcess) {
        # Get the zip file
        $ZipPath = Get-ChildItem -File -Force -Path $ArtifactDirectory.FullName | Where-Object { $PSItem.Name -Match '.+\.zip' } | Select-Object -First 1 -ExpandProperty 'FullName'

        # Build command
        $Command = $Dependency.SevenZip.Command -Replace '<DEPENDENCYPATH>',$Dependency.SevenZip.Path.$Architecture -Replace '<ZIPPATH>',$ZipPath -Replace '<OUTPUTPATH>',$ArtifactDirectory.FullName

        # Run the command
        $null = Invoke-Expression -Command $Command

        # Get root path to all artifacts
        $ArtifactRoot = '{0}\C\Windows\System32\winevt\logs' -f $ArtifactDirectory.FullName

        # Get the unzipped artifact paths
        $Artifacts = $Dependency.EvtxEcmd.Logs.Keys

        # Naming convention {DIRNAME}_Analysis
        $AnalysisDirectoryName = '{0}_Analysis' -f $ArtifactDirectory.Name

        # Build Analysis directory
        $AnalysisDirectory = Join-Path -Path $ArtifactDirectory.FullName -ChildPath $AnalysisDirectoryName | Foreach-Object { New-Item -Type 'Directory' -Path $PSItem }

        foreach ($ArtifactPath in $Artifacts) {
            # Build the log file
            $LogFile = Join-Path -Path $AnalysisDirectory.FullName -ChildPath ('EvtxECmd_{0}_Log.txt' -f $ArtifactPath)

            # Build the command
            $Command = $Dependency.EvtxECmd.Command -Replace '<DEPENDENCYPATH>',$Dependency.EvtxECmd.Path.$Architecture -Replace '<ARTIFACTPATH>',('{0}\{1}' -f $ArtifactRoot,($Dependency.Evtxecmd.Logs.$ArtifactPath.LogName)) -Replace '<ANALYSISFOLDERPATH>',$AnalysisDirectory.FullName -Replace '<ANALYSISFILENAME>',('{0}_EvtxECMD_Data.csv' -f $ArtifactPath) -Replace '<EVENTIDLIST>',($Dependency.EvtxEcmd.Logs.$ArtifactPath.ProcessedEvents)

            # Run the command
            Invoke-Expression -Command $Command -ErrorAction 'SilentlyContinue' | Out-File -FilePath $LogFile
        }
    }
}
