<#

.SYNOPSIS
    Plugin-Name: Retrieve-Handles.ps1
    
.Description

	Collects handles information from remote systems for further analysis

.EXAMPLE

	Power-Response Execution

	set ComputerName Test-PC
	run

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
    [System.Management.Automation.Runspaces.PSSession]$Session

    )

process {

	#Verify that bin dependencies are met
    $Bin_32 = ("{0}\handle.exe" -f $global:PowerResponse.Config.Path.Bin)
    $Bin_64 = ("{0}\handle64.exe" -f $global:PowerResponse.Config.Path.Bin)

    if (!(Test-Path $Bin_32)){

        Throw "handle.exe not found in {0}. Place executable in binary directory and try again." -f $global:PowerResponse.Config.Path.Bin
    }

    if (!(Test-Path $Bin_64)){

        Throw "handle64.exe not found in {0}. Place executable in binary directory and try again." -f $global:PowerResponse.Config.Path.Bin
    }

    #Determine remote system architecture
    $OSArchitecture = Invoke-Command -Session $Session -ScriptBlock {(Get-WmiObject Win32_OperatingSystem).OSArchitecture}

    #Select the proper EXE for OS Architecture
    if ($OSArchitecture -eq "64-bit") {

        $LocalExe = $Bin_64
        $RemoteExe = "handle64.exe"
    }

    if ($OSArchitecture -eq "32-bit") {

        $LocalExe = $Bin_32
        $RemoteExe = "handle.exe"
    }

    #Copy binary to remote machine for execution and data collection
    try {

        Copy-Item -Path $LocalExe -Destination "C:\ProgramData\$RemoteExe" -ToSession $Session -Force -ErrorAction Stop

    } catch {

        throw "Error copying the binary to the remote maching. Quitting."
    }

    #Collect Data from the remote machine

    $HandlesRaw = Invoke-Command -Session $Session -ScriptBlock {Invoke-Expression -Command "C:\ProgramData\$($args[0]) -accepteula | Select-Object -Skip 5"} -ArgumentList $RemoteExe

    #Format data for ingestion into readable Format

    $Handles = $HandlesRaw | Select-Object -Property @{ N = "Process"; E = { ($_ -split '(?<!:)\s+')[0] } }, @{ N = "ID"; E = { (($_ -split '(?<!:)\s+')[1] -replace 'pid:\s*') } }, @{ N = "Type"; E = { ($_ -split '(?<!:)\s+')[2] -replace 'type:\s*' } }, @{ N = "Path"; E = { ($_ -split '(?<!:)\s+')[3] -replace '^[^ ]*: ' } }
                                               
    [PSCustomObject]$Handles

    #Remove handles binary

    Invoke-Command -Session $Session -ScriptBlock {Remove-Item -Path "C:\ProgramData\$($args[0])" -Force} -ArgumentList $RemoteExe
                                        
}