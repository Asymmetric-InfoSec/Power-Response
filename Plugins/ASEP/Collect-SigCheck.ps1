<#

.SYNOPSIS
    Plugin-Name: Collect-Sigcheck.ps1
    
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
    Sigcheck

    Note: If using the $Recurse switch, this may take a long time 
    to complete.

.EXAMPLE
    Collect-Sigcheck.ps1 -ComputerName Test-PC -Location C:\Windows [-Recurse]

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
    [string[]]$ComputerName,

    [Parameter(Mandatory=$true,Position=1)]
    [string]$Location,

    [Parameter(Mandatory=$false)]
    [Switch]$Recurse

    )

process{

    #Get the root Power-Response directory - Assumes that the plugin is located in the plugins/ASEP directory
    $PRRoot = (Get-Item $PSScriptRoot).parent.parent.FullName

    #Sigcheck executable locations
    $Sigcheck64 = "$PRRoot\Bin\Sigcheck64.exe"
    $Sigcheck32 = "$PRRoot\Bin\Sigcheck.exe"

    #Verify binaries exist in Bin
    $64bitTestPath = Get-Item -Path $Sigcheck64 -ErrorAction SilentlyContinue
    $32bitTestPath = Get-Item -Path $Sigcheck32 -ErrorAction SilentlyContinue

    if (-not $64bitTestPath) {

        Throw "Sigcheck64.exe not detected in Bin. Place 64bit executable in Bin directory and try again."

    } elseif (-not $32bitTestPath) {

        Throw "Sigcheck.exe not detected in Bin. Place 32bit executable in Bin directory and try again."

    }

    #Loop through machines in $ComputerName to obtain data for each machine (if multiple machines are specified)
    foreach ($Computer in $ComputerName) {

    #Handle $ComputerName defined as localhost and not break the Plugin
    if ($Computer -eq "Localhost") {

        $Computer = $ENV:ComputerName
    }
    
    #Verify machine is online and ready for data collection
    if (-not (Test-Connection -ComputerName $Computer -Count 1 -Quiet)) {
        
        Write-Error ("{0} appears to be offline. Cannot gather Sigcheck data." -f $Computer)
        Continue
    }

    #Determine system architecture and select proper Sigcheck executable
    try {
        $Architecture = (Get-WmiObject -ComputerName $Computer -Class Win32_OperatingSystem -Property OSArchitecture -ErrorAction Stop).OSArchitecture
        
        if ($Architecture -eq "64-bit") {

            $Installexe = $Sigcheck64

        } elseif ($Architecture -eq "32-bit") {

            $Installexe = $Sigcheck32

        } else {
            
            Write-Error ("Unknown system architecture ({0}) detected for {1}. Data was not gathered.)" -f $Architecture, $Computer)
            Continue
        }
    } catch {
        
        Write-Error ("Unable to determine system architecture for {0}. Data was not gathered." -f $Computer)
        Continue
    }

    #Copy Sigcheck to remote host
    $SmbPath = ("\\{0}\c`$\ProgramData\{1}" -f $Computer, (Split-Path -Path $Installexe -Leaf))
    try {
        
        Copy-Item -Path $Installexe -Destination $SmbPath -ErrorAction Stop
        $RemoteFile = Get-Item -Path $SmbPath -ErrorAction Stop

        # verify that the file copy succeeded to the remote host
        if (-not $RemoteFile) {
            
            Write-Error ("Remote file not found on {0}. There may have been a problem during the copy process. Data was not gathered." -f $Computer)
            Continue
        }
    } catch {
        
        Write-Error ("An unexpected error occurred while copying Sigcheck to {0}. Data was not gathered" -f $Computer)
        Continue
    }


    #Run Sigcheck on the remote host and collect Sigcheck data (use -s option if $Recurse -eq $true)
    if ($Recurse) {
    
        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(("& C:\ProgramData\{0} /accepteula -nobanner -e -vt -h -c -s {1}") -f ((Split-Path -Path $Installexe -Leaf), $Location))
    
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock

    } else {

         $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(("& C:\ProgramData\{0} /accepteula -nobanner -e -vt -h -c {1}") -f ((Split-Path -Path $Installexe -Leaf), $Location))
    
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock | ConverFrom-CSV

    }
    
    #Remove Sigcheck from remote host
    try {
            Remove-Item -Path $SmbPath -Force -ErrorAction Stop
            
        } catch {
            
            Write-Error ("Unable to remove the Sigcheck executable from {0}. The file will need to be removed manually." -f $Computer)
            Continue
        }

    }

}