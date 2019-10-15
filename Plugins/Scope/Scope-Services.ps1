<#

.SYNOPSIS
    Plugin-Name: Scope-Services.ps1
    
.Description
    Performs scoping based on a list of services provided via string array
    or CSV input file. The output will return True or False based on
    whether or not it was discovered on the system.

    Note: The CSV import file must have a column header of 'Service'

.EXAMPLE
   
    Power-Response Execution

    Set ComputerName Test-PC
    Set Service MaliciousService
    run
    
    OR

    Set ComputerName Test-PC
    Set FileList C:\Tools\Services.csv
    run

.NOTES
    Author: Drew Schmitt
    Date Created: 10/15/2019
    Twitter: @5ynax
    
    Last Modified By: 
    Last Modified Date: 
    Twitter: 
  
#>

[cmdletbinding(DefaultParameterSetName="Service")]

param (

    [Parameter(ParameterSetName = "Service", Position = 0, Mandatory = $true)]
    [String[]]$Service,

    [Parameter(ParameterSetName = "ServiceList", Position = 0, Mandatory = $true)]
    [String]$ServiceList,

    [Parameter(ParameterSetName = "Service",Position = 1,Mandatory = $true)]
    [Parameter(ParameterSetName = "ServiceList",Position = 1,Mandatory = $true)]
    [String]$ScopeName,

    [Parameter(ParameterSetName = "Service",Position = 2,Mandatory = $true)]
    [Parameter(ParameterSetName = "ServiceList",Position = 2,Mandatory = $true)]
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

    #Generate list based on parameter set
    switch ($PSCmdlet.ParameterSetName){

        "Service" {[String[]]$Services = $Service}
        "ServiceList"{[String[]]$Services = (Import-CSV -Path $ServiceList | Select-Object -ExpandProperty 'Service')}

    }

    foreach ($ServiceItem in $Services){
        
        $ScriptBlock = {
            
            # Determine if the IP address is found on system
            $ServiceEval = Get-CimInstance -ClassName win32_service -Filter "name LIKE '$Using:ServiceItem%'"

            # Determine if service is found on system
            $NameArray = ($ServiceEval.Name -Join "`n")
            $DNArray = ($ServiceEval.DisplayName -Join "`n")
            $PIDArray = ($ServiceEval.ProcessID -Join "`n")
            $PathArray = ($ServiceEval.PathName -Join "`n")
            $STArray = ($ServiceEval.ServiceType -Join "`n")
            $SMArray = ($ServiceEval.StartMode -Join "`n")
            $StatusArray = ($ServiceEval.Status -Join "`n")

            # return PSCustomObject for recording in CSV
            $OutHash =@{ Host = $env:COMPUTERNAME; Detected = [Boolean]$ServiceEval; Name = $NameArray; DisplayName = $DNArray; PID = $PIDArray; Path = $PathArray; ServiceType = $STArray; StartMode = $SMArray; Status = $StatusArray }
            return [PSCustomObject]$OutHash
        }
        
        #Generate output fules from scoping data collected
        $OutputPath = ('{0}\Scope_{1}_{2}.csv' -f $Output,$ServiceItem,$Seconds)
        Invoke-Command -Session $Session -ScriptBlock $ScriptBlock | Export-CSV -Path $OutputPath -Append -NoTypeInformation

    }   
}
