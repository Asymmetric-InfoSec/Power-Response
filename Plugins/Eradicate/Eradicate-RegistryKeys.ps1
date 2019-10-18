<#

.SYNOPSIS
    Plugin-Name: Eradicate-RegistryKeys.ps1
    
.Description
    This plugin allows for incident responders to eradicate registry keys from
    known compromised systems. This plugin can take an explicit list of
    paths or a CSV list of different paths to eradicate from the 
    target machines.

    Note: If using a CSV of paths, the header must be 'RegKey'

    Note: This plugin is meant for the eradication of registry keys and not 
    registry properties. To eradicate registry properties, use the 
    Eradicate-RegistryProperties.ps1 plugin

.EXAMPLE

    Power-Response Execution

    Set ComputerName Test-PC
    Set Key HKLM:\Path\To\Key
    Run

    Set ComputerName Test-PC
    Set PathList C:\Tools\MaliciousRegKeys.csv
    Run

.NOTES
    Author: Drew Schmitt
    Date Created: 10/16/2019
    Twitter: @5ynax
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

[cmdletbinding(DefaultParameterSetName="RegKey")]

param (

    [Parameter(ParameterSetName="RegKey",Mandatory=$true,Position=0)]
    [String[]]$RegKey,

    [Parameter(ParameterSetName="RegKeyList",Mandatory=$true,Position=0)]
    [String]$RegKeyList,

    [Parameter(ParameterSetName="RegKey",Mandatory=$true,Position=1)]
    [Parameter(ParameterSetName="RegKeyList",Mandatory=$true,Position=1)]
    [String]$EradicateName,

    [Parameter(ParameterSetName="RegKey",Mandatory=$false,Position=2)]
    [Parameter(ParameterSetName="RegKeyList",Mandatory=$false,Position=2)]
    [Switch]$Recurse=$false,

    [Parameter(ParameterSetName="RegKey",Mandatory=$true,Position=3)]
    [Parameter(ParameterSetName="RegKeyList",Mandatory=$true,Position=3)]
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

        "RegKey" {[String[]]$RegKeys = $RegKey}
        "RegKeyList"{[String[]]$RegKeys = (Import-CSV -Path $RegKeyList | Select-Object -ExpandProperty 'RegKey')}

    }

     foreach ($RegKeyItem in $RegKeys) {

        $Scriptblock = {

            #Mount PS Drive for processes
            $null = New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS -ErrorAction SilentlyContinue

            try {

                $KeyCount = ((Get-Item -Path $Using:RegKeyItem -ErrorAction Stop).SubKeyCount)

                if (!$Using:Recurse -and $KeyCount -gt 0) {

                    $Outhash = @{ Host=$ENV:ComputerName; Eradicated=$false; Key = $Using:RegKeyItem; Notes = 'Key has subkeys, run with recursion' }
                }

                if ($Using:Recurse -or $KeyCount -eq 0) {

                    try {

                        if ($Using:Recurse) {

                            $null = Remove-Item -Recurse -Force -Path $Using:RegKeyItem -ErrorAction Stop

                        }
                        
                        if (!$Using:Recurse){

                            $null = Remove-Item -Force -Path $Using:RegKeyItem -ErrorAction Stop

                        }
                        
                        $Outhash = @{ Host=$ENV:ComputerName; Eradicated=$true; Key = $Using:RegKeyItem; Notes = '' }
                        

                    } catch {

                        $Outhash = @{ Host=$ENV:ComputerName; Eradicated=$false; Key = $Using:RegKeyItem; Notes = 'Error removing key' }
                    }
                }
            } catch {

                $Outhash = @{ Host=$ENV:ComputerName; Eradicated=$false; Key = $Using:RegKeyItem; Notes = 'Error getting key info' }
            }
            
            return [PSCustomObject]$Outhash | Select Host, Eradicated, Key, Notes
            $null = Remove-PSDrive -Name HKU -Force -ErrorAction SilentlyContinue
        }

        #Generate output from data collected 
        $OutputPath = ('{0}\Scope_{1}_{2}.csv' -f $Output,($RegKeyItem -Replace "\\","%5c" -Replace ":","%3a"),$Seconds)
        Invoke-Command -Session $Session -ScriptBlock $ScriptBlock | Export-CSV -Path $OutputPath -Append -NoTypeInformation
    } 
}
