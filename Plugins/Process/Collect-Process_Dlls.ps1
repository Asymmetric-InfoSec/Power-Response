<#

.SYNOPSIS
    Plugin-Name: Collect-Process_Dlls
    
.Description

    Gets modules (processes and dlls) currently being used on the remote machine and includes path

.EXAMPLE

    Stand Alone:

    .\Collect-Process_Dlls -ComputerName Test-PC

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

    [Parameter(Mandatory=$true,Position=0)]
    [string[]]$ComputerName

    )

process{

    foreach ($Computer in $ComputerName) {

        #Run Autorunsc on the remote host and collect ASEP data
        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(@'
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
'@)
    
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock | Select-Object "ProcessID", "ProcessName", "ModuleName", "ModuleBaseAddress", "ModuleMemorySize", "ModuleEntryPointAddress"


    }


}