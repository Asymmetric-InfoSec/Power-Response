<#

.SYNOPSIS
    Plugin-Name: Scope-RegistryKeys.ps1
    
.Description
    Performs scoping based on a list of registry keys provided via string array
    or CSV input file. The output will return True or False based on
    whether or not it was discovered on the system.

    Note: The CSV import file must have a column header of 'RegistryKey'

    Note: Keep in mind that this scoping plugin scopes based on KEY and not Property or Values.

    Note: PowerShell has a hard time with wildcarding multiple keys at one time using Get-Item

    --Key Formatting Notes--

    For HKEY_LOCAL_MACHINE:

    HLKM:\Path\To\Key

    For HKEY_CURRENT_USER:

    HKCU:\Path\To\Key

    For any user on the system:

    HKU:\*\Path\To\Key

.EXAMPLE
   
    Power-Response Execution

    Set ComputerName Test-PC
    Set RegistryKey HKLM:\Path\To\Malicious\Key
    run
    
    OR

    Set ComputerName Test-PC
    Set RegistryKeyList C:\Tools\RegKeys.csv
    run

.NOTES
    Author: Drew Schmitt
    Date Created: 10/15/2019
    Twitter: @5ynax
    
    Last Modified By: 
    Last Modified Date: 
    Twitter: 
  
#>

[cmdletbinding(DefaultParameterSetName="RegistryKey")]

param (

    [Parameter(ParameterSetName = "RegistryKey", Position = 0, Mandatory = $true)]
    [String[]]$RegistryKey,

    [Parameter(ParameterSetName = "RegistryKeyList", Position = 0, Mandatory = $true)]
    [String]$RegistryKeyList,

    [Parameter(ParameterSetName = "RegistryKey",Position = 1,Mandatory = $true)]
    [Parameter(ParameterSetName = "RegistryKeyList",Position = 1,Mandatory = $true)]
    [String]$ScopeName,

    [Parameter(ParameterSetName = "RegistryKey",Position = 2,Mandatory = $true)]
    [Parameter(ParameterSetName = "RegistryKeyList",Position = 2,Mandatory = $true)]
    [System.Management.Automation.Runspaces.PSSession[]]$Session
)

process {

    $Output = ('{0}\{1}' -f (Get-PRPath -Output),$ScopeName)

    #Get seconds for unique naming
    $Seconds = (Get-Date -UFormat %s).Split('.')[0]

    #Create output directory if needed
    if (!(Test-Path -Path $Output)){

        $null = New-Item -Type Directory -Path $Output
    }

    #Generate based on parameter set
    switch ($PSCmdlet.ParameterSetName){

        "RegistryKey" {[String[]]$RegistryKeys = $RegistryKey}
        "RegistryKeyList"{[String[]]$RegistryKeys = (Import-CSV -Path $RegistryKeyList | Select-Object -ExpandProperty 'RegistryKey')}

    }

    foreach ($RegistryKeyItem in $RegistryKeys){
        
        $ScriptBlock = {

            #Mount PS Drive for processes
            $null = New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS -ErrorACtion SilentlyContinue
            
            # Determine if found on system
            $FullKeyEval = ((Get-Item -Path $Using:RegistryKeyItem).Name -Join "`n" -ErrorAction SilentlyContinue)

            # return PSCustomObject for recording in CSV
            $OutHash =@{Host = $env:COMPUTERNAME; Detected = [Boolean]$FullKeyEval; Keys = $FullKeyEval}
            
            return [PSCustomObject]$OutHash | Select Host, Detected, Keys

            $null = Remove-PSDrive -Name HKU -Force -ErrorAction SilentlyContinue       
        }
        
        #Generate output fules from scoping data collected
        $OutputPath = ('{0}\Scope_{1}_{2}.csv' -f $Output,($RegistryKeyItem -Replace "\\","%5c" -Replace ":","%3a" -Replace "\*","%2a"),$Seconds)
        Invoke-Command -Session $Session -ScriptBlock $ScriptBlock | Export-CSV -Path $OutputPath -Append -NoTypeInformation

    }   
}
