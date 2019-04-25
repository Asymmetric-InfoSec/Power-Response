﻿<#

.SYNOPSIS
    Plugin-Name: Retrieve-WindowsArtifacts.ps1
    
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
    %SystemDrive%\$Boot
    %SystemDrive%\$Secure:SDS
    %SystemDrive%\$LogFile
    %SystemDrive%\$Extend\$UsnJrnl:$J
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
    %SYSTEMROOT%\System32\config\RegBack\
    %SYSTEMROOT%\$Recycle.Bin\*

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
    %UserProfile%\AppData\Roaming\Mozilla\Firefox\Profiles\*.default\places.sqlite

.EXAMPLE

    Power-Response Execution

    Set ComputerName Test-PC
    Run

.NOTES
    Author: Matt Weikert
    Date Created: 2/12/2019
    Twitter: @5k33tz
    
    Last Modified By: Drew Schmitt
    Last Modified Date: 4/5/2019
    Twitter: @5ynax
  
#>

param (

    [Parameter(Mandatory=$true,Position=0)]
    [System.Management.Automation.Runspaces.PSSession]$Session

    )

process{

    # Verify that 7za executables are located in (Get-PRPath -Bin)

    $7za32 = ("{0}\7za_x86.exe" -f (Get-PRPath -Bin))
    $7za64 = ("{0}\7za_x64.exe" -f (Get-PRPath -Bin))

    $7z64bitTestPath = Get-Item -Path $7za64 -ErrorAction SilentlyContinue
    $7z32bitTestPath = Get-Item -Path $7za32 -ErrorAction SilentlyContinue

    if (!$7z64bitTestPath) {

        Throw "64 bit version of 7za.exe not detected in Bin. Place 64bit executable in Bin directory and try again."

    } elseif (!$7z32bitTestPath) {

        Throw "32 bit version of 7za.exe not detected in Bin. Place 32bit executable in Bin directory and try again."
    }

    #Verify that Velociraptor executables are located in (Get-PRPath -Bin) (For locked files)

    $Velo_64 = ("{0}\Velociraptor_x64.exe" -f (Get-PRPath -Bin))
    $Velo_32 = ("{0}\Velociraptor_x86.exe" -f (Get-PRPath -Bin))

    $Velo_64TestPath = Get-Item -Path $Velo_64 -ErrorAction SilentlyContinue
    $Velo_32TestPath = Get-Item -Path $Velo_32 -ErrorAction SilentlyContinue

    if (!$Velo_64TestPath) {

        Throw "64 bit version of Velociraptor not detected in Bin. Place 64bit executable in Bin directory and try again."

    } elseif (!$Velo_32TestPath) {

        Throw "32 bit version of Velociraptor not detected in Bin. Place 32bit executable in Bin directory and try again."
    }

    # Set $Output for where to store recovered artifacts
    $Output= (Get-PRPath -ComputerName $Session.ComputerName -Directory 'Artifacts')

    # Create Subdirectory in $global:PowerResponse.OutputPath for storing artifacts
    If (!(Test-Path $Output)){

        New-Item -Type Directory -Path $Output | Out-Null
    }

    #Determine system architecture and select proper 7za.exe and Velociraptor executables
    try {
     
        $Architecture = Invoke-Command -Session $Session -ScriptBlock {(Get-WmiObject -Class Win32_OperatingSystem -Property OSArchitecture -ErrorAction Stop).OSArchitecture}
    
        if ($Architecture -eq "64-bit") {

            $Installexe = $7za64
            $Velo_exe = $Velo_64

        } elseif ($Architecture -eq "32-bit") {

            $Installexe = $7za32
            $Velo_exe = $Velo_32

        } else {
        
            Write-Error ("Unknown system architecture ({0}) detected for {1}. Data was not gathered.)" -f $Architecture, $Session.ComputerName)
            Continue
        }

    } catch {
    
     Write-Error ("Unable to determine system architecture for {0}. Data was not gathered." -f $Session.ComputerName)
        Continue
    }

    # Copy 7zip and Velociraptor to remote machine

    try {

        Copy-Item -Path $Installexe -Destination "C:\ProgramData" -ToSession $Session -Force -ErrorAction Stop

    } catch {

        Throw "Could not copy 7zip to remote machine. Quitting..."
    }

    try {

        Copy-Item -Path $Velo_exe -Destination "C:\ProgramData" -ToSession $Session -Force -ErrorAction Stop

    } catch {

        Throw "Could not copy Velociraptor to remote machine. Quitting..."
    }
       
    #Verify that 7zip and Velociraptor installed properly

    $VeloTest = Invoke-Command -Session $Session -ScriptBlock {Get-Item -Path ("C:\ProgramData\{0}" -f $($args[0]))} -ArgumentList (Split-Path $Velo_exe -Leaf)
    $7zTest = Invoke-Command -Session $Session -ScriptBlock {Get-Item -Path ("C:\ProgramData\{0}" -f $($args[0]))} -ArgumentList (Split-Path $Installexe -Leaf)

    if (!$VeloTest){

        Throw ("Velociraptor not found on {0}. There may have been a problem during the copy process. Artifacts were not acquired." -f $Session.ComputerName)   
    
    }

    if (!$7zTest){

        Throw ("7zip not found on {0}. There may have been a problem during the copy process. Artifacts were not acquired." -f $Session.ComputerName)
    
    }

    #Create Output directory structure on remote host
    $TestRemoteDumpPath = Invoke-Command -Session $Session -ScriptBlock {Get-Item -Path ("C:\ProgramData\{0}" -f $($args[0])) -ErrorAction SilentlyContinue} -ArgumentList $Session.ComputerName

    If (!$TestRemoteDumpPath){

        Invoke-Command -Session $Session -ScriptBlock {New-Item -Type Directory -Path ("C:\ProgramData\{0}" -f $($args[0])) | Out-Null} -ArgumentList $Session.ComputerName
    
    }

    #Collect System Artifacts    
    $SystemArtifacts = @(

        "$env:SystemDrive\```$MFT",
        "$env:SystemDrive\```$Boot",
        "$env:SystemDrive\```$Secure:```$SDS",
        "$env:SystemDrive\```$LogFile",
        "$env:SystemDrive\```$Extend\```$UsnJrnl:```$J",
        "$env:SystemRoot\Tasks\*",
        "$env:SystemRoot\System32\Tasks\*",
        "$env:SystemRoot\Prefetch\*",
        "$env:SystemRoot\System32\config\SAM",
        "$env:SystemRoot\System32\config\SAM.LOG1",
        "$env:SystemRoot\System32\config\SAM.LOG2",
        "$env:SystemRoot\System32\config\SYSTEM",
        "$env:SystemRoot\System32\config\SYSTEM.LOG1",
        "$env:SystemRoot\System32\config\SYSTEM.LOG2",
        "$env:SystemRoot\System32\config\SOFTWARE",
        "$env:SystemRoot\System32\config\SOFTWARE.LOG1",
        "$env:SystemRoot\System32\config\SOFTWARE.LOG2",
        "$env:SystemRoot\System32\config\SECURITY",
        "$env:SystemRoot\System32\config\SECURITY.LOG1",
        "$env:SystemRoot\System32\config\SECURITY.LOG2",
        "$env:SystemRoot\Appcompat\Programs\*",
        "$env:SystemRoot\System32\drivers\etc\hosts",
        "$env:SystemRoot\System32\winevt\logs\*",
        "$env:SystemRoot\system32\sru\SRUDB.dat",
        "$env:SystemRoot\System32\config\RegBack\*",
        "$env:ProgramData\Microsoft\Search\Data\Applications\Windows\*",
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\*"

    )
           
    foreach ($Artifact in $SystemArtifacts){

        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(('& C:\ProgramData\{0} fs --accessor ntfs cp \\.\{1} C:\ProgramData\{2}') -f ((Split-Path $Velo_exe -Leaf), $Artifact, $Session.ComputerName))
        Invoke-Command -Session $Session -ScriptBlock $ScriptBlock -ErrorAction SilentlyContinue | Out-Null
    }
    
    #Collect User Artifacts

    $UserArtifacts = @(

        "NTUSER.DAT",
        "NTUSER.DAT.LOG1",
        "NTUSER.DAT.LOG2",
        "AppData\Local\Microsoft\Windows\UsrClass.dat",
        "AppData\Local\Microsoft\Windows\UsrClass.dat.LOG1",
        "AppData\Local\Microsoft\Windows\UsrClass.dat.LOG2",
        "AppData\Roaming\Microsoft\Windows\Recent*\*",
        "AppData\Local\Google\Chrome\User*\Default\History*",
        "AppData\Local\Microsoft\Windows\WebCache\*",
        "AppData\Roaming\Mozilla\Firefox\Profiles\*.default\places.sqlite"

        )

    # Grab list of user profiles
    $Users = Invoke-Command -Session $Session -Scriptblock {Get-CimInstance -ClassName Win32_UserProfile | Select-Object -ExpandProperty LocalPath | Select-String Users} | Out-Null

    # Iterate through each user profile grabbing the artifacts
    foreach ($User in $Users){

        foreach ($Artifact in $UserArtifacts) {

            $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(("& C:\ProgramData\{0} fs --accessor ntfs cp \\.\{1}\{2} C:\ProgramData\{3}") -f ((Split-Path $Velo_exe -Leaf), $User, $Artifact,$Session.ComputerName))
            Invoke-Command -Session $Session -ScriptBlock $ScriptBlock -ErrorAction SilentlyContinue | Out-Null
        }
     
    }

    #Collect Contents of Recycle binaries
    $SIDS = Get-ChildItem -Path 'C:\$Recycle.Bin' -Force | Select -ExpandProperty Name

    foreach ($SID in $SIDS){

        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(('& C:\ProgramData\{0} fs --accessor ntfs cp \\.\C:\`$Recycle.Bin\{1}\* C:\ProgramData\{2}') -f ((Split-Path $Velo_exe -Leaf), $SID, $Session.ComputerName))
        Invoke-Command -Session $Session -ScriptBlock $ScriptBlock -ErrorAction SilentlyContinue | Out-Null
    }
        
    # Compress artifacts directory      
    $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(("& C:\ProgramData\{0} a C:\ProgramData\{1}_Artifacts.zip C:\ProgramData\{1}") -f ((Split-Path $Installexe -Leaf), $Session.ComputerName))
    Invoke-Command -Session $Session -ScriptBlock $ScriptBlock -ErrorAction SilentlyContinue | Out-Null

    # Copy artifacts back to $Output (Uses $Session)
    try {

        Copy-Item -Path (("C:\ProgramData\{0}_Artifacts.zip") -f ($Session.ComputerName)) -Destination "$Output\" -FromSession $Session -Force -ErrorAction Stop

    } catch {

        throw "There was an error copying zipped archive back to data collection machine. Retrieve data manually through PS Session."
    }
    
    # Delete initial artifacts, 7za, and velociraptor binaries from remote machine
    $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(("Remove-Item -Force -Recurse -Path C:\ProgramData\{0}, C:\ProgramData\{1}, C:\ProgramData\{2}_Artifacts.zip, C:\ProgramData\{2}") -f ((Split-Path $Velo_exe -Leaf), (Split-Path $Installexe -Leaf), $Session.ComputerName))
    Invoke-Command -Session $Session -ScriptBlock $ScriptBlock | Out-Null

}