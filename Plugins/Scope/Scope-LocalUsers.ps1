<#

.SYNOPSIS
    Plugin-Name: Scope-LocalUsers.ps1
    
.Description
    Performs scoping based on a list of local user accounts provided via string array
    or CSV input file. The output will return True or False based on
    whether or not it was discovered on the system.

    Note: The CSV import file must have a column header of 'User'

.EXAMPLE
   
    Power-Response Execution

    Set ComputerName Test-PC
    Set User maliciouslocaluseraccount
    run
    
    OR

    Set ComputerName Test-PC
    Set FileList C:\Tools\Users.csv
    run

.NOTES
    Author: Drew Schmitt
    Date Created: 10/15/2019
    Twitter: @5ynax
    
    Last Modified By: 
    Last Modified Date: 
    Twitter: 
  
#>

[cmdletbinding(DefaultParameterSetName="User")]

param (

    [Parameter(ParameterSetName = "User", Position = 0, Mandatory = $true)]
    [String[]]$User,

    [Parameter(ParameterSetName = "UserList", Position = 0, Mandatory = $true)]
    [String]$UserList,

    [Parameter(ParameterSetName = "User",Position = 1,Mandatory = $true)]
    [Parameter(ParameterSetName = "UserList",Position = 1,Mandatory = $true)]
    [String]$ScopeName,

    [Parameter(ParameterSetName = "User",Position = 2,Mandatory = $true)]
    [Parameter(ParameterSetName = "UserList",Position = 2,Mandatory = $true)]
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

        "User" {[String[]]$Users = $User}
        "UserList"{[String[]]$Users = (Import-CSV -Path $UserList | Select-Object -ExpandProperty 'User')}

    }

    foreach ($UserItem in $Users){
        
        $ScriptBlock = {
            
            # Determine if the IP address is found on system
            $UserEval = Get-LocalUser -Name $Using:UserItem -ErrorAction SilentlyContinue

            # Determine if service is found on system
            $NameArray = ($UserEval.Name -Join "`n")
            $EnabledArray = ($UserEval.Enabled -Join "`n")
                    
            # return PSCustomObject for recording in CSV
            $OutHash =@{ Host = $env:COMPUTERNAME; Detected = [Boolean]$UserEval; Name = $NameArray; Enabled = $EnabledArray }
            
            return [PSCustomObject]$OutHash | Select Host, Detected, Name, Enabled
        }
        
        #Generate output fules from scoping data collected
        $OutputPath = ('{0}\Scope_{1}_{2}.csv' -f $Output,$UserItem,$Seconds)
        Invoke-Command -Session $Session -ScriptBlock $ScriptBlock | Export-CSV -Path $OutputPath -Append -NoTypeInformation

    }
}
