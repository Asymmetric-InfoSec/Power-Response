<#

.SYNOPSIS
    Plugin-Name: Import-Computers.ps1
    
.Description

This plugin will allow the Power-Response user to import multiple hosts from a CSV or TXT
file for use with additional plugins. The Import-Computers plugin stores all hosts
into a global level variable that will pass to future plugins via the global
level parameter set. 

Note: The CSV and TXT file must be formatted with the first row (and first column)
being labeled as 'ComputerName'

When referencing the global variable in the Power-Response framework, you will need
to reference global:ComputerName as the value that will represent your imported 
hosts.

.EXAMPLE

Script Usage

Import-Hosts.ps1 -FilePath C:\Tools\Power-Response\Hosts.txt


.NOTES
    Author: 5yn@x
    Date Created: 11/21/2018
    Twitter: @5yn@x
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param (

    [Parameter(Mandatory=$true,Position=0)]
    [string]$FilePath

    )

process {

    $global:PowerResponse.Parameters.ComputerName = Import-CSV $FilePath | Select -ExpandProperty ComputerName

    }