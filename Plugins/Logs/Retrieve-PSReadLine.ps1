<#

.SYNOPSIS
    Plugin-Name: Retrieve-PSReadLine.ps1
    
.Description

    This plugin collects the PSReadLine Console Host History (equivalent to .bash_history on Linux).
    The consolehost_history.txt file from PSReadLine is enabled in Windows 10 by default and 
    may be enabled with a KB in Windows 7. 

.EXAMPLE

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
    [System.Management.Automation.Runspaces.PSSession]$Session

    )

process{

    #Set $Output for where to store recovered browsing history
    $Output= (Get-PROutputPath -ComputerName $Session.ComputerName -Directory 'PSReadLine')

    # Create Subdirectory in $global:PowerResponse.OutputPath for storing PSReadLine
    If (-not (Test-Path $Output)) {
        New-Item -Type Directory -Path $Output | Out-Null
    }

    # Get all user profiles on the PC if default, continue if not 
    $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock("Get-ChildItem C:\Users")
    $UserProfiles = Invoke-Command -Session $Session -ScriptBlock $ScriptBlock

    # Retrieve the consolehost_history file for all users on the machine
    Foreach ($UserProfile in $UserProfiles){

        # Copy the ConsoleHost_history file to $Output
        Copy-Item "C:\Users\$UserProfile\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadline\ConsoleHost_history.txt" -Destination "$Output\${UserProfile}_ConsoleHost_History.txt" -FromSession $Session -Force -ErrorAction SilentlyContinue

    }
}    
