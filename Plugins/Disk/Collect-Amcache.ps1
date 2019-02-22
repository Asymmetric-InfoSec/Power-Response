<#

.SYNOPSIS
    Plugin-Name: Collect-Amcache.ps1
    
.Description

    This plugin collects the amcache.hve. The file is copied by pushing the 
    Velociraptor binary to the the remote system, where it copies the files 
    to C:\ProgramData\%COMPUTERNAME%. 7za.exe is also copied to the system, 
    to then zip the directory containing the amcache.hve before moving them 
    back to your local system for further analysis and processing. This plugin 
    will remove the Velociraptor, 7zip PE, and all locally created files after 
    successfully pulling the artifacts back to the output destination in Power-Response.

.EXAMPLE
    Stand Alone 

    .\Collect-Amcache.ps1 -ComputerName Test-PC

    Power-Response Execution

    Set ComputerName Test-PC
    Run

.NOTES
    Author: Matt Weikert
    Date Created: 2/22/2019
    Twitter: @5k33tz
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param (

    [Parameter(Mandatory=$true,Position=0)]
    [string[]]$ComputerName

    )

process{

    # Set $Output for where to store recovered artifacts
    $Output= ("{0}\Artifacts" -f $global:PowerResponse.OutputPath)

    # Create Subdirectory in $global:PowerResponse.OutputPath for storing memory
    If (-not (Test-Path $Output)) 
    {
        New-Item -Type Directory -Path $Output | Out-Null
    }

    # Verify that velociraptor and 7za executables are located in $global:PowerResponse.Config.Path.Bin
    $Velociraptor = ("{0}\velociraptor-amd64.exe" -f $global:PowerResponse.Config.Path.Bin)
    $7za64 = ("{0}\7za_x64.exe" -f $global:PowerResponse.Config.Path.Bin)

    $VelociraptorTestPath = Get-Item -Path $Velociraptor -ErrorAction SilentlyContinue
    $7z64bitTestPath = Get-Item -Path $7za64 -ErrorAction SilentlyContinue

    if (-not $VelociraptorTestPath) 
    {
        Throw "velociraptor-amd64.exe not detected in Bin. Place executable in Bin directory and try again."

    } elseif (-not $7z64bitTestPath) 
    {
        Throw "7za_x64.exe not detected in Bin. Place executable in Bin directory and try again."
    }

    foreach ($Computer in $ComputerName) 
    {
        #Handle $ComputerName defined as localhost and not break the Plugin
        if ($Computer -eq "Localhost") 
        {
            $Computer = $ENV:ComputerName
        }

        #Verify machine is online and ready for data collection
        if (-not (Test-Connection -ComputerName $Computer -Count 1 -Quiet)) 
        {
            Write-Error ("{0} appears to be offline. Cannot collect artifacts." -f $Computer)
            Continue
        }

        #Establish PS Session criteria
        $Session = New-PSSession -ComputerName "$Computer" -SessionOption (New-PSSessionOption -NoMachineProfile)
         
        #Create Output directory structure on remote host
        $RemoteDumpPath = ("\\{0}\c`$\ProgramData\{0}" -f $Computer)
        If (-not (Test-Path $RemoteDumpPath)) 
        {
            New-Item -Type Directory -Path $RemoteDumpPath | Out-Null
        }

        #Copy velociraptor to remote host
        $SmbPathVelociraptor = ("\\{0}\c`$\ProgramData\{1}" -f $Computer, (Split-Path -Path $Velociraptor -Leaf))
        
        try 
        {
            Copy-Item -Path $Velociraptor -Destination $SmbPathVelociraptor -ErrorAction Stop
            $RemoteFileVelociraptor = Get-Item -Path $SmbPathVelociraptor -ErrorAction Stop

            # verify that the file copy succeeded to the remote host
            if (-not $RemoteFileVelociraptor) 
            {
                Write-Error ("Velociraptor not found on {0}. There may have been a problem during the copy process. Artifacts were not acquired." -f $Computer)
                Continue
            }

        } 
        catch 
        {
            Write-Error ("An unexpected error occurred while copying velociraptor to {0}. Artifacts not acquired." -f $Computer)
            Continue
        }

        #Copy 7za.exe to remote system
        $SmbPath7za = ("\\{0}\c`$\ProgramData\{1}" -f $Computer, (Split-Path -Path $7za64 -Leaf))
        
        try 
        {
            Copy-Item -Path $7za64 -Destination $SmbPath7za -ErrorAction Stop
            $RemoteFile7za = Get-Item -Path $SmbPath7za -ErrorAction Stop

            #verify that the file copy succeeded to the remote host
            if (-not $RemoteFile7za) 
            {
                Write-Error ("7za_x64.exe not found on {0}. There may have been a problem during the copy process. Artifacts cannot be compressed." -f $Computer)
                Continue
            }
        } 
        catch 
        {
            Write-Error ("An unexpected error occurred while copying 7za_x64.exe to {0}. Artifacts cannot be compressed." -f $Computer)
            Continue
        }

        # Collect %SystemRoot%\AppCompat\Programs\Amcache.hve
        Write-Host ("Collecting {0}\AppCompat\Programs\Amcache.hve" -f $env:SystemRoot)
        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(('& {0}\{1} fs --accessor ntfs cp \\.\{2}\AppCompat\Programs\Amcache.hve {0}\{3}') -f ($env:ProgramData, (Split-Path -Path $Velociraptor -Leaf), $env:SystemRoot, $Computer))
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock -ErrorAction SilentlyContinue | Out-Null
        
        # Compress artifacts directory
        Write-Host ("Compressing Artifacts into {0}\{1}_amcache.zip" -f $env:ProgramData, $Computer)        
        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(("& {0}\{1} a {0}\{2}_amcache.zip {0}\{2}") -f ($env:ProgramData, (Split-Path -Path $7za64 -Leaf), $Computer))
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock -ErrorAction SilentlyContinue | Out-Null

        # Copy artifacts back to $Output (Uses $Session)
        Write-Host ("Copying {0}\{1}_amcache.zip to {2}" -f $env:ProgramData, $Computer, $Output)
        Copy-Item -Path (("{0}\{1}_amcache.zip") -f ($env:ProgramData, $Computer)) -Destination "$Output\" -FromSession $Session -Force -ErrorAction SilentlyContinue

        # Delete initial artifacts, 7za, and velociraptor binaries from remote machine
        Write-Host ("Performing cleanup")
        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(("Remove-Item -Force -Recurse -Path {0}\{1}, {0}\{2}, {0}\{3}_amcache.zip, {0}\{3}") -f ($env:ProgramData, (Split-Path -Path $Velociraptor -Leaf), (Split-Path -Path $7za64 -Leaf), $Computer))
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock | Out-Null

        #Remove PS Session
        $Session | Remove-PSSession
    }
}