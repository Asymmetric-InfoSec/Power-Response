<#

.SYNOPSIS
    Plugin-Name: Import-Items.ps1
    
.Description

This plugin will allow the Power-Response user to import multiple hosts from a CSV or TXT
file for use with additional plugins. The Import-Items plugin stores all hosts
into a global level variable that will pass to future plugins via the global
level parameter set. 

.EXAMPLE

# Implicit ParameterName definition
Power-Response Usage
Set Path C:\Tools\Power-Response\Hosts.txt
Set Key ComputerName
Run

# Explicit ParameterName definition
Set Path C:\Tools\Power-Response\Hosts.txt
Set Key Host
Set ParameterName ComputerName
Run

.NOTES
    Author: 5yn@x
    Date Created: 11/21/2018
    Twitter: @5ynax
    
    Last Modified By: Valrkey
    Last Modified Date: 10/2/2019
    Twitter: @valrkey
  
#>

param (

    [Parameter(Mandatory=$true,Position=0)]
    [String]$Path,

    [Parameter(Mandatory=$true,Position=1)]
    [String]$Key,

    [Parameter(Position=2)]
    [String]$ParameterName = $Key,

    [System.Management.Automation.Runspaces.PSSession[]]$Session

)

process {
    # Import the data
    $Data = Import-Csv -Path $Path -ErrorAction 'SilentlyContinue'

    if ($Data.$Key) {
        # Set the ParameterName to Data.Key
        $global:PowerResponse.Parameters.$ParameterName = $Data.$Key
    } elseif ($Data) {
        # File exists, but Key is not a column
        Write-PRError -Message "CSV file $Path does not contain a key $Key"
    } else {
        # File does not exist
        Write-PRError -Message "File $Path does not exist"
    }
}
