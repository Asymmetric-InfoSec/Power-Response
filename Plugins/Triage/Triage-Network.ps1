<#

.SYNOPSIS
    Plugin-Name: Triage-Network.ps1
    
.Description

    Grabs relevant Windows artifacts and data and performs analysis to 
    speed up the investigation process. This plugin runs the following
    plugins to gather information:

    Invoke-PRPlugin -Name Collect-ArpCache.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-DNSCache.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-InterfaceDetails.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-NetworkConnections.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-NetworkProfiles.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-NetworkRoutes.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-SessionDrives.ps1 -Session $Session

.EXAMPLE

    Power-Response Execution

    set computername test-pc
    run

.NOTES
    Author: Drew Schmitt
    Date Created: 5/10/2019
    Twitter: @5ynax
    
    Last Modified By: Gavin Prentice
    Last Modified Date: 10/11/2019
    Twitter: @Valrkey
  
#>

param (

    [Parameter(Mandatory=$true,Position=0)]
    [System.Management.Automation.Runspaces.PSSession[]]$Session

)

process {
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
    Invoke-PRPlugin -Name Collect-ArpCache.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-DNSCache.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-InterfaceDetails.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-NetworkConnections.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-NetworkProfiles.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-NetworkRoutes.ps1 -Session $Session
    Invoke-PRPlugin -Name Collect-SessionDrives.ps1 -Session $Session
    # End plugin logic

    # Begin dependency cleanup logic
    # Remove created files on remote machine as cleanup
    Invoke-Command -Session $Session -ScriptBlock {
        # Remove the staging directory
        Remove-Item -Force -Recurse -Path $using:RemoteStageDirectory
    }
    # End dependency cleanup logic
}