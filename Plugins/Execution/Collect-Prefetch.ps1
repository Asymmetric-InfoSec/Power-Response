<#

.SYNOPSIS
    Plugin-Name: Collect-Prefetch.ps1
    
.Description

    This plugin will retrieve prefetch files from a remote host and move them to a specified
    output directory based on the the output path provided from Power-Response. By default,
    this plugin will retrieve all prefetch files in the C:\Windows\Prefetch directory, 
    however, you can specify a specific prefetch file to retrieve using the -PrefetchName
    parameter.

.EXAMPLE

    Power-Response Execution

    Set ComputerName Test-PC
    Run

    OR

    Set ComputerName Test-PC
    Set PrefetchName 7ZFM.EXE-3129C294.pf
    Run

.NOTES
    Author: Drew
    Date Created: 2/2/2019
    Twitter: @5ynax
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param (

    [Parameter(Mandatory=$true,Position=0)]
    [System.Management.Automation.Runspaces.PSSession[]]$Session,

    [Parameter(Mandatory=$false,Position=1)]
    [string[]]$PrefetchName

    )

process{
    
    # Set $Output for where to store recovered prefetch files
    $Output= (Get-PROutputPath -ComputerName $Session.ComputerName -Directory 'Prefetch')

    # Create Subdirectory in $global:PowerResponse.OutputPath for storing prefetch
    If (-not (Test-Path $Output)) {
        New-Item -Type Directory -Path $Output | Out-Null
    }   

    #Scope $PrefetchName
    If (!$PrefetchName){

        #Get Prefetch File Names - get only files that have a .pf extension
        $PrefetchName = Invoke-Command -Session $Session -ScriptBlock {Get-ChildItem "C:\Windows\Prefetch" -Filter "*.pf"} 

    }

    #Collect Prefetch Files
    foreach ($File in $PrefetchName){

        #Get Prefetch File Attributes
        $CreationTime = Invoke-Command -Session $Session -ScriptBlock {(Get-Item C:\Windows\Prefetch\$($args[0])).CreationTime} -ArgumentList $File 

        #Copy specified prefetch file to $Output
        Copy-Item "C:\Windows\Prefetch\$File" -Destination "$Output\" -FromSession $Session -Force -ErrorAction SilentlyContinue

        #Set original creation time on copied prefetch file
        (Get-Item "$Output\$File").CreationTime = $CreationTime

    }   
}