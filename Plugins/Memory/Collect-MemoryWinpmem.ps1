<#

.SYNOPSIS
    Plugin-Name: Collect-MemoryWinpmem.ps1
    
.Description
    This plugin captures memory from a remote host by deploying winpmem to the 
    remote machine and captures memory locally to the remote machine before
    copying back to the output location for PowerResponse. This plugin will
    remove the winpmem PE and delete all locally created files after successfully
    copying the memory acquisition back to the output destionation in
    Power-Response.

.EXAMPLE
    Stand Alone 

    .\Collect-MemoryWinpmem.ps1 -ComputerName Test-PC

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
    [string[]]$ComputerName

    )

process{

    # Set $Output for where to store recovered memory
    $Output= ("{0}\Memory" -f $global:PowerResponse.OutputPath)

    # Create Subdirectory in $global:PowerResponse.OutputPath for storing memory
    If (-not (Test-Path $Output)) {

        New-Item -Type Directory -Path $Output | Out-Null

    }

    # Verify that 7za and winpmem executables are located in $global:PowerResponse.Config.Path.Bin

    $7za32 = ("{0}\7za_x86.exe" -f $global:PowerResponse.Config.Path.Bin)
    $7za64 = ("{0}\7za_x64.exe" -f $global:PowerResponse.Config.Path.Bin)
    $Winpmem = ("{0}\winpmem.exe" -f $global:PowerResponse.Config.Path.Bin)

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

    foreach ($Computer in $ComputerName) {

        #Handle $ComputerName defined as localhost and not break the Plugin
        if ($Computer -eq "Localhost") {

            $Computer = $ENV:ComputerName
        }

        #Verify machine is online and ready for data collection
        if (-not (Test-Connection -ComputerName $Computer -Count 1 -Quiet)) {
        
            Write-Error ("{0} appears to be offline. Cannot acquire memory." -f $Computer)
            Continue
        }

        #Determine system architecture and select proper 7za.exe executable
        try {
         $Architecture = (Get-WmiObject -ComputerName $Computer -Class Win32_OperatingSystem -Property OSArchitecture -ErrorAction Stop).OSArchitecture
        
            if ($Architecture -eq "64-bit") {

                $Installexe = $7za64

            } elseif ($Architecture -eq "32-bit") {

                $Installexe = $7za32

            } else {
            
                Write-Error ("Unknown system architecture ({0}) detected for {1}. Data was not gathered.)" -f $Architecture, $Computer)
                Continue
            }

        } catch {
        
         Write-Error ("Unable to determine system architecture for {0}. Data was not gathered." -f $Computer)
            Continue
        }

        #Establish PS Session criteria

        $Session = New-PSSession -ComputerName "$Computer"
         
        #Copy winpmem to remote host
        $SmbPathWinpmem = ("\\{0}\c`$\ProgramData\{1}" -f $Computer, (Split-Path -Path $Winpmem -Leaf))
        
        try {
        
        Copy-Item -Path $Winpmem -Destination $SmbPathWinpmem -ErrorAction Stop
        $RemoteFileWinpmem = Get-Item -Path $SmbPathWinpmem -ErrorAction Stop

        # verify that the file copy succeeded to the remote host
            if (-not $RemoteFileWinpmem) {
            
                Write-Error ("Winpmem not found on {0}. There may have been a problem during the copy process. Memory was not acquired." -f $Computer)
                Continue

                }

            } catch {
        
        Write-Error ("An unexpected error occurred while copying winpmem to {0}. Memory not acquired." -f $Computer)
        Continue

        }

        # Copy 7za.exe to remote system

        $SmbPath7za = ("\\{0}\c`$\ProgramData\{1}" -f $Computer, (Split-Path -Path $Installexe -Leaf))
        
        try {
        
        Copy-Item -Path $Installexe -Destination $SmbPath7za -ErrorAction Stop
        $RemoteFile7za = Get-Item -Path $SmbPath7za -ErrorAction Stop

        # verify that the file copy succeeded to the remote host
        if (-not $RemoteFile7za) {
            
            Write-Error ("7za.exe not found on {0}. There may have been a problem during the copy process. Memory cannot be compressed." -f $Computer)
            Continue
            }

        } catch {
        
        Write-Error ("An unexpected error occurred while copying 7za.exe to {0}. Memory cannot be compressed." -f $Computer)
        Continue

        }

        # Execute winpmem on remote machine to capture memory

        $ScriptBlock_Mem = $ExecutionContext.InvokeCommand.NewScriptBlock(("& C:\ProgramData\{0} -o C:\ProgramData\{1}_memory.raw --volume_format raw -dd -t") -f ((Split-Path -Path $Winpmem -Leaf), $Computer))
    
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock_Mem

        # Compress winpmem capture

        $ScriptBlock_Compress = $ExecutionContext.InvokeCommand.NewScriptBlock(("& C:\ProgramData\{0} a C:\ProgramData\{1}_memory.zip C:\ProgramData\{1}_memory.raw") -f ((Split-Path -Path $Installexe -Leaf), $Computer))
    
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock_Compress

        # Copy winpmem capture back to $Output (Uses $Session)

        Copy-Item -Path (("C:\ProgramData\{0}_memory.zip") -f $Computer) -Destination "$Output\" -FromSession $Session -Force -ErrorAction SilentlyContinue

        # Delete initial winpmem capture and remove winpmem from remote machine

        $ScriptBlock_Remove = $ExecutionContext.InvokeCommand.NewScriptBlock(("Remove-Item -Path C:\ProgramData\{0}, C:\ProgramData\{1}, C:\ProgramData\{2}_memory.zip, C:\ProgramData\{2}_memory.raw") -f ((Split-Path -Path $Winpmem -Leaf), (Split-Path -Path $Installexe -Leaf), $Computer))

        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock_Remove

        #Remove PS Session

        $Session | Remove-PSSession

    }

}