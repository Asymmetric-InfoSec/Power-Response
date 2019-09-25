<#

.SYNOPSIS
    Plugin-Name: Retrieve-RecycleBins.ps1
    
.Description
    This plugin collects the $Recycle.Bin contents (recursively) from a remote system. 
    The file is copied by pushing the Velociraptor binary to the the remote system, 
    where it copies the files to C:\ProgramData\%COMPUTERNAME%. 7za.exe is also copied
    to the system, to then zip the directory containing the MFT before moving them back 
    to your local system for further analysis and processing. This plugin will remove
    the Velociraptor, 7zip PE, and all locally created files after successfully pulling
    the artifacts back to the output destination in Power-Response.

.EXAMPLE

    Power-Response Execution

    Set ComputerName Test-PC
    Run

.NOTES
    Author: Drew Schmitt
    Date Created: 4/10/2019
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

    # Set $Output for where to store recovered artifacts
    $Output= (Get-PRPath -ComputerName $Session.ComputerName -Directory ('RecycleBin_{0:yyyyMMdd}' -f (Get-Date)))

    # Create Subdirectory in $global:PowerResponse.OutputPath for storing artifacts
    If (!(Test-Path $Output)){

        New-Item -Type Directory -Path $Output | Out-Null
    }

    #Determine system architecture and select proper 7za.exe and Velociraptor executables
    try {
     
        $Architecture = Invoke-Command -Session $Session -ScriptBlock {(Get-WmiObject -Class Win32_OperatingSystem -Property OSArchitecture -ErrorAction Stop).OSArchitecture}
    
        if ($Architecture -eq "64-bit") {

            $Installexe = $7za64

        } elseif ($Architecture -eq "32-bit") {

            $Installexe = $7za32

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

    #Create Output directory structure on remote host
    $TestRemoteDumpPath = Invoke-Command -Session $Session -ScriptBlock {Get-Item -Path ("C:\ProgramData\{0}" -f $($args[0])) -ErrorAction SilentlyContinue} -ArgumentList $Session.ComputerName

    If (!$TestRemoteDumpPath){

        Invoke-Command -Session $Session -ScriptBlock {New-Item -Type Directory -Path ("C:\ProgramData\{0}" -f $($args[0])) | Out-Null} -ArgumentList $Session.ComputerName
    
    }

    #Collect System Artifacts    
    $Path = Get-ChildItem -Path 'C:\$Recycle.Bin' -Force | Select -ExpandProperty FullName | Foreach-Object { Join-Path -Path $PSItem -ChildPath '*' }

    #Stage System Artifacts
    Copy-PRItem -Session $Session -Path $Path -Destination (Join-Path -Path 'C:\ProgramData' -ChildPath $Session.ComputerName)
        
    # Compress artifacts directory      
    $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(("& 'C:\ProgramData\{0}' a C:\ProgramData\{1}_RecycleBin.zip C:\ProgramData\{1}") -f ((Split-Path $Installexe -Leaf), $Session.ComputerName))
    Invoke-Command -Session $Session -ScriptBlock $ScriptBlock -ErrorAction SilentlyContinue | Out-Null

    # Copy artifacts back to $Output (Uses $Session)
    try {

        Copy-Item -Path (("C:\ProgramData\{0}_RecycleBin.zip") -f ($Session.ComputerName)) -Destination "$Output\" -FromSession $Session -Force -ErrorAction Stop

    } catch {

        throw "There was an error copying zipped archive back to data collection machine. Retrieve data manually through PS Session."
    }
    
    #Delete 7zip if deployed by plugin
    if (!$7zFlag){

        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(("Remove-Item -Force -Recurse -Path C:\ProgramData\{0}") -f (Split-Path $Installexe -Leaf))
        Invoke-Command -Session $Session -ScriptBlock $ScriptBlock | Out-Null
    }

    # Delete reamining artifacts from remote machine
    $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(("Remove-Item -Force -Recurse -Path C:\ProgramData\{0}_RecycleBin.zip, C:\ProgramData\{0}") -f ($Session.ComputerName))
    Invoke-Command -Session $Session -ScriptBlock $ScriptBlock | Out-Null
}