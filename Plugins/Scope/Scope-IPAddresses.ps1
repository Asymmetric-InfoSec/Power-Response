<#

.SYNOPSIS
    Plugin-Name: Scope-IPAddresses.ps1
    
.Description
    Performs scoping based on a list of IP addresses provided via string array
    or CSV input file. The output will return True or False based on
    whether or not it was discovered on the system.

    Note: The CSV import file must have a column header of 'Address'

.EXAMPLE
   
    Power-Response Execution

    Set ComputerName Test-PC
    Set Address 127.0.0.1
    run
    
    OR

    Set ComputerName Test-PC
    Set FileList C:\Tools\Addresses.csv
    run

.NOTES
    Author: Drew Schmitt
    Date Created: 10/15/2019
    Twitter: @5ynax
    
    Last Modified By: 
    Last Modified Date: 
    Twitter: 
  
#>

[cmdletbinding(DefaultParameterSetName="Address")]

param (

    [Parameter(ParameterSetName = "Address",Position = 0,Mandatory = $true)]
    [String[]]$Address,

    [Parameter(ParameterSetName = "AddressList",Position = 0,Mandatory = $true)]
    [String]$AddressList,

    [Parameter(ParameterSetName = "Address",Position = 1,Mandatory = $true)]
    [Parameter(ParameterSetName = "AddressList",Position = 1,Mandatory = $true)]
    [String]$ScopeName,

    [Parameter(ParameterSetName = "Address",Position = 2,Mandatory = $true)]
    [Parameter(ParameterSetName = "AddressList",Position = 2,Mandatory = $true)]
    [System.Management.Automation.Runspaces.PSSession[]]$Session
)

process {

    $Output = ('{0}\{1}' -f (Get-PRPath -Output),$ScopeName)

    #Get seconds for unique naming
    $Seconds = (Get-Date -UFormat %s).Split('.')[0]

    #Create output directory if needed
    if (!(Test-Path $Output)){

       $null = New-Item -Type Directory -Path $Output
    }

    #Generate  based on parameter set
    switch ($PSCmdlet.ParameterSetName){

        "Address" {[String[]]$Addresses = $Address}
        "AddressList"{[String[]]$Addresses = (Import-CSV -Path $AddressList | Select-Object -ExpandProperty 'Address')}

    }

    foreach ($AddressItem in $Addresses){

        $ScriptBlock = {

            # Determine if  found on system
            $IPAddressEval = netstat -naob | Select-String -pattern ".*$Using:AddressItem.*" | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value

            # Determine if found on system
            # return PSCustomObject for recording in CSV
            $OutHash =@{ Host = $env:COMPUTERNAME; Detected = [Boolean]$IPAddressEval; Address = $Using:AddressItem; Details = ($IPAddressEval -Join "`n")}
            
            return [PSCustomObject]$OutHash | Select Host, Detected, Address, Details
        }

        #Generate output fules from scoping data collected 
        $OutputPath = ('{0}\Scope_{1}_{2}.csv' -f $Output,$AddressItem,$Seconds)
        Invoke-Command -Session $Session -ScriptBlock $ScriptBlock | Export-CSV -Path $OutputPath -Append -NoTypeInformation

    }
}
