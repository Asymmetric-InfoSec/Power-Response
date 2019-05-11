<#

.SYNOPSIS
    Plugin-Name: Triage-WindowsArtifacts.ps1
    
.Description

    Grabs relevant Windows Artifacts and performs analysis to 
    speed up the investigation process. This plugin runs the following
    plugins to gather information:

    Invoke-PRPlugin -Name Retrive-NTFSArtifacts.ps1 -Session $Session
    Invoke-PRPlugin -Name Retrive-RegistryFiles.ps1 -Session $Session
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
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param (

    [Parameter(Mandatory=$true,Position=0)]
    [System.Management.Automation.Runspaces.PSSession]$Session

    )

process{

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

    #Plugin Execution

    Invoke-PRPlugin -Name Retrieve-NTFSArtifacts.ps1 -Session $Session
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
}