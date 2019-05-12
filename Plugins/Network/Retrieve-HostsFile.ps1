<#

.SYNOPSIS
    Plugin-Name: Retrieve-HostsFile.ps1
    
.Description
	Retrieves the hosts file on all remote machines.

.EXAMPLE

	Power-Response Execution

	set computername TestPC
	run

.NOTES
    Author: Drew Schmitt
    Date Created: 5/10/2019
    Twitter: @5ynax 
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param(

    [Parameter(Mandatory=$true,Position=0)]
    [System.Management.Automation.Runspaces.PSSession]$Session

)

process {

	# Set $Output for where to store recovered prefetch files
    $Output= (Get-PRPath -ComputerName $Session.ComputerName -Directory ('HostsFile_{0:yyyyMMdd}' -f (Get-Date)))

    # Create Subdirectory in $global:PowerResponse.OutputPath for storing prefetch
    If (-not (Test-Path $Output)) {
        
        New-Item -Type Directory -Path $Output | Out-Null
    } 

    #Get Prefetch File Attributes
    $CreationTime = Invoke-Command -Session $Session -ScriptBlock {(Get-Item "C:\Windows\System32\drivers\etc\hosts").CreationTime} -ArgumentList $File 

    #Copy specified prefetch file to $Output
    Copy-Item "C:\Windows\System32\drivers\etc\hosts" -Destination "$Output\" -FromSession $Session -Force -ErrorAction SilentlyContinue

    #Set original creation time on copied prefetch file
    (Get-Item "$Output\$File").CreationTime = $CreationTime

}