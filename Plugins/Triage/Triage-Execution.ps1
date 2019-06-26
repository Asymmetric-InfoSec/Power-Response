<#

.SYNOPSIS
    Plugin-Name: Triage-Execution.ps1
    
.Description

    Grabs relevant Windows artifacts and data and performs analysis to 
    speed up the investigation process. This plugin runs the following
    plugins to gather information:

    Invoke-PRPlugin -Name Collect-PrefetchListing.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-ProcessDLLs.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-Processes.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-RecentItemsListing.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-UserAssist.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrieve-Handles.ps1 -Session $Session


.EXAMPLE

    Power-Response Execution

    set computername test-pc
    run

.NOTES
    Author: Drew Schmitt
    Date Created: 5/10/2019
    Twitter: @5ynax
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param (

    [Parameter(Mandatory=$true,Position=0)]
    [System.Management.Automation.Runspaces.PSSession[]]$Session

    )

process {
    # Configuration Section
    $DependencyName = @('7za','Velociraptor')
    $StagingDirectory = 'C:\ProgramData'

    # TestDependency is a helper function to be sent to the remote systems and check for existing binary dependencies
    function TestDependency {
        process {
            # Get system $Architecture
            $Architecture = Get-WmiObject 'Win32_OperatingSystem' -Property 'OSArchitecture' -ErrorAction 'SilentlyContinue' | Select-Object -ExpandProperty 'OSArchitecture'

            foreach ($Name in $Args) {
                [String]$Path = '{0}\{1}*.exe' -f $using:StagingDirectory,$Name
                [PSCustomObject]@{
                    Architecture = $Architecture
                    IsPresent = (Test-Path -Path $Path)
                    Path = $Path
                    Name = $Name
                }
            }
        }
    }

    # Create $Dependency list skeleton
    $Dependency = @{}

    foreach ($Name in $DependencyName) {
        # Populate $Dependency with 32-bit and 64-bit path entries for each $Name
        $Dependency.$Name = @{
            '32-bit' = '{0}\{1}_x86.exe' -f (Get-PRPath -Bin),$Name
            '64-bit' = '{0}\{1}_x64.exe' -f (Get-PRPath -Bin),$Name
        }

        # Verify that local binaries exist
        $Dependency.$Name.GetEnumerator() | Where-Object { !(Test-Path -Path $PSItem.Value) } | Foreach-Object { throw ('{0} version of {1} not detected in Bin. Place {0} executable in Bin directory and try again.' -f $PSItem.Key,$Name) }
    }

    # Track which machines we deployed binaries to
    $Deployed = @{}

    # Get the $Dependency list from $Session
    $MissingRemoteDependency = Invoke-Command -Session $Session -ScriptBlock $function:TestDependency -ArgumentList @($Dependency.Keys) | Where-Object { !$PSItem.IsPresent } | Group-Object -Property 'PSComputerName'

    foreach ($RemoteDependencyGroup in $MissingRemoteDependency) {
        # Get the $SessionInstance
        $SessionInstance = $Session | Where-Object { $RemoteDependencyGroup.Name -eq $PSItem.ComputerName }

        foreach ($RemoteDependency in $RemoteDependencyGroup.Group) {
            # Get $DependencyPath from $RemoteDependency information
            $DependencyPath = $Dependency.($RemoteDependency.Name).($RemoteDependency.Architecture)

            # Get $Destination from $StagingDirectory
            $Destination = '{0}\{1}' -f $StagingDirectory,(Split-Path -Leaf -Path $DependencyPath)

            try {
                # Copy the requested $RemoteDependency to $SessionInstance
                Copy-Item -Force -ToSession $SessionInstance -Path $DependencyPath -Destination $Destination

                # On success, track our action in $Deployed
                [String[]]$Deployed.($RemoteDependency.PSComputerName) += $Destination
            } catch {
                throw ('Could not copy {0} to remote machine {1}: {2}. Quitting...' -f $DependencyPath,$SessionInstance.ComputerName,$PSItem)
            }
        }
    }
        

    # Plugin Execution
    Invoke-PRPlugin -Name Collect-PrefetchListing.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-ProcessDLLs.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-Processes.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-RecentItemsListing.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-UserAssist.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrieve-Handles.ps1 -Session $Session

    foreach ($Deployment in $Deployed.GetEnumerator()) {
        # Get the $SessionInstance
        $SessionInstance = $Session | Where-Object { $Deployment.Key -eq $PSItem.ComputerName }

        # Get $Binaries array
        $Binaries = $Deployment.Value

        try {
            # Delete any $Deployed $Binaries
            Invoke-Command -Session $SessionInstance -ScriptBlock { Remove-Item -Force -Recurse -Path $using:Binaries }
        } catch {
            # Whelp we tried, write a warning
            Write-Warning -Message ('Failed to remove binary dependency {0} from remote system {1}' -f ($Binaries -join ','),$Deployment.Key)
        }
    }
    
}