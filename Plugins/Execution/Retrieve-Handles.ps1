<#

.SYNOPSIS
    Plugin-Name: Retrieve-Handles.ps1
    
.Description

	Collects handles information from remote systems for further analysis

.EXAMPLE

	Power-Response Execution

	set ComputerName Test-PC
	run

.NOTES
    Author: Drew Schmitt
    Date Created: 3/16/2019
    Twitter: @5ynax
    
    Last Modified By: Drew Schmitt
    Last Modified Date: 10/08/2019
    Twitter: @5ynax
  
#>
[cmdletbinding()]
param (

    [Parameter(Mandatory=$true,Position=0)]
    [System.Management.Automation.Runspaces.PSSession[]]$Session

)

process {

    # Get stage directory
    $RemoteStageDirectory = Get-PRConfig -Property 'RemoteStagePath'

    # Define $Dependency tracking structure
    $Dependency = [Ordered]@{
        Handles = @{
            Command = '$Raw = Invoke-Expression "<DEPENDENCYPATH> -accepteula" | Select-Object -Skip 5; $Handles = $Raw | Select-Object -Property @{ N = "Process"; E = { ($_ -split ''(?<!:)\s+'')[0] } }, @{ N = "ID"; E = { (($_ -split ''(?<!:)\s+'')[1] -replace ''pid:\s*'') } }, @{ N = "Type"; E = { ($_ -split ''(?<!:)\s+'')[2] -replace ''type:\s*'' } }, @{ N = "Path"; E = { ($_ -split ''(?<!:)\s+'')[3] -replace ''^[^ ]*: '' } }; [PSCustomObject]$Handles'
            Path = @{
                '32-bit' = Join-Path -Path (Get-PRPath -Bin) -ChildPath 'Handle.exe'
                '64-bit' = Join-Path -Path (Get-PRPath -Bin) -ChildPath 'Handle64.exe'
            }
            TestPath = (Join-Path -Path $RemoteStageDirectory -ChildPath 'Handle*.exe')
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

    #Collect Data from the remote machine

    Invoke-Command -Session $Session -Scriptblock {
        # Pull remote Dependency into a local variable in each session
        $Dependency = $using:Dependency

        # Get all non-exe paths in the remote stage directory
        $Path = Get-ChildItem -Force -Path $using:RemoteStageDirectory -Exclude '*.exe' | Select-Object -ExpandProperty 'FullName'

        foreach ($Key in $Dependency.Keys) {
            # Get actual dependency path
            $DependencyPath = Get-Item -Path $Dependency.$Key.TestPath -ErrorAction 'SilentlyContinue' | Select-Object -First 1 -ExpandProperty 'FullName'

            # Create dependency command
            $Command = $Dependency.$Key.Command -Replace '<DEPENDENCYPATH>',$DependencyPath -Replace '<PATH>',($Path -Join ' ')

            # Execute dependency command
            Invoke-Expression -Command $Command
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
