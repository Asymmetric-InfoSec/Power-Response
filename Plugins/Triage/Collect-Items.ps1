<#

.SYNOPSIS
    Plugin-Name: Collect-Items.ps1
    
.Description
    Retrieves a list of items based on user specified item paths or a list stored on disk
    and specified as a list path that points to a CSV or TXT file that contains a list of 
    item paths. Items will be retrieved, compressed into a zip archive, and stored on the local system in the 
    Power-Response output path. 

    The output is in ZIP format and has the files inside will have the password "infected"

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

    # Verify that 7za executables are located in $global:PowerResponse.Config.Path.Bin

    $7za32 = ("{0}\7za_x86.exe" -f $global:PowerResponse.Config.Path.Bin)
    $7za64 = ("{0}\7za_x64.exe" -f $global:PowerResponse.Config.Path.Bin)

    $7z64bitTestPath = Get-Item -Path $7za64 -ErrorAction SilentlyContinue
    $7z32bitTestPath = Get-Item -Path $7za32 -ErrorAction SilentlyContinue

    if (-not $7z64bitTestPath) {

        Throw "64 bit version of 7za.exe not detected in Bin. Place 64bit executable in Bin directory and try again."

    } elseif (-not $7z32bitTestPath) {

        Throw "32 bit version of 7za.exe not detected in Bin. Place 32bit executable in Bin directory and try again."
    }

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

    foreach ($Computer in $ComputerName) {

        # Create session on remote host (with no profile saved remotely)
        $Session = New-PSSession -ComputerName "$Computer" -SessionOption (New-PSSessionOption -NoMachineProfile)

        #Determine system architecture and select proper 7za.exe executable
        try {
         
            $Architecture = (Get-WmiObject -ComputerName $Computer -Class Win32_OperatingSystem -Property OSArchitecture -ErrorAction Stop).OSArchitecture
        
            if ($Architecture -eq "64-bit") {

                $Installexe = $7za64

            } elseif ($Architecture -eq "32-bit") {

                $Installexe = $7za32

            } else {
            
                Write-Error ("Unknown system architecture ({0}) detected for {1}. Data was not gathered.)" -f $Architecture, $Computer)
                Continue
            }

        } catch {
        
         Write-Error ("Unable to determine system architecture for {0}. Data was not gathered." -f $Computer)
            Continue
        }

        #Copy 7zip executable to the remote machine for user

        try {

            Copy-Item -Path $Installexe -Destination "C:\ProgramData" -ToSession $Session -Force -ErrorAction Stop

        } catch {

            Throw "Could not copy 7zip to remote machine. Quitting."
        }

        #Collect items
        foreach ($Item in $Items){

            #Verify that file exists on remote system, if not skip and continue
            $PathVerify = Invoke-Command -Session $Session -ScriptBlock {Test-Path $($args[0])} -ArgumentList $Item

            if (!$PathVerify) {
               
                Write-Error "No item found at $Item. Skipping." -ErrorAction Continue
                Continue
            }

            #Get Item Attributes, create metadata file, and compress files
            Invoke-Command -Session $Session -ScriptBlock {

                $MetaData = @{

                    Item = $($args[0])
                    CreationTimeUTC = (Get-Item $($args[0])).CreationTimeUtc
                    ModifiedTime = (Get-Item $($args[0])).LastWriteTimeUtc
                    AccessTime = (Get-Item $($args[0])).LastAccessTimeUtc
                } 

                $ExportPath = "C:\ProgramData\{0}_Metadata.csv" -f (Split-Path $($args[0]) -Leaf)

                [PSCustomObject]$MetaData | Export-CSV $ExportPath

                #Create archive of Item and MetaData

                $ArchivePath = "C:\ProgramData\{0}.zip" -f (Split-Path $($args[0]) -Leaf)
                $Command_Compress = "C:\ProgramData\{0} a -pinfected -tzip {1} {2} {3}" -f ($($args[1]), $ArchivePath, $ExportPath, ($($args[0])))

                Invoke-Expression -Command $Command_Compress | Out-Null

            } -ArgumentList $Item, (Split-Path $Installexe -Leaf)

            #Copy specified archive to $Output

            $ItemPath = "C:\ProgramData\{0}.zip" -f (Split-Path $Item -Leaf)

            Copy-Item -Path $ItemPath -Destination "$Output\" -FromSession $Session -Force -ErrorAction SilentlyContinue

            #Remove created files on remote machine as cleanup

            Invoke-Command -Session $Session -ScriptBlock {

                #Remove the archive

                Remove-Item -Path $ArchivePath -Force 
                    
                #Remove the Metadata file

                Remove-Item -Path $ExportPath -Force  

            } -ArgumentList (Split-Path $Installexe -Leaf)

        }

        #Remove 7zip

        Invoke-Command -Session $Session -ScriptBlock {Remove-Item -Path ("C:\ProgramData\{0}" -f ($($args[0])))} -Argumentlist (Split-Path $Installexe -Leaf)

        #Close PS remoting session
        $Session | Remove-PSSession
    }
}