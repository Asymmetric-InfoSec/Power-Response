<#

.SYNOPSIS
    Plugin-Name: Collect-NetworkData
    
.Description

    Collects network information from remote hosts including:

    TCP Connections
    UDP Connections (PowerShell is limited on informaiton provided for UDP connections)
    Network Connection Profiles
    Interface Information
    DNS Client Cache
    Routing Information
    Shares Information
    ARP Information

    Note: When running this plugin, all data will be stored in separate CSV files with a name 
    similar to [Date]_Collect-NetworkData_[Data Type]

.EXAMPLE

    Stand Alone Execution:

    ./Collect-NetworkData.ps1 -ComputerName Test-PC

    Power-Response Execution:

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

process {

    foreach ($Computer in $ComputerName) {

        # Get TCP Connection Information

        $ScriptBlock_TCP = $ExecutionContext.InvokeCommand.NewScriptBlock('Get-NetTCPConnection | Select  LocalAddress, LocalPort, RemoteAddress, RemotePort, OwningProcess, CreationTime, InstanceID, State')
    
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock_TCP | Out-PRFile -Append "TCP"

        # Get UDP Connection Information

        $ScriptBlock_UDP = $ExecutionContext.InvokeCommand.NewScriptBlock('get-netudpendpoint | select LocalAddress, LocalPort, OwningProcess, CreationTime')

        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock_UDP | Out-PRFile -Append "UDP"

        # Get Network Connection Profile(s)

        $ScriptBlock_NetProfile = $ExecutionContext.InvokeCommand.NewScriptBlock('Get-NetConnectionProfile')
    
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock_NetProfile | Out-PRFile -Append "NetProfile"

        # Get Inferface Information

        $ScriptBlock_NetConfig = $ExecutionContext.InvokeCommand.NewScriptBlock('Get-NetIPConfiguration')
    
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock_NetConfig | Out-PRFile -Append "NetConfig"

        # Get-DNSClientCache

        $ScriptBlock_DNSClientCache = $ExecutionContext.InvokeCommand.NewScriptBlock('Get-DNSClientCache')
    
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock_DNSClientCache | Out-PRFile -Append "DNSCache"

        # Get Routing Information

        $ScriptBlock_Route = $ExecutionContext.InvokeCommand.NewScriptBlock('Get-NETRoute')
    
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock_Route | Out-PRFile -Append "RouteTable"

        # Get Share Information

        $ScriptBlock_PSDrive = $ExecutionContext.InvokeCommand.NewScriptBlock('Get-PSDrive')
    
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock_PSDrive | Out-PRFile -Append "Shares"

        # Get ARP Information

        $ScriptBlock_ARP = $ExecutionContext.InvokeCommand.NewScriptBlock('Get-NetNeighbor')
    
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock_ARP | Out-PRFile -Append "ARP"

    }

}