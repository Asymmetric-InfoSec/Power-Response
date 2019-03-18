<#

.SYNOPSIS
    Plugin-Name: Collect-Items.ps1
    
.Description
    Retrieves a list of items based on user specified item paths or a list stored on disk
    and specified as a list path that points to a CSV or TXT file that contains a list of 
    item paths. Items will be retrieved and stored on the local system in the 
    Power-Response output path. 

    Note: The CSV and TXT file must be formatted with the first row (and first column)
    being labeled as 'Path'

.EXAMPLE
    Stand Alone Execution

    .\Collect-Items.ps1 -ComputerName Test-PC -ItemPath C:\Power-Response\Power-Response.ps1

    OR

    .\Collect-Items.ps1 -ComputerName Test-PC -ListPath C:\Tools\ItemPaths.csv

    Power-Response Execution

    Set ComputerName Test-PC
    Set ItemPath C:\Power-Response\Power-Response.ps1
    run
    
    OR

    Set ComputerName Test-PC
    Set ListPath C:\Tools\ItemPaths.csv
    run

.NOTES
    Author: Drew Schmitt
    Date Created: 3/15/2019
    Twitter: @5ynax
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param (

    [Parameter(ParameterSetName = "Items", Position = 0, Mandatory = $true)]
    [Parameter(ParameterSetName = "List", Position = 0, Mandatory = $true)]
    [string[]]$ComputerName,

    [Parameter(ParameterSetName = "Items", Position = 1, Mandatory = $true)]
    [string[]]$ItemPath,

    [Parameter(ParameterSetName = "List", Position = 1, Mandatory = $true)]
    [string]$ListPath

    )

process{

    # Set $Output for where to store recovered prefetch files
    $Output= ("{0}\ItemCollection\" -f $global:PowerResponse.OutputPath)

    # Create Subdirectory in $global:PowerResponse.OutputPath for storing prefetch
    If (-not (Test-Path $Output)) {
        New-Item -Type Directory -Path $Output | Out-Null
    }

    switch ($PSCmdlet.ParameterSetName) {

        "Items" {[string[]]$Items = $ItemPath}
        "List" {[string[]]$Items = (Import-CSV $ListPath | Select -ExpandProperty "Path")}
    }

    Write-Host "The items are "$Items

    foreach ($Computer in $ComputerName) {

        # Create session on remote host (with no profile saved remotely)
        $Session = New-PSSession -ComputerName "$Computer" -SessionOption (New-PSSessionOption -NoMachineProfile)

        #Collect items
        foreach ($Item in $Items){

            Write-Host "The Item Is" $Item

            #Verify that file exists on remote system, if not skip and continue
            $PathVerify = Invoke-Command -Session $Session -ScriptBlock {Test-Path $($args[0])} -ArgumentList $Item

            if (!$PathVerify) {
               
                Write-Error "No item found at $Item. Skipping."
                continue
            }

            #Get Prefetch File Attributes
            $CreationTime = Invoke-Command -Session $Session -ScriptBlock {(Get-Item $($args[0])).CreationTime} -ArgumentList $Item 

            #Copy specified prefetch file to $Output
            Copy-Item $Item -Destination "$Output\" -FromSession $Session -Force -ErrorAction SilentlyContinue

            #Set original creation time on copied prefetch file
            (Get-Item ("{0}\{1}" -f $Output, (Split-Path $File -Leaf))).CreationTime = $CreationTime

        }

        #Close PS remoting session
        $Session | Remove-PSSession
    }
}