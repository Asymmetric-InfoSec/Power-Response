<#

.SYNOPSIS
    Plugin-Name: Retrieve-AutoRuns.ps1
    
.Description
    This plugin gathers Auto Start Execution Points from one or several hosts
    using the autorunsc Sysinternals tool. This plugin runs autoruns with the
    following options on each host:

    autorunsc64.exe /accepteula -a * -h -nobanner [-vt] -s -t -c

    The options that are inlcuded in this execution are:

    -a             Specifies the ASEP type to collect (See below)
    -h             Collects several hashes of each ASEP
    -s             Verifies signatures of all ASEPs
    -t             Standardizes time in UTC format
    -c             Outputs in a CSV format
    -nobanner      Does not inlcude Autoruns banner
    /accepteula    Does not prompt for EULA acceptance

    Note: You can add in the -vt flag into the commands below if you want to submit
    hashes to VT for analysis. Consider your OPSEC plans before adding this in.

    This plugin opts for collection of all ASEPs available including:

    Boot execute, codecs, appinit DLLs, Explorer addons, sidebar gadgets, image
    highjacks, Internet Explorer addons, known DLLs, logon startups, WMI entries,
    Winsock protocol and network providers, Office addins, printer monitor DLLs,
    LSA security providers, Autostart services and non-disabled drivers, scheduled
    tasks, winlogon entries

    Note: If you are interested in running a different version of this command, you 
    can simply edit the Invoke-Command entry below and adjust as needed.

    Note: If you are using custom directory paths, you will need to edit the EXE 
    checks in the script so that it does not error and exit. Best practice, use the
    default paths provided by Power-Response.

    Dependencies:

    PowerShell remoting
    Autorunsc

.EXAMPLE

    PowerResponse Execution
    Set ComputerName Test-PC
    Run

.NOTES
    Author: Drew Schmitt
    Date Created: 12/29/2018
    Twitter: @5ynax
    
    Last Modified By: Drew Schmitt
    Last Modified Date: 10/11/2019
    Twitter: @5ynax
  
#>

param (

    [Parameter(Mandatory=$true,Position=0)]
    [System.Management.Automation.Runspaces.PSSession[]]$Session,

    [Parameter(Position=1)]
    [Switch]$Force

)

process{

     # Get the plugin name
    $PluginName = $MyInvocation.MyCommand.Name -Replace '\..+'

    # Remote archive name with second count for randomness
    $PluginOutputName = '{0}_{1}' -f ($PluginName -Replace '.+-'),(Get-Date -UFormat %s).Split('.')[0]


    # If we are not forcing through, see if we have collected artifacts already
    if (!$Force) {
        # Make a copy of session for manipulation
        $SessionCopy = $Session

        # Loop through each session computer name
        foreach ($ComputerName in $Session.ComputerName) {
            # Determine where the plugin log is
            $LogPath = Join-Path (Get-PRPath -Output) -ChildPath $ComputerName | Join-Path -ChildPath ('{0}_plugin-log.csv' -f $ComputerName) 

            # Make sure log file is there
            if (Test-Path -Path $LogPath -PathType 'Leaf') {
                # Check if this plugin has already been executed today
                Import-Csv -Path $LogPath -ErrorAction 'SilentlyContinue' | Where-Object { $PSItem.Success -and $PSItem.Plugin -eq $PluginName -and [DateTime]$PSItem.Date -gt (Get-Date).ToUniversalTime().Date } | Select-Object -First 1 | Foreach-Object {
                    # Write warning message to use Force parameter
                    Write-PRWarning -Message ("Plugin {0} has already been executed for system {1}. If you want to execute it again, use the 'Force' parameter" -f $PluginName,$ComputerName)

                    # Remove already executed session from tracked session list
                    $SessionCopy = $SessionCopy | Where-Object { $PSItem.ComputerName -ne $ComputerName }
                }
            }
        }

        # If we don't have any sessions left, return
        if ($SessionCopy) {
            $Session = $SessionCopy
        } else {
            return
        }
    }

    # Get stage directory
    $RemoteStageDirectory = Get-PRConfig -Property 'RemoteStagePath'

    # Get encryption password
    $EncryptPassword = Get-PRConfig -Property 'EncryptPassword'

    # Remote archive name
    $Archive = (Join-Path -Path $RemoteStageDirectory -ChildPath $PluginOutputName) + '.zip'

    # Define $Dependency tracking structure
    $Dependency = [Ordered]@{
        Autoruns = @{
            Command = '& "<DEPENDENCYPATH>" /accepteula -a * -h -nobanner -s -t -c *'
            Path = @{
                '32-bit' = Join-Path -Path (Get-PRPath -Bin) -ChildPath 'autorunsc.exe'
                '64-bit' = Join-Path -Path (Get-PRPath -Bin) -ChildPath 'autorunsc64.exe'
            }
            TestPath = @((Join-Path -Path $RemoteStageDirectory -ChildPath 'autoruns*.exe'))
        }
    }

    # Begin dependency deploy logic
    # Verify the each $Dependency exe exists
    $Dependency | Select-Object -ExpandProperty 'Keys' -PipelineVariable 'Dep' | Foreach-Object { $Dependency.$Dep.Path.GetEnumerator() | Where-Object { !(Test-Path -Path $PSItem.Value -PathType 'Leaf') } | Foreach-Object { throw ('{0} version of {1} not detected in Bin. Place {0} executable in Bin directory and try again.' -f $PSItem.Key,$Dep) } }

    foreach ($Key in $Dependency.Keys) {
        # Track all session we are deploying this dependency to
        $Dependency.$Key.Deploy = Invoke-Command -Session $Session -ScriptBlock { $Key = $using:Key; $Dependency = $using:Dependency; (Get-Item -Force -Path $Dependency.$Key.TestPath -ErrorAction 'SilentlyContinue' | Select-Object -First 1) -eq $null } | Where-Object { $PSItem } | Foreach-Object { Get-PSSession -InstanceId $PSItem.RunspaceId }
        
        foreach ($Instance in $Dependency.$Key.Deploy) {
            try {
                # Determine system $Architecture and select proper executable
                $Architecture = Invoke-Command -Session $Instance -ScriptBlock { if (!(Test-Path -Path $using:RemoteStageDirectory -PathType 'Container')) { $null = New-Item -Path $using:RemoteStageDirectory -ItemType 'Directory' }; Get-WmiObject -Class 'Win32_OperatingSystem' -Property 'OSArchitecture' -ErrorAction 'Stop' | Select-Object -ExpandProperty 'OSArchitecture' }
            } catch {
                # Unable to get $Architecture information
                $Warning = 'Unable to determine system architecture for {0}. Data was not gathered.' -f $Instance.ComputerName
            }

            # Ensure we are tracking a sensible $Architecture
            if ($Architecture -and $Dependency.$Key.Path.Keys -NotContains $Architecture) {
                $Warning = 'Unknown system architecture ({0}) detected for {1}. Data was not gathered.)' -f $Architecture, $Instance.ComputerName
            }

            # If we ran into problems with the above checks
            if ($Warning) {
                # Write the warning
                Write-PRWarning -Message $Warning

                # Remove the failed $Session for master and deploy list
                $Session = $Session | Where-Object { $PSItem.ComputerName -ne $Instance.ComputerName }
                $Dependency.$Key.Deploy = $Dependency.$Key.Deploy | Where-Object { $PSItem.ComputerName -ne $Instance.ComputerName }

                # Continue to next item
                continue
            }

            # Compute the $RemoteDependency path
            $RemoteDependency = Join-Path -Path $RemoteStageDirectory -ChildPath (Split-Path -Leaf -Path $Dependency.$Key.Path.$Architecture)

            try {
                # Copy dependency executable to the remote machine
                Copy-Item -Path $Dependency.$Key.Path.$Architecture -Destination $RemoteDependency -ToSession $Instance -Force -ErrorAction 'Stop'
            } catch {
                # Failed to copy dependency
                throw ('Could not copy {0} to remote machine. Quitting.' -f $Key)
            }
        }
    }
    # End dependency deploy logic

    # Start plguin logic

    # Loop through dependencies and run the associated commands in order
    Invoke-Command -Session $Session -ScriptBlock {
        # Pull remote Dependency into a local variable in each session
        $Dependency = $using:Dependency

        # Get all non-exe paths in the remote stage directory
        $Path = Get-ChildItem -Force -Path $using:RemoteStageDirectory -Exclude '*.exe' | Select-Object -ExpandProperty 'FullName'

        foreach ($Key in $Dependency.Keys) {
            # Get actual dependency path
            $DependencyPath = Get-Item -Path $Dependency.$Key.TestPath -ErrorAction 'SilentlyContinue' | Select-Object -First 1 -ExpandProperty 'FullName'

            # Create dependency command
            $Command = $Dependency.$Key.Command -Replace '<DEPENDENCYPATH>',$DependencyPath

            # Execute dependency command
            Invoke-Expression -Command $Command | ConvertFrom-CSV
        }
    }

    # End plugin logic

    # Remove $Dependency if deployed by this plugin
    $Dependency.Keys | Where-Object { $Dependency.$PSItem.Deploy } | Foreach-Object { Invoke-Command -Session $Dependency.$PSItem.Deploy -ScriptBlock { $Key = $using:PSItem; $Dependency = $using:Dependency; Remove-Item -Force -Path $Dependency.$Key.TestPath -ErrorAction 'SilentlyContinue' } }

    # Remove created files on remote machine as cleanup
    Invoke-Command -Session $Session -ScriptBlock {
        # By default remove entire remote stage directory
        $RemovePath = $using:RemoteStageDirectory

        # Unless we have deployed exes there
        Get-ChildItem -Force -Path $using:RemoteStageDirectory -Include '*.exe' | Select-Object -First 1 | Foreach-Object { $RemovePath = $Path }

        # Remove the archive
        Remove-Item -Force -Recurse -Path $RemovePath
    }
}
