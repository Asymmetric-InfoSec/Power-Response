<#

.SYNOPSIS
    Plugin-Name: Eradicate-Processes.ps1
    
.Description
    This plugin allows for incident responders to eradicate processes from
    known compromised systems. This plugin can take an explicit list of
    paths or a CSV list of different paths to eradicate from the 
    target machines.

    Note: If using a CSV of paths, the header must be 'Process'

.EXAMPLE

    Power-Response Execution

    Set ComputerName Test-PC
    Set Service MaliciousService
    Run

    Set ComputerName Test-PC
    Set PathList C:\Tools\MaliciousServices.csv
    Run

.NOTES
    Author: Drew Schmitt
    Date Created: 10/16/2019
    Twitter: @5ynax
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

[cmdletbinding(DefaultParameterSetName="Process")]

param (

    [Parameter(ParameterSetName="Process",Mandatory=$true,Position=0)]
    [String[]]$Process,

    [Parameter(ParameterSetName="ProcessList",Mandatory=$true,Position=0)]
    [String]$ProcessList,

    [Parameter(ParameterSetName="Process",Mandatory=$true,Position=1)]
    [Parameter(ParameterSetName="ProcessList",Mandatory=$true,Position=1)]
    [String]$EradicateName,

    [Parameter(ParameterSetName="Process",Mandatory=$true,Position=2)]
    [Parameter(ParameterSetName="ProcessList",Mandatory=$true,Position=2)]
    [System.Management.Automation.Runspaces.PSSession[]]$Session

)

process { 

    $Output = ('{0}\{1}' -f (Get-PRPath -Output),$EradicateName)

    #Get seconds for unique naming
    $Seconds = (Get-Date -UFormat %s).Split('.')[0]

    #Create output directory if needed
    if (!(Test-Path $Output)){

       $null = New-Item -Type Directory -Path $Output
    }

    switch ($PSCmdlet.ParameterSetName){

        "Process" {[String[]]$Processes = $Process}
        "ProcessList"{[String[]]$Processes = (Import-CSV -Path $ProcessList | Select-Object -ExpandProperty 'Process')}

    }

    foreach ($ProcessItem in $Processes) {

        $Scriptblock = {

            try {

                $ProcessInfo = Get-WMIObject win32_process -Filter "Name LIKE '$Using:ProcessItem%'" -ErrorAction Stop
                $null = Get-Process -Name $Using:ProcessItem -ErrorAction Stop | Stop-Process -Force -ErrorAction Stop
                $Outhash = @{ Host=$ENV:ComputerName; Eradicated=$true; ProcessName=$ProcessInfo.ProcessName; PID = $ProcessInfo.ProcessId; PPID = $ProcessInfo.ParentProcessId; Path = $ProcessInfo.ExecutablePath; CommandLine = $ProcessInfo.Commandline }

            } catch {

                $Outhash = @{ Host=$ENV:ComputerName; Eradicated=$false; ProcessName=$Using:ProcessItem; PID = ''; PPID =''; Path =''; CommandLine ='' }

            }

            return [PSCustomObject]$OutHash | Select Host, Eradicated, ProcessName, PID, PPID, Path, Commandline
        }

        #Generate output from data collected 
        $OutputPath = ('{0}\Scope_{1}_{2}.csv' -f $Output,$ProcessItem,$Seconds)
        Invoke-Command -Session $Session -ScriptBlock $ScriptBlock | Export-CSV -Path $OutputPath -Append -NoTypeInformation
    } 
}
