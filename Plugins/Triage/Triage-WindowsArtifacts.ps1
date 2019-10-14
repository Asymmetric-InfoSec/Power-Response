<#

.SYNOPSIS
    Plugin-Name: Triage-WindowsArtifacts.ps1
    
.Description

    Grabs relevant Windows Artifacts and performs analysis to 
    speed up the investigation process. This plugin runs the following
    plugins to gather information:

    Invoke-PRPlugin -Name Retrive-NTFSArtifacts.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrive-RegistryHives.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrive-EventLogFiles.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrive-Amcache.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrive-Prefetch.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrive-ShimCache.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrive-ScheduledTasks.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrive-Startup.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrive-RecentItems.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrive-JumpLists.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrive-RecycleBin.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrive-Shellbags.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrive-BrowsingHistory.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrive-HostsFile.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrive-WindowsSearchData.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrive-SRUMDB.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrive-PSReadLine.ps1 -Session $Session

.EXAMPLE

    Power-Response Execution

    set computername test-pc
    run

.NOTES
    Author: Drew Schmitt
    Date Created: 5/10/2019
    Twitter: @5ynax
    
    Last Modified By: Drew Schmitt
    Last Modified Date: 09/30/2019
    Twitter: @5ynax
  
#>

param (

    [Parameter(Mandatory=$true,Position=0)]
    [System.Management.Automation.Runspaces.PSSession[]]$Session,

    [Switch]$Force

)

process {

    # Get the plugin name
    $PluginName = $MyInvocation.MyCommand.Name -Replace '\..+'

    # Remote archive name with second count for randomness
    $PluginOutputName = '{0}_{1}' -f ($PluginName -Replace '.+-'),(Get-Date -UFormat %s).Split('.')[0]

    $SessionCopy = $Session

    # If we are not forcing through, see if we have collected artifacts already
    if (!$Force) {
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
    }

    # If we don't have any sessions left, return
    if ($SessionCopy) {
        $Session = $SessionCopy
    } else {
        return
    }

    # Get stage directory
    $RemoteStageDirectory = Get-PRConfig -Property 'RemoteStagePath'

    # Define $Dependency tracking structure
    $Dependency = [Ordered]@{
        SevenZip = @{
            Command = '& "<DEPENDENCYPATH>" a -p{0} -tzip {1} <PATH>' -f $EncryptPassword,$Archive
            Path = @{
                '32-bit' = Join-Path -Path (Get-PRPath -Bin) -ChildPath '7za_x86.exe'
                '64-bit' = Join-Path -Path (Get-PRPath -Bin) -ChildPath '7za_x64.exe'
            }
            TestPath = @('C:\Program Files\7-Zip\7z.exe',(Join-Path -Path $RemoteStageDirectory -ChildPath '7za*.exe'))
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

    # Begin plugin logic
    Invoke-PRPlugin -Name Retrieve-NTFSArtifacts.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrieve-FLSBody.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrieve-RegistryHives.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrieve-EventLogFiles.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrieve-Amcache.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrieve-Prefetch.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrieve-ShimCache.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrieve-ScheduledTasks.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrieve-Startup.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrieve-RecentItems.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrieve-JumpLists.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrieve-RecycleBin.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrieve-Shellbags.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrieve-BrowsingHistory.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrieve-HostsFile.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrieve-WindowsSearchData.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrieve-SRUMDB.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrieve-PSReadLine.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-SystemInfo.ps1 -Session $Session
    # End plugin logic
    
    # Begin dependency cleanup logic
    # Remove created files on remote machine as cleanup
    Invoke-Command -Session $Session -ScriptBlock {
        # Remove the staging directory
        Remove-Item -Force -Recurse -Path $using:RemoteStageDirectory -ErrorAction 'SilentlyContinue'
    }
    # End dependency cleanup logic
}
