<#

.SYNOPSIS
    Plugin-Name: Analyze-Prefetch.ps1
    
.Description
    Analyzes recovered prefetch files for all hosts that you have collected data from.
    There are checks built in to not analyze twice. By default, the plugin will look for 
    prefetch results from the current date.

    Dependencies
    PECmd.exe (From Eric Zimmerman's Tools. stored in the Power-Response Bin directory)

.EXAMPLE
    
    Power-Response Execution

    For current date Analysis just execute 'run'

    To specify a date

    set AnalyzeDate 20190309
    run

.NOTES
    Author: Drew Schmitt
    Date Created: 3/9/2019
    Twitter: @5ynax
    
    Last Modified By: Drew Schmitt
    Last Modified Date: 10/04/2019
    Twitter:@5ynax
  
#>

param (

    [Parameter(Mandatory=$false,Position=0)]
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
        PECmd = @{
            Command = '& "<DEPENDENCYPATH>" -d <ARTIFACTPATH> --csv <ANALYSISFOLDERPATH>'
            Path = @{
                '32-bit' = Join-Path -Path (Get-PRPath -Bin) -ChildPath 'PECmd.exe'
                '64-bit' = Join-Path -Path (Get-PRPath -Bin) -ChildPath 'PECmd.exe'
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

        # Get the unzipped artifact paths
        $Artifacts = Get-ChildItem -Force -Directory -Path $ArtifactDirectory.FullName | Where-Object { $PSItem.Name -eq 'C' -and $PSItem.PSIsContainer }

        # Naming convention {DIRNAME}_Analysis
        $AnalysisDirectoryName = '{0}_Analysis' -f $ArtifactDirectory.Name

        # Build Analysis directory
        $AnalysisDirectory = Join-Path -Path $ArtifactDirectory.FullName -ChildPath $AnalysisDirectoryName | Foreach-Object { New-Item -Type 'Directory' -Path $PSItem }

        foreach ($ArtifactPath in $Artifacts) {
            # Build the log file
            $LogFile = Join-Path -Path $AnalysisDirectory.FullName -ChildPath ('PECmd_{0}_Log.txt' -f $ArtifactPath.Name)

            # Build the command
            $Command = $Dependency.PECmd.Command -Replace '<DEPENDENCYPATH>',$Dependency.PECmd.Path.$Architecture -Replace '<ARTIFACTPATH>',$ArtifactPath.FullName -Replace '<ANALYSISFOLDERPATH>',$AnalysisDirectory.FullName

            # Run the command
            Invoke-Expression -Command $Command -ErrorAction 'SilentlyContinue' | Out-File -FilePath $LogFile
        }
    }
}
