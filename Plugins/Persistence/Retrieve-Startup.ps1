<#

.SYNOPSIS
    Plugin-Name: Retrieve-Startup.ps1
    
.Description

	Collects the startup directory contents for each user and all users (public)
	to use as part of an investigation to determine if there are persistence
    mechanisms established via the startup directory

.EXAMPLE

	Power-Response Execution

	Set ComputerName Test-PC
	run

.NOTES
    Author: Drew Schmitt
    Date Created: 4/3/2019
    Twitter: @5ynax
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param(

    [Parameter(Mandatory=$true,Position=0)]
    [System.Management.Automation.Runspaces.PSSession]$Session

)

process {
	
    #7zip checks
    $7zTestPath = "C:\ProgramData\7za*.exe"
    $7zFlag = Invoke-Command -Session $Session -ScriptBlock {Test-Path $($args[0])} -ArgumentList $7zTestPath

    #7zip BIN locations
    $7za32 = ("{0}\7za_x86.exe" -f (Get-PRPath -Bin))
    $7za64 = ("{0}\7za_x64.exe" -f (Get-PRPath -Bin))

    #Velociraptor checks
    $VeloTestPath = "C:\ProgramData\Velociraptor*.exe"
    $VeloFlag = Invoke-Command -Session $Session -ScriptBlock {Test-Path $($args[0])} -ArgumentList $VeloTestPath

    #Velociraptor BIN locations
    $Velo_64 = ("{0}\Velociraptor_x64.exe" -f (Get-PRPath -Bin))
    $Velo_32 = ("{0}\Velociraptor_x86.exe" -f (Get-PRPath -Bin))

    if (!$7zFlag){

        # Verify that 7za executables are located in (Get-PRPath -Bin)

        $7z64bitTestPath = Get-Item -Path $7za64 -ErrorAction SilentlyContinue
        $7z32bitTestPath = Get-Item -Path $7za32 -ErrorAction SilentlyContinue

        if (!$7z64bitTestPath) {

            Throw "64 bit version of 7za.exe not detected in Bin. Place 64bit executable in Bin directory and try again."

        } elseif (!$7z32bitTestPath) {

            Throw "32 bit version of 7za.exe not detected in Bin. Place 32bit executable in Bin directory and try again."
        }
    }

    if (!$VeloFlag){

        #Verify that Velociraptor executables are located in (Get-PRPath -Bin) (For locked files)

        $Velo_64TestPath = Get-Item -Path $Velo_64 -ErrorAction SilentlyContinue
        $Velo_32TestPath = Get-Item -Path $Velo_32 -ErrorAction SilentlyContinue

        if (!$Velo_64TestPath) {

            Throw "64 bit version of Velociraptor not detected in Bin. Place 64bit executable in Bin directory and try again."

        } elseif (!$Velo_32TestPath) {

            Throw "32 bit version of Velociraptor not detected in Bin. Place 32bit executable in Bin directory and try again."
        }
    }

    #Set $Output for where to store recovered artifacts
    $Output= (Get-PRPath -ComputerName $Session.ComputerName -Directory ('Startup_{0:yyyyMMdd}' -f (Get-Date)))

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

    if (!$7zFlag){

        try {

            Copy-Item -Path $Installexe -Destination "C:\ProgramData" -ToSession $Session -Force -ErrorAction Stop

        } catch {

            Throw "Could not copy 7zip to remote machine. Quitting..."
        }

    }

    if (!$VeloFlag){

        try {

            Copy-Item -Path $Velo_exe -Destination "C:\ProgramData" -ToSession $Session -Force -ErrorAction Stop

        } catch {

            Throw "Could not copy Velociraptor to remote machine. Quitting..."
        }

    }

    #Create Output directory structure on remote host
    $TestRemoteDumpPath = Invoke-Command -Session $Session -ScriptBlock {Get-Item -Path ("C:\ProgramData\{0}" -f $($args[0])) -ErrorAction SilentlyContinue} -ArgumentList $Session.ComputerName

    If (!$TestRemoteDumpPath){

        Invoke-Command -Session $Session -ScriptBlock {New-Item -Type Directory -Path ("C:\ProgramData\{0}" -f $($args[0])) | Out-Null} -ArgumentList $Session.ComputerName
    
    }

    #Collect System Artifacts    
    $SystemArtifacts = @(

        "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\*"
    )
           
    foreach ($Artifact in $SystemArtifacts){

        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(("& 'C:\ProgramData\{0}' fs --accessor ntfs cp '\\.\{1}' C:\ProgramData\{2}") -f ((Split-Path $Velo_exe -Leaf), $Artifact, $Session.ComputerName))
        Invoke-Command -Session $Session -ScriptBlock $ScriptBlock -ErrorAction SilentlyContinue | Out-Null
    }

    #Collect user artifacts    
    $UserArtifacts = @(

        "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\*"
    )

    # Grab list of user profiles
    $Users = Invoke-Command -Session $Session -Scriptblock {Get-CimInstance -ClassName Win32_UserProfile | Select-Object -ExpandProperty LocalPath | Select-String Users}

    # Iterate through each user profile grabbing the artifacts
    foreach ($User in $Users){

        foreach ($Artifact in $UserArtifacts) {

            $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(("& 'C:\ProgramData\{0}' fs --accessor ntfs cp '\\.\{1}\{2}' C:\ProgramData\{3}") -f ((Split-Path $Velo_exe -Leaf), $User, $Artifact, $Session.ComputerName))
            Invoke-Command -Session $Session -ScriptBlock $ScriptBlock -ErrorAction SilentlyContinue | Out-Null
        }
    }
        
    # Compress artifacts directory      
    $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(("& 'C:\ProgramData\{0}' a -pinfected -tzip 'C:\ProgramData\{1}_Startup.zip' C:\ProgramData\{1}") -f ((Split-Path $Installexe -Leaf), $Session.ComputerName))
    Invoke-Command -Session $Session -ScriptBlock $ScriptBlock -ErrorAction SilentlyContinue | Out-Null

    # Copy artifacts back to $Output (Uses $Session)
    try {

        Copy-Item -Path (("C:\ProgramData\{0}_Startup.zip") -f ($Session.ComputerName)) -Destination "$Output\" -FromSession $Session -Force -ErrorAction Stop

    } catch {

        throw "There was an error copying zipped archive back to data collection machine. Retrieve data manually through PS Session."
    }

    #Delete 7zip if deployed by plugin
    if (!$7zFlag){

        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(("Remove-Item -Force -Recurse -Path C:\ProgramData\{0}") -f (Split-Path $Installexe -Leaf))
        Invoke-Command -Session $Session -ScriptBlock $ScriptBlock | Out-Null
    }
    
    #Delete Velociraptor if deployed by plugin
    if (!$VeloFlag){

        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(("Remove-Item -Force -Recurse -Path C:\ProgramData\{0}") -f (Split-Path $Velo_exe -Leaf))
        Invoke-Command -Session $Session -ScriptBlock $ScriptBlock | Out-Null
    }
    
    # Delete initial artifacts, 7za, and velociraptor binaries from remote machine
    $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(("Remove-Item -Force -Recurse -Path C:\ProgramData\{0}_Startup.zip, C:\ProgramData\{0}") -f ($Session.ComputerName))
    Invoke-Command -Session $Session -ScriptBlock $ScriptBlock | Out-Null
}