<#

.SYNOPSIS
    Plugin-Name: Analyze-NTFSArtifacts.ps1
    
.Description
    Analyzes recovered NTFS artifacts for all hosts that you have collected data from.
    There are checks built in to not analyze twice. By default, the plugin will look for 
    results from the current date. You can specify the analysis date with the
    $AnalyzeDate parameter. When using the $AnalyzeDate parameter, you must put your
    date in the format of yyyyMMdd.

    Dependencies
    MFTECmd.exe (From Eric Zimmerman's Tools. stored in the Power-Response Bin directory)

    Note: $LogFile and $Boot are listed as being able to be parsed by MFTECmd per 
    Eric Zimmerman's website, but the functionality has not been added yet. The plugin
    has executions for these included below in preparation for future releases.

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
    
    Last Modified By: Gavin Prentice
    Last Modified Date: 10/3/2019
    Twitter: @valrkey
  
#>

param (

    [Parameter(Mandatory=$true,Position=0)]
    [System.Management.Automation.Runspaces.PSSession[]]$Session

)

process {
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
        MFTECmd = @{
            Command = '& "<DEPENDENCYPATH>" -f <ARTIFACTPATH> --csv <ANALYSISFOLDERPATH>'
            Path = @{
                '32-bit' = Join-Path -Path (Get-PRPath -Bin) -ChildPath 'MFTECmd.exe'
                '64-bit' = Join-Path -Path (Get-PRPath -Bin) -ChildPath 'MFTECmd.exe'
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
        $Artifacts = Get-ChildItem -Force -Directory -Path $ArtifactDirectory.FullName | Get-ChildItem -Force -Recurse -File

        # Naming convention {DIRNAME}_Analysis
        $AnalysisDirectoryName = '{0}_Analysis' -f $ArtifactDirectory.Name

        # Build Analysis directory
        $AnalysisDirectory = Join-Path -Path $ArtifactDirectory.FullName -ChildPath $AnalysisDirectoryName | Foreach-Object { New-Item -Type 'Directory' -Path $PSItem }

        foreach ($ArtifactPath in $Artifacts) {
            # Build the log file
            $LogFile = Join-Path -Path $AnalysisDirectory.FullName -ChildPath ('MFTECmd_{0}_Log.txt' -f $ArtifactPath.Name)

            # Build the command
            $Command = $Dependency.MFTECmd.Command -Replace '<DEPENDENCYPATH>',$Dependency.MFTECmd.Path.$Architecture -Replace '<ARTIFACTPATH>',$ArtifactPath.FullName -Replace '<ANALYSISFOLDERPATH>',$AnalysisDirectory.FullName

            # Run the command
            Invoke-Expression -Command $Command -ErrorAction 'SilentlyContinue' | Out-File -FilePath $LogFile
        }
    }
}
