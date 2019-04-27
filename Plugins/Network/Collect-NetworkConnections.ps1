<#

.SYNOPSIS
    Plugin-Name: Collect-NetworkConnections.ps1
    
.Description

    Collects network connection (TCP and UDP) information from remote hosts 

.EXAMPLE

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

    )

process {

    # Get TCP Connection Information

    try {

        $TCPConnections = Get-NetTCPConnection | Select LocalAddress, LocalPort, RemoteAddress, RemotePort, OwningProcess, CreationTime, State

        foreach ($Connection in $TCPConnections){

            $OwningProcessName = Get-Process -ID ($Connection.OwningProcess)
            
            $TCPConArray = @{

                Protocol = "TCP"
                LocalAddress = $Connection.LocalAddress
                LocalPort = $Connection.LocalPort
                RemoteAddress = $Connection.RemoteAddress
                RemotePort = $Connection.RemotePort
                OwningProcessID = $Connection.OwningProcess
                OwningProcessName = $OwningProcessName.Name
                CreationTime = $Connection.CreationTime
                State = $Connrction.State

            }

            [PSCustomObject]$TCPConArray | Select Protocol, LocalAddress, LocalPort, RemoteAddress, RemotePort, OwningProcessID, OwningProcessName, CreationTime, State

        }

    } catch {

        Write-Warning "Could not collect TCP connection information."
    } 

    # Get UDP Connection Information

    try {

        $UDPConnections = Get-NetUDPEndPoint | Select LocalAddress, LocalPort, OwningProcess, CreationTime

        foreach ($Connection in $UDPConnections){

            $OwningProcessName = Get-Process -ID ($Connection.OwningProcess)
            
            $UDPConArray = @{

                Protocol = "UDP"
                LocalAddress = $Connection.LocalAddress
                LocalPort = $Connection.LocalPort
                RemoteAddress = $Null
                RemotePort = $Null
                OwningProcessID = $Connection.OwningProcess
                OwningProcessName = $OwningProcessName.Name
                CreationTime = $Connection.CreationTime
                State = $Null

            }

            [PSCustomObject]$UDPConArray | Select Protocol, LocalAddress, LocalPort, RemoteAddress, RemotePort, OwningProcessID, OwningProcessName,CreationTime, State
        
        }
        
    } catch {

        Write-Warning "Could not collect UDP connection information."
    }  
}