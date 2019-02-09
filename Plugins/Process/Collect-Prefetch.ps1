<#

.SYNOPSIS
    Plugin-Name: Collect-Prefetch.ps1
    
.Description

    This plugin will retrieve prefetch files from a remote host and move them to a specified
    output directory based on the the output path provided from Power-Response. By default,
    this plugin will retrieve all prefetch files in the C:\Windows\Prefetch directory, 
    however, you can specify a specific prefetch file to retrieve using the -PrefetchName
    parameter.

.EXAMPLE

    Stand Alone Execution:

    .\Collect-Prefetch.ps1 -ComputerName Test-PC

    Power-Response Execution

    Set ComputerName Test-PC
    Run

    OR

    Set ComputerName Test-PC
    Set PrefetchName 7ZFM.EXE-3129C294.pf
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
    [string[]]$ComputerName,
    [Parameter(Mandatory=$false,Position=1)]
    [string[]]$PrefetchName

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

        If ($PrefetchName){

            #Copy specified prefetch file to $Output
            Copy-Item "C:\Windows\Prefetch\$PrefetchName" -Destination "$Output\" -FromSession $Session -Force -ErrorAction SilentlyContinue

        }else{

            # Recursively copy all prefetch files to $Output
            Copy-Item "C:\Windows\Prefetch\" -Recurse -Destination "$Output\" -FromSession $Session -Force -ErrorAction SilentlyContinue

        }

        #Close PS remoting session
        $Session | Remove-PSSession
    
    }

}

