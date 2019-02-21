<#

.SYNOPSIS
    Plugin-Name: Collect-WindowsArtifacts.ps1
    
.Description
    This plugin collects windows artifacts (including locked files) from the 
    preset list below. The file are copied by pushing the Velociraptor binary to 
    the the remote system, where it copies the files to C:\ProgramData\%COMPUTERNAME%.
    7za.exe is also copied to the system, to then zip the directory of artifacts 
    before moving them back to your local system for further analysis. This plugin 
    will remove the Velociraptor, 7zip PE, and all locally created files after 
    successfully pulling the artifacts back to the output destination in Power-Response.

    System Artifacts:
    %SystemDrive%\$MFT
    %SYSTEMROOT%\Tasks
    %SYSTEMROOT%\System32\Tasks
    %SYSTEMROOT%\Prefetch
    %SYSTEMROOT%\System32\config\SAM
    %SYSTEMROOT%\System32\config\SAM.LOG1
    %SYSTEMROOT%\System32\config\SAM.LOG2
    %SYSTEMROOT%\System32\config\SYSTEM
    %SYSTEMROOT%\System32\config\SYSTEM.LOG1
    %SYSTEMROOT%\System32\config\SYSTEM.LOG2
    %SYSTEMROOT%\System32\config\SOFTWARE
    %SYSTEMROOT%\System32\config\SOFTWARE.LOG1
    %SYSTEMROOT%\System32\config\SOFTWARE.LOG2
    %SYSTEMROOT%\System32\config\SECURITY
    %SYSTEMROOT%\System32\config\SECURITY.LOG1
    %SYSTEMROOT%\System32\config\SECURITY.LOG2
    %SYSTEMROOT%\Appcompat\Programs
    %SYSTEMROOT%\System32\drivers\etc\hosts
    %SYSTEMROOT%\System32\winevt\logs
    %PROGRAMDATA%\Microsoft\Search\Data\Applications\Windows
    %PROGRAMDATA%\Microsoft\Windows\Start Menu\Programs\Startup

    User Artifacts:
    %UserProfile%\NTUSER.DAT
    %UserProfile%\NTUSER.DAT.LOG1
    %UserProfile%\NTUSER.DAT.LOG2
    %UserProfile%\AppData\Local\Microsoft\Windows\UsrClass.dat
    %UserProfile%\AppData\Local\Microsoft\Windows\UsrClass.dat.LOG1
    %UserProfile%\AppData\Local\Microsoft\Windows\UsrClass.dat.LOG2
    %UserProfile%\AppData\Roaming\Microsoft\Windows\Recent
    %UserProfile%\AppData\Local\Google\Chrome\User Data\Default\History
    %UserProfile%\AppData\Local\Microsoft\Windows\WebCache

.EXAMPLE
    Stand Alone 

    .\Collect-WindowsArtifacts.ps1 -ComputerName Test-PC

    Power-Response Execution

    Set ComputerName Test-PC
    Run

.NOTES
    Author: Matt Weikert
    Date Created: 2/12/2019
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

        # Collect %SystemDrive%\$MFT
        Write-Host ("Collecting {0}\`$MFT" -f $env:SystemDrive)
        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(('& {0}\{1} fs --accessor ntfs cp \\.\{2}\`$MFT {0}\{3}') -f ($env:ProgramData, (Split-Path -Path $Velociraptor -Leaf), $env:SystemDrive, $Computer))
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock -ErrorAction SilentlyContinue | Out-Null
        
        # Compress artifacts directory
        Write-Host ("Compressing Artifacts into {0}\{1}_MFT.zip" -f $env:ProgramData, $Computer)        
        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(("& {0}\{1} a {0}\{2}_MFT.zip {0}\{2}") -f ($env:ProgramData, (Split-Path -Path $7za64 -Leaf), $Computer))
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock -ErrorAction SilentlyContinue | Out-Null

        # Copy artifacts back to $Output (Uses $Session)
        Write-Host ("Copying {0}\{1}_MFT.zip to {2}" -f $env:ProgramData, $Computer, $Output)
        Copy-Item -Path (("{0}\{1}_MFT.zip") -f ($env:ProgramData, $Computer)) -Destination "$Output\" -FromSession $Session -Force -ErrorAction SilentlyContinue

        # Delete initial artifacts, 7za, and velociraptor binaries from remote machine
        Write-Host ("Performing cleanup")
        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(("Remove-Item -Force -Recurse -Path {0}\{1}, {0}\{2}, {0}\{3}_MFT.zip, {0}\{3}") -f ($env:ProgramData, (Split-Path -Path $Velociraptor -Leaf), (Split-Path -Path $7za64 -Leaf), $Computer))
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock | Out-Null

        #Remove PS Session
        $Session | Remove-PSSession
    }
}