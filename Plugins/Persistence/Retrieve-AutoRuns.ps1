<#

.SYNOPSIS
    Plugin-Name: Retrieve-AutoRuns.ps1
    
.Description
    This plugin gathers Auto Start Execution Points from one or several hosts
    using the autorunsc Sysinternals tool. This plugin runs autoruns with the
    following options on each host:

    autorunsc64.exe /accepteula -a * -h -nobanner -vt -s -t -c

    The options that are inlcuded in this execution are:

    -a             Specifies the ASEP type to collect (See below)
    -h             Collects several hashes of each ASEP
    -vt            Queries VirusTotal based on hash only, but does not require explicit acceptance of EULA for VT
    -s             Verifies signatures of all ASEPs
    -t             Standardizes time in UTC format
    -c             Outputs in a CSV format
    -nobanner      Does not inlcude Autoruns banner
    /accepteula    Does not prompt for EULA acceptance

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

    PowerResponse Execution
    Set ComputerName Test-PC
    Run

.NOTES
    Author: Drew Schmitt
    Date Created: 12/29/2018
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

    #Autorunsc executable locations
    $Autorunsc64 = "{0}\Bin\autorunsc64.exe" -f $global:PowerResponse.Config.Path.Bin
    $Autorunsc32 = "{0}\Bin\autorunsc.exe" -f $global:PowerResponse.Config.Path.Bin

    #Verify binaries exist in Bin
    $64bitTestPath = Get-Item -Path $Autorunsc64 -ErrorAction SilentlyContinue
    $32bitTestPath = Get-Item -Path $Autorunsc32 -ErrorAction SilentlyContinue

    if (!$64bitTestPath) {

        Throw "Autorunsc64.exe not detected in Bin. Place 64bit executable in Bin directory and try again."

    } elseif (!$32bitTestPath) {

        Throw "Autorunsc.exe not detected in Bin. Place 32bit executable in Bin directory and try again."
    }

    #Determine system architecture and select proper Autorunsc executable
    try {

        $Architecture = Invoke-Command -Session $Session -ScriptBlock {(Get-WmiObject -Class Win32_OperatingSystem -Property OSArchitecture -ErrorAction Stop).OSArchitecture}
        
        if ($Architecture -eq "64-bit") {

            $Installexe = $Autorunsc64

        } elseif ($Architecture -eq "32-bit") {

            $Installexe = $Autorunsc32

        } else {
            
            Write-Error ("Unknown system architecture ({0}) detected for {1}. Data was not gathered.)" -f $Architecture, $Session.ComputerName)
            Continue
        }
    } catch {
        
        Write-Error ("Unable to determine system architecture for {0}. Data was not gathered." -f $Session.ComputerName)
        Continue
    }

    #Copy Autorunsc to remote host
    $RemotePath = ("C:\ProgramData\{0}") -f (Split-Path $Installexe -Leaf)

    try {
        
        Copy-Item -Path $Installexe -Destination $RemotePath -ToSession $Session -ErrorAction Stop
        
        $RemoteFile = Invoke-Command -Session $Session -ScriptBlock {Get-Item -Path $($args[0]) -ErrorAction Stop} -ArgumentList $RemotePath

        # verify that the file copy succeeded to the remote host
        if (!$RemoteFile) {
            
            Write-Error ("Remote file not found on {0}. There may have been a problem during the copy process. Data was not gathered." -f $Session.ComputerName)
            Continue
        }

    } catch {
        
        Write-Error ("An unexpected error occurred while copying Autorunsc to {0}. Data was not gathered" -f $Session.ComputerName)
        Continue
    }


    #Run Autorunsc on the remote host and collect ASEP data
    $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(("& {0}\{1} /accepteula -a * -h -nobanner -vt -s -t -c *") -f ($RemotePath, Split-Path -Path $Installexe -Leaf))
    
    Invoke-Command -Session $Session -ScriptBlock $ScriptBlock | ConvertFrom-CSV

    
    #Remove Autorunsc from remote host
    try {
            
            $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(("Remove-Item {0} -Force -ErrorAction Stop") -f ($RemotePath))
            Invoke-Command -Session $Session -ScriptBlock $ScriptBlock
            
        } catch {
            
            Write-Error ("Unable to remove the Autoruns executable from {0}. The file will need to be removed manually." -f $Session.ComputerName)
            Continue
    }
}