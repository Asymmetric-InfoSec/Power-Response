<#

.SYNOPSIS
    Plugin-Name: Retrieve-Sigcheck.ps1
    
.Description
    This plugin uses Sigcheck to verify the digital signature and version
    information of executables located (recursively) in the specified location.

    This execution is equivalent to executing: 

    Sigcheck.exe /accepteula -nobanner -e -vt -h -c -s [location]

    The options that are inlcuded in this execution are:

    -e             Executables only (regardless of extension)
    -vt            Submit to VirusTotal (hashes only)
    -h             Show hashes
    -c             Output as CSV (comma delmited)
    -s             Recursive subdirectories (if utilizing the $Recurse switch)
    -nobanner      Does not inlcude Autoruns banner
    /accepteula    Does not prompt for EULA acceptance

    Dependencies:

    PowerShell remoting
    Sigcheck (must be downloaded separately)

    Note: If using the $Recurse switch, this may take a long time 
    to complete.

.EXAMPLE

    PowerResponse Execution (Non-recursive)
    Set ComputerName Test-PC
    Set Location C:\Windows
    Run

    PowerResponse Execution (Recursive)
    Set ComputerName Test-PC
    Set Location C:\Windows
    Set Recurse $true
    Run

.NOTES
    Author: Drew Schmitt
    Date Created: 1/2/2019
    Twitter: @5ynax
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param (

    [Parameter(Mandatory=$true,Position=0)]
    [System.Management.Automation.Runspaces.PSSession]$Session,

    [Parameter(Mandatory=$true,Position=1)]
    [string]$Location,

    [Parameter(Mandatory=$false,Position=2)]
    [Switch]$Recurse

    )

process{

    # Sigcheck executable locations
    $Sigcheck64 = ("{0}\sigcheck64.exe" -f (Get-PRPath -Bin))
    $Sigcheck32 = ("{0}\sigcheck.exe" -f (Get-PRPath -Bin))

    # Verify binaries exist in Bin
    $64bitTestPath = Get-Item -Path $Sigcheck64 -ErrorAction SilentlyContinue
    $32bitTestPath = Get-Item -Path $Sigcheck32 -ErrorAction SilentlyContinue

    if (!$64bitTestPath) {

        Throw "Sigcheck64.exe not detected in Bin. Place 64bit executable in Bin directory and try again."

    } elseif (!$32bitTestPath) {

        Throw "Sigcheck.exe not detected in Bin. Place 32bit executable in Bin directory and try again."

    }

    # Determine system architecture and select proper Sigcheck executable
    try {

        $Architecture = Invoke-Command -Session $Session -ScriptBlock {(Get-WmiObject -Class Win32_OperatingSystem -Property OSArchitecture -ErrorAction Stop).OSArchitecture}
        
        if ($Architecture -eq "64-bit") {

            $Installexe = $Sigcheck64

        } elseif ($Architecture -eq "32-bit") {

            $Installexe = $Sigcheck32

        } else {
            
            Write-Error ("Unknown system architecture ({0}) detected for {1}. Data was not gathered.)" -f $Architecture, $Session.ComputerName)
            Continue
        }
    } catch {
        
        Write-Error ("Unable to determine system architecture for {0}. Data was not gathered." -f $Session.ComputerName)
        Continue
    }

    # Copy Sigcheck to remote host
    $RemotePath = ("C:\ProgramData\{0}") -f (Split-Path $Installexe -Leaf)

    try {
        
        Copy-Item -Path $Installexe -Destination $RemotePath -ToSession $Session -ErrorAction Stop
        
        $RemoteFile = Invoke-Command -Session $Session -ScriptBlock {Get-Item -Path $($args[0]) -ErrorAction Stop} -Argumentlist $RemotePath

        # verify that the file copy succeeded to the remote host
        if (!$RemoteFile) {
            
            Write-Error ("Remote file not found on {0}. There may have been a problem during the copy process. Data was not gathered." -f $Session.ComputerName)
            Continue
        }

    } catch {
        
        Write-Error ("An unexpected error occurred while copying Sigcheck to {0}. Data was not gathered" -f $Session.ComputerName)
        Continue
    }

    # Run Sigcheck on the remote host and collect Sigcheck data (use -s option if $Recurse -eq $true)
    if ($Recurse) {
    
        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(("& '{0} /accepteula -nobanner -e -vt -h -c -s {1}'") -f ($RemotePath, $Location))
    
        Invoke-Command -Session $Session -ScriptBlock $ScriptBlock

    } else {

         $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(("& '{0} /accepteula -nobanner -e -vt -h -c {1}'") -f ($RemotePath, $Location))
    
        Invoke-Command -Session $Session -ScriptBlock $ScriptBlock | ConvertFrom-CSV

    }
    
    # Remove Sigcheck from remote host
    try {
            
            $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(("Remove-Item {0} -Force -ErrorAction Stop") -f ($RemotePath))
            Invoke-Command -Session $Session -ScriptBlock $ScriptBlock
            
        } catch {
            
            Write-Error ("Unable to remove the Sigcheck executable from {0}. The file will need to be removed manually." -f $Session.ComputerName)
            Continue
    }
}