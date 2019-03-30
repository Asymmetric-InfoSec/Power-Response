<#

.SYNOPSIS
    Plugin-Name: Collect-Process_Dlls.ps1
    
.Description

    Gets modules (processes and dlls) currently being used on the remote machine and includes path

.EXAMPLE

    Power-Response:

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

    )

process{


    Get-Process | Select-Object "ID", "Name", "Modules" | Sort-Object "ID" | Foreach-Object {
        $ProcessID = $PSItem.ID
        $ProcessName = $PSItem.Name
        $PSItem.Modules | Foreach-Object {
            [PSCustomObject]@{
                ProcessID=$ProcessID
                ProcessName=$ProcessName
                ModuleName=$PSItem.FileName
                ModuleBaseAddress=$PSItem.BaseAddress
                ModuleMemorySize=$PSItem.ModuleMemorySize
                ModuleEntryPointAddress=$PSItem.EntryPointAddress
            }
        }
    }
}
