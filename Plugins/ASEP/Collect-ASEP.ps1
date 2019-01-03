<#

.SYNOPSIS
    Plugin-Name: Collect-ASEP.ps1
    
.Description
    This plugin gathers Auto Start Execution Points from one or several hosts
    using the autorunsc Sysinternals tool. This plugin runs autoruns with the
    following options on each host:

    autorunsc64.exe -accepteula -a * -h -nobanner -v -s -t -c

    The options that are inlcuded in this execution are:

    -a             Specifies the ASEP type to collect (See below)
    -h             Collects several hashes of each ASEP
    -v             Queries VirusTotal based on hash only
    -s             Verifies signatures of all ASEPs
    -t             Standardizes time in UTC format
    -c             Outputs in a CSV format
    -nobanner      Does not inlcude Autoruns banner
    -accepteula    Does not prompt for EULA acceptance

    This plugin opts for collection of all ASEPs available including:

    Boot execute, codecs, appinit DLLs, Explorer addons, sidebar gadgets, image
    highjacks, Internet Explorer addons, known DLLs, logon startups, WMI entries,
    Winsock protocol and network providers, Office addins, printer monitor DLLs,
    LSA security providers, Autostart services and non-disabled drivers, scheduled
    tasks, winlogon entries

    Note: If you are interested in running a different version of this command, you 
    can simply edit the Invoke-Command entry below and adjust as needed.

    Note: If you are using custom directory paths, you will need to edit the EXE 
    checks in the script so that it does not error and exit. Best practice, use the
    default paths provided by Power-Response.

    Dependencies:

    PowerShell remoting
    Autorunsc

.EXAMPLE
    Get-ASEP.ps1 -ComputerName Test-PC

    PowerResponse Execution
    Set ComputerName Test-PC
    Run

.NOTES
    Author: 5yn@x
    Date Created: 12/29/2018
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

    #Get the root Power-Response directory - Assumes that the plugin is located in the plugins/ASEP directory
    $PRRoot = (Get-Item $PSScriptRoot).parent.parent.FullName

    #Autorunsc executable locations
    $Autorunsc64 = "$PRRoot\Bin\autorunsc64.exe"
    $Autorunsc32 = "$PRRoot\Bin\autorunsc.exe"

    #Verify binaries exist in Bin
    $64bitTestPath = Get-Item -Path $Autorunsc64 -ErrorAction SilentlyContinue
    $32bitTestPath = Get-Item -Path $Autorunsc32 -ErrorAction SilentlyContinue

    if (-not $64bitTestPath) {

        Throw "Autorunsc64.exe not detected in Bin. Place 64bit executable in Bin directory and try again."

    } elseif (-not $32bitTestPath) {

        Throw "Autorunsc.exe not detected in Bin. Place 32bit executable in Bin directory and try again."

    }

    #Loop through machines in $ComputerName to obtain data for each machine (if multiple machines are specified)
    foreach ($Computer in $ComputerName) {

    #Handle $ComputerName defined as localhost and not break the Plugin
    if ($Computer -eq "Localhost") {

        $Computer = $ENV:ComputerName
    }
    
    #Verify machine is online and ready for data collection
    if (-not (Test-Connection -ComputerName $Computer -Count 1 -Quiet)) {
        
        Write-Error ("{0} appears to be offline. Cannot gather ASEP data." -f $Computer)
        Continue
    }

    #Determine system architecture and select proper Autorunsc executable
    try {
        $Architecture = (Get-WmiObject -ComputerName $Computer -Class Win32_OperatingSystem -Property OSArchitecture -ErrorAction Stop).OSArchitecture
        
        if ($Architecture -eq "64-bit") {

            $Installexe = $Autorunsc64

        } elseif ($Architecture -eq "32-bit") {

            $Installexe = $Autorunsc32

        } else {
            
            Write-Error ("Unknown system architecture ({0}) detected for {1}. Data was not gathered.)" -f $Architecture, $Computer)
            Continue
        }
    } catch {
        
        Write-Error ("Unable to determine system architecture for {0}. Data was not gathered." -f $Computer)
        Continue
    }

    #Copy Autorunsc to remote host
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
        
        Write-Error ("An unexpected error occurred while copying Autorunsc to {0}. Data was not gathered" -f $Computer)
        Continue
    }


    #Run Autorunsc on the remote host and collect ASEP data
    $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(("& C:\ProgramData\{0} /accepteula -a * -h -nobanner -v -s -t -c") -f (Split-Path -Path $Installexe -Leaf))
    
    Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock
    
    #Remove Autorunsc from remote host
    try {
            Remove-Item -Path $SmbPath -Force -ErrorAction Stop
            
        } catch {
            
            Write-Error ("Unable to remove the Autoruns executable from {0}. The file will need to be removed manually." -f $Computer)
            Continue
        }

    }

}