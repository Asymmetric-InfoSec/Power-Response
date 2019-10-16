<#

.SYNOPSIS
    Plugin-Name: Eradicate-Services.ps1
    
.Description
    This plugin allows for incident responders to eradicate services from
    known compromised systems. This plugin can take an explicit list of
    paths or a CSV list of different paths to eradicate from the 
    target machines.

    Note: If using a CSV of paths, the header must be 'Service'

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

[cmdletbinding(DefaultParameterSetName="Service")]

param (

    [Parameter(ParameterSetName="Service",Mandatory=$true,Position=0)]
    [String[]]$Service,

    [Parameter(ParameterSetName="ServiceList",Mandatory=$true,Position=0)]
    [String]$ServiceList,

    [Parameter(ParameterSetName="Service",Mandatory=$true,Position=1)]
    [Parameter(ParameterSetName="ServiceList",Mandatory=$true,Position=1)]
    [String]$EradicateName,

    [Parameter(ParameterSetName="Service",Mandatory=$true,Position=2)]
    [Parameter(ParameterSetName="ServiceList",Mandatory=$true,Position=2)]
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

        "Service" {[String[]]$Services = $Service}
        "ServiceList"{[String[]]$Services = (Import-CSV -Path $ServiceList | Select-Object -ExpandProperty 'Service')}

    }

    foreach ($ServiceItem in $Services) {

        $Scriptblock = {

            try {

                $null = Get-Service -Name "$Using:ServiceItem" -ErrorAction Stop | Stop-Service
                $Command = "sc.exe delete $Using:ServiceItem"
                $null = Invoke-Expression -Command $Command -ErrorAction Stop
                $Outhash = @{ Host=$ENV:ComputerName; Service=$Using:ServiceItem; Eradicated=$true }
                return [PSCustomObject]$Outhash

            } catch {

                $Outhash = @{ Host=$ENV:ComputerName; Service=$Using:ServiceItem; Eradicated=$false }
                return [PSCustomObject]$Outhash

            }
        }

        #Generate output from data collected 
        $OutputPath = ('{0}\Scope_{1}_{2}.csv' -f $Output,$ServiceItem,$Seconds)
        Invoke-Command -Session $Session -ScriptBlock $ScriptBlock | Export-CSV -Path $OutputPath -Append -NoTypeInformation
    } 
}
