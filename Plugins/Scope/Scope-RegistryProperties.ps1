<#

.SYNOPSIS
    Plugin-Name: Scope-RegistryProperties.ps1
    
.Description
    Performs scoping based on a list of registry key/value pairs provided via string array
    or CSV input file. The output will return True or False based on
    whether or not it was discovered on the system.

    Note: The CSV import file must have a column header of 'RegKeyProperty'

    Note: Keep in mind that this scoping plugin scopes based on properties that belong to a 
    specific key and not necessarily for keys themselves. If you want to scope based on the 
    existence of keys, use Scope-RegistryKeys.ps1.

    Note: PowerShell has a hard time with wildcarding multiple keys at one time using Get-Item

    --Key Formatting Notes--

    For HKEY_LOCAL_MACHINE:

    HLKM:\Path\To\Key

    For HKEY_CURRENT_USER:

    HKCU:\Path\To\Key

    For any user on the system:

    HKU:\*\Path\To\Key

    --Key/Value Formatting Notes--

    All key value pairs must be formatted as 'Key;Value'. These will be parsed in the plugin and
    scoped accordingly

    Example String Array of Key/Value Pairs

    'key1;value1','key2;value2','key3;value3'

.EXAMPLE
   
    Power-Response Execution

    Set ComputerName Test-PC
    Set RegKeyProperty 'HKLM:\Path\To\Malicious\Key;MaliciousProperty'
    run
    
    OR

    Set ComputerName Test-PC
    Set RegistryKeyList C:\Tools\RegKeyProperties.csv
    run

.NOTES
    Author: Drew Schmitt
    Date Created: 10/18/2019
    Twitter: @5ynax
    
    Last Modified By: 
    Last Modified Date: 
    Twitter: 
  
#>

[cmdletbinding(DefaultParameterSetName="RegKeyProperty")]

param (

    [Parameter(ParameterSetName = "RegKeyProperty", Position = 0, Mandatory = $true)]
    [String[]]$RegKeyProperty,

    [Parameter(ParameterSetName = "RegKeyPropertyList", Position = 0, Mandatory = $true)]
    [String]$RegKeyPropertyList,

    [Parameter(ParameterSetName = "RegKeyProperty",Position = 1,Mandatory = $true)]
    [Parameter(ParameterSetName = "RegKeyPropertyList",Position = 1,Mandatory = $true)]
    [String]$ScopeName,

    [Parameter(ParameterSetName = "RegKeyProperty",Position = 2,Mandatory = $true)]
    [Parameter(ParameterSetName = "RegKeyPropertyList",Position = 2,Mandatory = $true)]
    [System.Management.Automation.Runspaces.PSSession[]]$Session
)

process {

    $Output = ('{0}\{1}' -f (Get-PRPath -Output),$EradicateName)

    #Get seconds for unique naming
    $Seconds = (Get-Date -UFormat %s).Split('.')[0]

    #Create output directory if needed
    if (!(Test-Path -Path $Output)){

        $null = New-Item -Type Directory -Path $Output
    }

    #Generate based on parameter set
    switch ($PSCmdlet.ParameterSetName){

        "RegKeyProperty" {[String[]]$RegKeyProperties = $RegKeyProperty}
        "RegKeyPropertyList"{[String[]]$RegKeyProperties = (Import-CSV -Path $RegKeyPropertyList | Select-Object -ExpandProperty 'RegKeyProperty')}

    }

    foreach ($RegKeyPropertyItem in $RegKeyProperties){
        
        $ScriptBlock = {
            
            #Mount PS Drive for processes
            $null = New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS -ErrorAction SilentlyContinue

            $RegKeyValue = $Using:RegKeyPropertyItem
            
            # Determine if found on system
            $FullPropertyEval = (Get-ItemProperty -Path ($RegKeyValue.Split(';')[0]) -Name ($RegKeyValue.Split(';')[1]) -ErrorAction SilentlyContinue)

            # return PSCustomObject for recording in CSV
            $OutHash =@{Host = $env:COMPUTERNAME; Detected = [Boolean]$FullPropertyEval; RegKey = $RegKeyValue.Split(';')[0]; RegProperty = $RegKeyValue.Split(';')[1]}
            
            return [PSCustomObject]$OutHash | Select Host, Detected, RegKey, RegProperty

            $null = Remove-PSDrive -Name HKU -Force -ErrorAction SilentlyContinue      
        }
        
        #Generate output fules from scoping data collected
        $OutputPath = ('{0}\Scope_{1}_{2}.csv' -f $Output,($RegKeyPropertyItem -Replace "\\","%5c" -Replace ":","%3a" -Replace "\*","%2a" -Replace ";","%3b" ),$Seconds)
        Invoke-Command -Session $Session -ScriptBlock $ScriptBlock | Export-CSV -Path $OutputPath -Append -NoTypeInformation

    }
}
