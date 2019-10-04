<#

.SYNOPSIS
    Plugin-Name: Retrieve-NTFSArtifacts.ps1
    
.Description
    This plugin collects NTFS artifacts from a remote system. 
    By default, this plugin will only run once each day unless the analyst uses the 
    force parameter

.EXAMPLE

    Power-Response Execution

    Set ComputerName Test-PC
    Run

.NOTES
    Author: Matt Weikert
    Date Created: 2/18/2019
    Twitter: @5k33tz
    
    Last Modified By: Gavin Prentice
    Last Modified Date: 10/3/2019
    Twitter: @valrkey
  
#>

param (

    [Parameter(Mandatory=$true,Position=0)]
    [System.Management.Automation.Runspaces.PSSession[]]$Session,

    [Parameter(Position=1)]
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

    # Get stage directory
    $RemoteStageDirectory = Get-PRConfig -Property 'RemoteStagePath'

    # Get encryption password
    $EncryptPassword = Get-PRConfig -Property 'EncryptPassword'

    # Remote archive name
    $Archive = (Join-Path -Path $RemoteStageDirectory -ChildPath $PluginOutputName) + '.zip'

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
        $Dependency.$Key.Deploy = Invoke-Command -Session $Session -ScriptBlock { $Key = $using:Key; $Dependency = $using:Dependency; Get-Item -Force -Path $Dependency.$Key.TestPath -ErrorAction 'SilentlyContinue' | Select-Object -First 1 } | Where-Object { !$PSItem } | Foreach-Object { Get-PSSession -InstanceId $PSItem.RunspaceId }

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

    # Collect System Artifacts    
    $SystemArtifacts = @(
        'C:\$MFT',
        'C:\$Boot',
        'C:\$Secure:$SDS',
        'C:\$LogFile',
        'C:\$Extend\$UsnJrnl:$J'
    )

    # Stage System Artifacts   
    try {        
        # Copy the files
        Copy-PRItem -Session $Session -Path $SystemArtifacts -Destination $RemoteStageDirectory
    } catch {
        # Caught an error
        Write-Warning -Message ('Copy-PRItem error: {0}' -f $PSItem)
    }

    # End plugin logic

    # Loop through dependencies and run the associated commands in order
    Invoke-Command -Session $Session -ScriptBlock {
        # Pull remote Dependency into a local variable in each session
        $Dependency = $using:Dependency

        # Get all non-exe paths in the remote stage directory
        $Path = Get-ChildItem -Force -Path $using:RemoteStageDirectory -Exclude '*.exe' | Select-Object -ExpandProperty 'FullName'

        foreach ($Key in $Dependency.Keys) {
            # Get actual dependency path
            $DependencyPath = Get-Item -Path $Dependency.$Key.TestPath | Select-Object -First 1 -ExpandProperty 'FullName'

            # Create dependency command
            $Command = $Dependency.$Key.Command -Replace '<DEPENDENCYPATH>',$DependencyPath -Replace '<PATH>',($Path -Join ' ')

            # Execute dependency command
            $null = Invoke-Expression -Command $Command
        }
    }

    # Copy output archive back to each output directory
    foreach ($Instance in $Session) {
        # Set output for each specific instance of session
        $Output = Get-PRPath -ComputerName $Instance.ComputerName -Directory $PluginOutputName

        # Create directory if it doesn't exist
        if (!(Test-Path -Path $Output -PathType 'Container')) {
            $null = New-Item -ItemType 'Directory' -Path $Output
        }

        # Copy each item to output
        Copy-Item -Path $Archive -Destination $Output -FromSession $Instance
    }

    # Remove created files on remote machine as cleanup
    Invoke-Command -Session $Session -ScriptBlock {
        # By default remove entire remote stage directory
        $RemovePath = $using:RemoteStageDirectory

        # Unless we have deployed exes there
        Get-ChildItem -Force -Path $using:RemoteStageDirectory -Include '*.exe' | Select-Object -First 1 | Foreach-Object { $RemovePath = $Path }

        # Remove the archive
        Remove-Item -Force -Recurse -Path $RemovePath
    }

    # Remove $Dependency if deployed by this plugin
    $Dependency.Keys | Where-Object { $Dependency.$PSItem.Deploy } | Foreach-Object { Invoke-Command -Session $Dependency.$Key.Deploy -ScriptBlock { $Key = $using:Key; $Dependency = $using:Dependency; Remove-Item -Force -Path $Dependency.$Key.TestPath } }
}
