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

    # Set $Output for where to store recovered memory
    $Output= Get-PRPath -ComputerName $Session.ComputerName -Directory 'Memory'

    # Create Subdirectory in $global:PowerResponse.OutputPath for storing memory
    If (!(Test-Path $Output)) {

        New-Item -Type Directory -Path $Output | Out-Null
    }

    # Verify that 7za and winpmem executables are located in (Get-PRPath -Bin)

    $7za32 = ("{0}\7za_x86.exe" -f (Get-PRPath -Bin))
    $7za64 = ("{0}\7za_x64.exe" -f (Get-PRPath -Bin))
    $Winpmem = ("{0}\winpmem.exe" -f (Get-PRPath -Bin))

    $7z64bitTestPath = Get-Item -Path $7za64 -ErrorAction SilentlyContinue
    $7z32bitTestPath = Get-Item -Path $7za32 -ErrorAction SilentlyContinue
    $WinpmemTestPath = Get-Item -Path $Winpmem -ErrorAction SilentlyContinue

    if (-not $7z64bitTestPath) {

        Throw "64 bit version of 7za.exe not detected in Bin. Place 64bit executable in Bin directory and try again."

    } elseif (-not $7z32bitTestPath) {

        Throw "32 bit version of 7za.exe not detected in Bin. Place 32bit executable in Bin directory and try again."

    } elseif (-not $WinpmemTestPath) {

        Throw "winpmem not detected in Bin. Place executable in Bin directory and try again."
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
    $RemotePathWinpmem = ("C:\ProgramData\{0}" -f (Split-Path -Path $Winpmem -Leaf))
    
    try {
    
    Copy-Item -Path $Winpmem -Destination $RemotePathWinpmem -ToSession $Session -ErrorAction Stop
    
    $RemoteFileWinpmem = Invoke-Command -Session $Session -ScriptBlock {Get-Item -Path $($args[0]) -ErrorAction Stop} -ArgumentList $RemotePathWinpmem

    # verify that the file copy succeeded to the remote host
        if (!$RemoteFileWinpmem) {
        
            Write-Error ("Winpmem not found on {0}. There may have been a problem during the copy process. Memory was not acquired." -f $Session.ComputerName)
            Continue

            }

        } catch {
    
            Write-Error ("An unexpected error occurred while copying winpmem to {0}. Memory not acquired." -f $Session.ComputerName)
            Continue
        }

    # Copy 7za.exe to remote system

    $RemotePath7za = ("C:\ProgramData\{0}" -f (Split-Path -Path $Installexe -Leaf))
    
    try {
    
    Copy-Item -Path $Installexe -Destination $RemotePath7za -ToSession $Session -ErrorAction Stop
    
    $RemoteFile7za = Invoke-Command -Session $Session -ScriptBlock {Get-Item -Path $($args[0]) -ErrorAction Stop} -ArgumentList $RemotePath7za

    # verify that the file copy succeeded to the remote host
    if (!$RemoteFile7za) {
        
        Write-Error ("7za.exe not found on {0}. There may have been a problem during the copy process. Memory cannot be compressed." -f $Session.ComputerName)
        Continue

        }

    } catch {
    
        Write-Error ("An unexpected error occurred while copying 7za.exe to {0}. Memory cannot be compressed." -f $Session.ComputerName)
        Continue

    }

    # Execute winpmem on remote machine to capture memory

    $ScriptBlock_Mem = $ExecutionContext.InvokeCommand.NewScriptBlock(("& '{0}' -o C:\ProgramData\{1}_memory.raw --volume_format raw -dd -t") -f (($RemotePathWinpmem), $Session.ComputerName))

    Invoke-Command -Session $Session -ScriptBlock $ScriptBlock_Mem

    # Compress winpmem capture

    $ScriptBlock_Compress = $ExecutionContext.InvokeCommand.NewScriptBlock(("& '{0}' a C:\ProgramData\{1}_memory.zip C:\ProgramData\{1}_memory.raw") -f ($RemotePath7za, $Session.ComputerName))

    Invoke-Command -Session $Session -ScriptBlock $ScriptBlock_Compress

    # Copy winpmem capture back to $Output (Uses $Session)

    Copy-Item -Path (("C:\ProgramData\{0}_memory.zip") -f $Session.ComputerName) -Destination "$Output\" -FromSession $Session -Force -ErrorAction SilentlyContinue

    # Delete initial winpmem capture and remove winpmem from remote machine

    $ScriptBlock_Remove = $ExecutionContext.InvokeCommand.NewScriptBlock(("Remove-Item -Path {0}, {1}, C:\ProgramData\{2}_memory.zip, C:\ProgramData\{2}_memory.raw") -f ($RemotePathWinpmem, $RemotePath7za, $Session.ComputerName))

    Invoke-Command -Session $Session -ScriptBlock $ScriptBlock_Remove

}