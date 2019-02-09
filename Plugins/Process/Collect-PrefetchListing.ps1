<#

.SYNOPSIS
    Plugin-Name: Collect-PrefetchListing.ps1
    
.Description
    This plugin lists the contents of the C:\Windows\Prefetch directory to quickly
    explore for signs of execution. This plugin does not retrive all contents from 
    the prefetch directory. To get the contents of the prefetch directory, use the
    Collect-Prefetch plugin

.EXAMPLE

    Stand Alone Execution

    .\Collect-PrefetchListing.ps1 -ComputerName Test-PC

    Power-Response Execution

    Set ComputerName Test-PC
    Run

.NOTES
    Author: Drew Schmitt
    Date Created: 2/8/2019
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

        # Retrieves the child items of C:\Windows\Prefetch
        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock("Get-ChildItem -Path C:\Windows\Prefetch")
        
        #Execute and output to a file in $global:PowerResponse.OutputPath\Prefetch\Collect-PrefetchListing.txt
        #If the plugin was run previously, the results will be appended to $global:PowerResponse.OutputPath\Prefetch\Collect-PrefetchListing.txt
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock | Out-File "$Output\_Collect-PrefetchListing.txt" -Append -Force

    }


}