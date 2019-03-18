<#

.SYNOPSIS
    Plugin-Name: Collect-NetworkConnections.ps1
    
.Description

    Collects network connection (TCP and UDP) information from remote hosts 

.EXAMPLE

    Stand Alone Execution:

    .\Collect-NetworkConnections.ps1 -ComputerName Test-PC

    Power-Response Execution:

    Set ComputerName Test-PC
    Run

.NOTES
    Author: Drew Schmitt
    Date Created: 3/16/2019
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

        # Create session on remote host
        $Session = New-PSSession -ComputerName "$Computer" -SessionOption (New-PSSessionOption -NoMachineProfile)

        # Get TCP Connection Information

        $ScriptBlock_TCP = $ExecutionContext.InvokeCommand.NewScriptBlock('Get-NetTCPConnection | Select  LocalAddress, LocalPort, RemoteAddress, RemotePort, OwningProcess, CreationTime, State')
    
        $TCPConnections = Invoke-Command -Session $Session -ScriptBlock $ScriptBlock_TCP

        foreach ($Connection in $TCPConnections){

            $OwningProcessName = Invoke-Command -Session $Session -ScriptBlock {(Get-Process -ID $($args[0])).Name} -ArgumentList ($Connection.OwningProcess)
            
            $TCPConArray = @{

                Protocol = "TCP"
                LocalAddress = $Connection.LocalAddress
                LocalPort = $Connection.LocalPort
                RemoteAddress = $Connection.RemoteAddress
                RemotePort = $Connection.RemotePort
                OwningProcessID = $Connection.OwningProcess
                OwningProcessName = $OwningProcessName
                CreationTime = $Connection.CreationTime
                State = $Connrction.State

            }

            [PSCustomObject]$TCPConArray | Select Protocol, LocalAddress, LocalPort, RemoteAddress, RemotePort, OwningProcessID, OwningProcessName, CreationTime, State

        }

        # Get UDP Connection Information

        $ScriptBlock_UDP = $ExecutionContext.InvokeCommand.NewScriptBlock('Get-NetUDPEndPoint | select LocalAddress, LocalPort, OwningProcess, CreationTime')

        $UDPConnections = Invoke-Command -Session $Session -ScriptBlock $ScriptBlock_UDP

        foreach ($Connection in $UDPConnections){

            $OwningProcessName = Invoke-Command -Session $Session -ScriptBlock {(Get-Process -ID $($args[0])).Name} -ArgumentList ($Connection.OwningProcess)
            
            $UDPConArray = @{

                Protocol = "UDP"
                LocalAddress = $Connection.LocalAddress
                LocalPort = $Connection.LocalPort
                RemoteAddress = ""
                RemotePort = ""
                OwningProcessID = $Connection.OwningProcess
                OwningProcessName = $OwningProcessName
                CreationTime = $Connection.CreationTime
                State = ""

            }

            [PSCustomObject]$UDPConArray | Select Protocol, LocalAddress, LocalPort, RemoteAddress, RemotePort, OwningProcessID, OwningProcessName,CreationTime, State

        }

        $Session | Remove-PSSession
    }
}