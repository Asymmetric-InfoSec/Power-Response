<#

.SYNOPSIS
    Plugin-Name: Retrieve-MFT.ps1
    
.Description
    This plugin collects the $MFT from a remote system. The file is copied by pushing 
    the Velociraptor binary to the the remote system, where it copies the files to 
    C:\ProgramData\%COMPUTERNAME%. 7za.exe is also copied to the system, to then zip 
    the directory containing the MFT before moving them back to your local system for 
    further analysis and processing. This plugin will remove the Velociraptor, 7zip PE, 
    and all locally created files after successfully pulling the artifacts back to the 
    output destination in Power-Response.

.EXAMPLE

    Power-Response Execution

    Set ComputerName Test-PC
    Run

.NOTES
    Author: Matt Weikert
    Date Created: 2/18/2019
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

   # Verify that 7za executables are located in $global:PowerResponse.Config.Path.Bin

    $7za32 = ("{0}\7za_x86.exe" -f $global:PowerResponse.Config.Path.Bin)
    $7za64 = ("{0}\7za_x64.exe" -f $global:PowerResponse.Config.Path.Bin)

    $7z64bitTestPath = Get-Item -Path $7za64 -ErrorAction SilentlyContinue
    $7z32bitTestPath = Get-Item -Path $7za32 -ErrorAction SilentlyContinue

    if (!$7z64bitTestPath) {

        Throw "64 bit version of 7za.exe not detected in Bin. Place 64bit executable in Bin directory and try again."

    } elseif (!$7z32bitTestPath) {

        Throw "32 bit version of 7za.exe not detected in Bin. Place 32bit executable in Bin directory and try again."
    }

    #Verify that Velociraptor executables are located in $global:PowerREsponse.Config.Path.Bin (For locked files)

    $Velo_64 = ("{0}\Velociraptor-amd64.exe" -f $global:PowerResponse.Config.Path.Bin)
    $Velo_32 = ("{0}\Velociraptor-386.exe" -f $global:PowerResponse.Config.Path.Bin)

    $Velo_64TestPath = Get-Item -Path $Velo_64 -ErrorAction SilentlyContinue
    $Velo_32TestPath = Get-Item -Path $Velo_32 -ErrorAction SilentlyContinue

    if (!$Velo_64TestPath) {

        Throw "64 bit version of Velociraptor not detected in Bin. Place 64bit executable in Bin directory and try again."

    } elseif (!$Velo_32TestPath) {

        Throw "32 bit version of Velociraptor not detected in Bin. Place 32bit executable in Bin directory and try again."
    }

    # Set $Output for where to store recovered artifacts
    $Output= (Get-PROutputPath -ComputerName $Session.ComputerName -Directory 'MFT')

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

        "$env:SystemDrive\```$MFT"
    
     )
           
    foreach ($Artifact in $SystemArtifacts){

        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(('& C:\ProgramData\{0} fs --accessor ntfs cp \\.\{1} C:\ProgramData\{2}') -f ((Split-Path $Velo_exe -Leaf), $Artifact, $Session.ComputerName))
        Invoke-Command -Session $Session -ScriptBlock $ScriptBlock -ErrorAction SilentlyContinue | Out-Null
    }
        
    # Compress artifacts directory      
    $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(("& C:\ProgramData\{0} a C:\ProgramData\{1}_MFT.zip C:\ProgramData\{1}") -f ((Split-Path $Installexe -Leaf), $Session.ComputerName))
    Invoke-Command -Session $Session -ScriptBlock $ScriptBlock -ErrorAction SilentlyContinue | Out-Null

    # Copy artifacts back to $Output (Uses $Session)
    try {

        Copy-Item -Path (("C:\ProgramData\{0}_MFT.zip") -f ($Session.ComputerName)) -Destination "$Output\" -FromSession $Session -Force -ErrorAction Stop

    } catch {

        throw "There was an error copying zipped archive back to data collection machine. Retrieve data manually through PS Session."
    }
    
    # Delete initial artifacts, 7za, and velociraptor binaries from remote machine
    $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(("Remove-Item -Force -Recurse -Path C:\ProgramData\{0}, C:\ProgramData\{1}, C:\ProgramData\{2}_MFT.zip, C:\ProgramData\{2}") -f ((Split-Path $Velo_exe -Leaf), (Split-Path $Installexe -Leaf), $Session.ComputerName))
    Invoke-Command -Session $Session -ScriptBlock $ScriptBlock | Out-Null

}