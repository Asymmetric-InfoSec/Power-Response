#Requires -Module PSSQLite
<#

.SYNOPSIS
    Plugin-Name: Analyze-BrowsingHistory.ps1
    
.Description
    Analyzes recovered browser history files all hosts that you have collected data from.
    There are checks built in to not analyze twice. By default, the plugin will look for 
    results from the current date. 

    Dependencies
    PSSQLite module (From Rambling Cookie Monster, installed on setup script execution)

.EXAMPLE
    
    Power-Response Execution
    run

.NOTES
    Author: Gavin Prentice
    Date Created: 2/18/2020
    Twitter: @valrkey
    
    Last Modified By: 
    Last Modified Date: 
    Twitter: 
  
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
        $Artifacts = Get-ChildItem -Force -Recurse -Path $ArtifactDirectory.FullName | Where-Object { $PSItem.Name -eq 'History' }

        # Naming convention {DIRNAME}_Analysis
        $AnalysisDirectoryName = '{0}_Analysis' -f $ArtifactDirectory.Name

        # Build Analysis directory
        $AnalysisDirectory = Join-Path -Path $ArtifactDirectory.FullName -ChildPath $AnalysisDirectoryName | Foreach-Object { New-Item -Type 'Directory' -Path $PSItem }
        
        foreach ($ArtifactPath in $Artifacts) {
            # Format the CSV name
            $CsvName = '{0}_chrome-history_<TABLE>.csv' -f ($ArtifactPath.FullName -Replace '.+\\C\\Users\\' -Replace '\\.+')

            # Set up urls table export csv file path
            $CsvPath = Join-Path -Path $AnalysisDirectory.FullName -ChildPath $CsvName

            # Create the readonly SQLite connection
            $Connection = New-SQLiteConnection -DataSource $ArtifactPath.FullName -ReadOnly -Open:$true

            # Set up urls table query
            $Query = "SELECT url, title, visit_count,datetime(urls.last_visit_time / 1000000 + (strftime('%s', '1601-01-01')), 'unixepoch') AS last_visit from urls"

            # Dump urls table to CSV
            Invoke-SqliteQuery -SqliteConnection $Connection -Query $Query | Export-Csv -NoTypeInformation -Path ($CsvPath -Replace '<TABLE>','urls')

            # Set up downloads table query
            $Query = "SELECT current_path, target_path, total_bytes, received_bytes, opened, datetime(start_time / 1000000 + (strftime('%s', '1601-01-01')), 'unixepoch') AS start_time,datetime(end_time / 1000000 + (strftime('%s', '1601-01-01')), 'unixepoch') AS end_time from downloads"

            # Dump downloads table to CSV
            Invoke-SqliteQuery -SqliteConnection $Connection -Query $Query | Export-Csv -NoTypeInformation -Path ($CsvPath -Replace '<TABLE>','downloads')

            # Close the SQLite connection
            $Connection.Close()
        }
    }
}
