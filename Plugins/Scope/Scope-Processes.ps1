<#

.SYNOPSIS
    Plugin-Name: Scope-Processes.ps1
    
.Description
    Performs scoping based on a list of processes provided via string array
    or CSV input file. The output will return True or False based on
    whether or not it was discovered on the system.

    Note: The CSV import file must have a column header of 'Process'

.EXAMPLE
   
    Power-Response Execution

    Set ComputerName Test-PC
    Set Process maliciousprocess
    run
    
    OR

    Set ComputerName Test-PC
    Set FileList C:\Tools\Processes.csv
    run

.NOTES
    Author: Drew Schmitt
    Date Created: 10/15/2019
    Twitter: @5ynax
    
    Last Modified By: 
    Last Modified Date: 
    Twitter: 
  
#>

[cmdletbinding(DefaultParameterSetName="Process")]

param (

    [Parameter(ParameterSetName = "Process",Position = 0,Mandatory = $true)]
    [String[]]$Process,

    [Parameter(ParameterSetName = "ProcessList",Position = 0,Mandatory = $true)]
    [String]$ProcessList,

    [Parameter(ParameterSetName = "Process",Position = 1,Mandatory = $true)]
    [Parameter(ParameterSetName = "ProcessList",Position = 1,Mandatory = $true)]
    [String]$ScopeName,

    [Parameter(ParameterSetName = "Process",Position = 2,Mandatory = $true)]
    [Parameter(ParameterSetName = "ProcessList",Position = 2,Mandatory = $true)]
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

    #Generate based on parameter set
    switch ($PSCmdlet.ParameterSetName){

        "Process" {[String[]]$Processes = $Process}
        "ProcessList"{[String[]]$Processes = (Import-CSV -Path $ProcessList | Select-Object -ExpandProperty 'Process')}

    }

    foreach ($ProcessItem in $Processes){

        $ScriptBlock = {

            # Determine if found on system
            $ProcessEval = Get-CimInstance -ClassName win32_process -Filter "name LIKE '$Using:ProcessItem%'"

            # Determine if found on system
            $NameArray = ($ProcessEval.Name -Join "`n")
            $EPArray = ($ProcessEval.ExecutablePath -Join "`n")
            $CMDLineArray = ($ProcessEval.Commandline -Join "`n")
            $PIDArray = ($ProcessEval.ProcessID -Join "`n")
            $PPIDArray = ($ProcessEval.ParentProcessID -Join "`n")

            # return PSCustomObject for recording in CSV
            $OutHash = @{ Host = $env:COMPUTERNAME; Detected = [Boolean]$ProcessEval; Name = $NameArray; ExecutablePath = $EPArray; Commandline = $CMDLineArray; PID = $PIDArray; ParentPID = $PPIDArray }
            return [PSCustomObject]$OutHash
        }

        #Generate output fules from scoping data collected
        $OutputPath = ('{0}\Scope_{1}_{2}.csv' -f $Output,$ProcessItem,$Seconds)
        Invoke-Command -Session $Session -ScriptBlock $ScriptBlock | Export-CSV -Path $OutputPath -Append -NoTypeInformation

    }   
}
