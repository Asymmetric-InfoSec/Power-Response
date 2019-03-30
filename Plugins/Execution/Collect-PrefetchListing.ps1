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

    )

process{

    # Retrieves the child items of C:\Windows\Prefetch
    $PrefetchFiles = Get-ChildItem -Path C:\Windows\Prefetch

    foreach ($Prefetchfile in $PrefetchFiles) {

        $PrefetchHash = @{

            Name = $PrefetchFile.Name
            CreationTimeUTC = $PrefetchFile.CreationTimeUTC
            LastWriteTimeUTC = $PrefetchFile.LastWriteTimeUTC
            LastAccessTimeUTC = $PrefetchFile.LastAccessTimeUTC
            Length = $PrefetchFile.Length
        }

        [PSCustomObject]$PrefetchHash | Select Name, CreationTimeUTC, LastWriteTimeUTC, LastAccessTimeUTC, Length
    }
}