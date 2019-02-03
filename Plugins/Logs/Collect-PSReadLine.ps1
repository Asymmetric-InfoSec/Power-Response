<#

.SYNOPSIS
    Plugin-Name: Collect-PSReadLine.ps1
    
.Description

    This plugin collects the PSReadLine Console Host History (equivalent to .bash_history on Linux).
    The consolehost_history.txt file from PSReadLine is enabled in Windows 10 by default and 
    may be enabled with a KB in Windows 7. 

.EXAMPLE

    Stand Alone Execution:

    .\Collect-PSReadLine.ps1 -ComputerName Test-PC
    Note: Output will most likely end up in C:\PSReadLine if running stand alone

    Power-Response Exection:

    Set ComputerName Test-PC
    Run

.NOTES
    Author: Drew Schmitt
    Date Created: 2/2/2019
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

    #Set $Output for where to store recovered browsing history
    $Output= ("{0}\PSReadLine" -f $global:PowerResponse.OutputPath)

    # Create Subdirectory in $global:PowerResponse.OutputPath for storing PSReadLine
    If (-not (Test-Path $Output)) {
        New-Item -Type Directory -Path $Output | Out-Null
    }
   
    foreach ($Computer in $ComputerName) {

        # Create session on remote host
        $Session = New-PSSession -ComputerName "$Computer"

        # Get all user profiles on the PC if default, continue if not 
        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock("Get-ChildItem C:\Users")
        $UserProfiles = Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock

        # Retrieve the consolehost_history file for all users on the machine
        Foreach ($UserProfile in $UserProfiles){

            # Copy the ConsoleHost_history file to $Output
            Copy-Item "C:\Users\$UserProfile\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadline\ConsoleHost_history.txt" -Destination "$Output\${UserProfile}_ConsoleHost_History.txt" -FromSession $Session -Force -ErrorAction SilentlyContinue

        }

        #Close the PS Remoting Session for $Computer
        $Session | Remove-PSSession
    }

}    
