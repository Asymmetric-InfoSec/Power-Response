<#

.SYNOPSIS
    Plugin-Name: Collect-Prefetch
    
.Description

    This plugin will retrieve prefetch files from a remote host and move them to a specified
    output directory based on the the output path provided from Power-Response. 

.EXAMPLE

    Stand Alone Execution:

    .\Collect-Prefetch -ComputerName Test-PC
    Note: Output most likely will end up in C:\Prefetch

    Power-Response Execution

    Set ComputerName Test-PC
    Run

.NOTES
    Author: Drew
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

    # Set $Output for where to store recovered prefetch files
    $Output= ("{0}\Prefetch" -f $global:PowerResponse.OutputPath)

    # Create Subdirectory in $global:PowerResponse.OutputPath for storing prefetch
    If (-not (Test-Path $Output)) {
        New-Item -Type Directory -Path $Output | Out-Null
    }   

    foreach ($Computer in $ComputerName) {

        # Create session on remote host
        $Session = New-PSSession -ComputerName "$Computer"

        Copy-Item "C:\Windows\Prefetch\*" -Destination "$Output\" -FromSession $Session -Force -ErrorAction SilentlyContinue

        $Session | Remove-PSSession
    
    }

}

