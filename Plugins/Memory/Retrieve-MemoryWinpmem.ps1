<#

.SYNOPSIS
    Plugin-Name: Retrieve-MemoryWinpmem.ps1
    
.Description
    This plugin captures memory from a remote host by deploying winpmem to the 
    remote machine and captures memory locally to the remote machine before
    copying back to the output location for PowerResponse. This plugin will
    remove the winpmem PE and delete all locally created files after successfully
    copying the memory acquisition back to the output destionation in
    Power-Response.

.EXAMPLE

    Power-Response Execution

    Set ComputerName Test-PC
    Run

.NOTES
    Author: Drew Schmitt
    Date Created: 2/9/2019
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

    $Winpmem = ("{0}\winpmem.exe" -f (Get-PRPath -Bin))
    $WinpmemTestPath = Get-Item -Path $Winpmem -ErrorAction SilentlyContinue

    if (!$WinpmemTestPath) {

        Throw "winpmem not detected in Bin. Place executable in Bin directory and try again."
    }

    # Set $Output for where to store recovered memory
    $Output= (Get-PRPath -ComputerName $Session.ComputerName -Directory ('Memory_{0:yyyyMMdd}' -f (Get-Date)))

    # Create Subdirectory in $global:PowerResponse.OutputPath for storing memory
    If (!(Test-Path $Output)) {

        New-Item -Type Directory -Path $Output | Out-Null
    }

    #Determine system architecture and select proper 7za.exe executable
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

    #Copy winpmem to remote host
    try {
    
        Copy-Item -Path $Winpmem -Destination "C:\ProgramData" -ToSession $Session -ErrorAction Stop

    } catch {

            Throw "Could not copy Winpmem to remote machine. Quitting..."
    }

    # Copy 7za.exe to remote system

    if (!$7zFlag){

        try {

            Copy-Item -Path $Installexe -Destination "C:\ProgramData" -ToSession $Session -Force -ErrorAction Stop

        } catch {

            Throw "Could not copy 7zip to remote machine. Quitting..."
        }
    }

    # Execute winpmem on remote machine to capture memory

    $ScriptBlock_Mem = $ExecutionContext.InvokeCommand.NewScriptBlock(("& 'C:\ProgramData\{0}' -o C:\ProgramData\{1}_memory.raw --volume_format raw -dd -t") -f ((Split-Path $Winpmem -Leaf), $Session.ComputerName))

    Invoke-Command -Session $Session -ScriptBlock $ScriptBlock_Mem | Out-Null

    # Compress winpmem capture

    $ScriptBlock_Compress = $ExecutionContext.InvokeCommand.NewScriptBlock(("& 'C:\ProgramData\{0}' a C:\ProgramData\{1}_memory.zip C:\ProgramData\{1}_memory.raw") -f ((Split-Path $Installexe -Leaf), $Session.ComputerName))

    Invoke-Command -Session $Session -ScriptBlock $ScriptBlock_Compress | Out-Null

    # Copy winpmem capture back to $Output (Uses $Session)

    Copy-Item -Path (("C:\ProgramData\{0}_memory.zip") -f $Session.ComputerName) -Destination $Output -FromSession $Session -Force -ErrorAction SilentlyContinue

    #Delete 7zip if deployed by plugin
    if (!$7zFlag){

        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(("Remove-Item -Force -Recurse -Path C:\ProgramData\{0}") -f (Split-Path $Installexe -Leaf))
        Invoke-Command -Session $Session -ScriptBlock $ScriptBlock | Out-Null
    }

    # Delete initial winpmem capture and remove winpmem from remote machine
    $ScriptBlock_Remove = $ExecutionContext.InvokeCommand.NewScriptBlock(("Remove-Item -Path C:\ProgramData\{0}, C:\ProgramData\{1}_memory.zip, C:\ProgramData\{1}_memory.raw") -f ((Split-Path $Winpmem -Leaf), $Session.ComputerName))
    Invoke-Command -Session $Session -ScriptBlock $ScriptBlock_Remove | Out-Null
}