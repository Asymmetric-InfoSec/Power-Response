<#

.SYNOPSIS
    Plugin-Name: Retrieve-Items.ps1
    
.Description
    Retrieves a list of items based on user specified item paths or a list stored on disk
    and specified as a list path that points to a CSV or TXT file that contains a list of 
    item paths. Items will be retrieved, compressed into a zip archive, and stored on the local system in the 
    Power-Response output path. This plugin will handle locked files with the help of velociraptor.

    The output is in ZIP format and has the files inside will have the password "infected"

    Note: The CSV and TXT file must be formatted with the first row (and first column)
    being labeled as 'Path'

.EXAMPLE
   
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
    [System.Management.Automation.Runspaces.PSSession]$Session,

    [Parameter(ParameterSetName = "Items", Position = 1, Mandatory = $true)]
    [string[]]$ItemPath,

    [Parameter(ParameterSetName = "List", Position = 1, Mandatory = $true)]
    [string]$ListPath

    )

process{

    # Verify that 7za executables are located in (Get-PRPath -Bin)

    $7za32 = ("{0}\7za_x86.exe" -f (Get-PRPath -Bin))
    $7za64 = ("{0}\7za_x64.exe" -f (Get-PRPath -Bin))

    $7z64bitTestPath = Get-Item -Path $7za64 -ErrorAction SilentlyContinue
    $7z32bitTestPath = Get-Item -Path $7za32 -ErrorAction SilentlyContinue

    if (!$7z64bitTestPath) {

        Throw "64 bit version of 7za.exe not detected in Bin. Place 64bit executable in Bin directory and try again."

    } elseif (!$7z32bitTestPath) {

        Throw "32 bit version of 7za.exe not detected in Bin. Place 32bit executable in Bin directory and try again."
    }

    #Verify that Velociraptor executables are located in (Get-PRPath -Bin) (For locked files)

    $Velo_64 = ("{0}\Velociraptor-amd64.exe" -f (Get-PRPath -Bin))
    $Velo_32 = ("{0}\Velociraptor-386.exe" -f (Get-PRPath -Bin))

    $Velo_64TestPath = Get-Item -Path $Velo_64 -ErrorAction SilentlyContinue
    $Velo_32TestPath = Get-Item -Path $Velo_32 -ErrorAction SilentlyContinue

    if (!$Velo_64TestPath) {

        Throw "64 bit version of Velociraptor not detected in Bin. Place 64bit executable in Bin directory and try again."

    } elseif (!$Velo_32TestPath) {

        Throw "32 bit version of Velociraptor not detected in Bin. Place 32bit executable in Bin directory and try again."
    }

    # Set $Output for where to store recovered prefetch files
    $Output= (Get-PRPath -ComputerName $Session.ComputerName -Directory 'CollectedItems')

    # Create Subdirectory in $global:PowerResponse.OutputPath for storing items
    If (!(Test-Path $Output)) {

        New-Item -Type Directory -Path $Output | Out-Null
    }

    switch ($PSCmdlet.ParameterSetName) {

        "Items" {[string[]]$Items = $ItemPath}
        "List" {[string[]]$Items = (Import-CSV $ListPath | Select -ExpandProperty "Path")}
    }

    #Determine system architecture and select proper 7za.exe and Velociraptor executables
    try {
     
        $Architecture = Invoke-Command -Session $Session -ScriptBlock {(Get-WmiObject -Class Win32_OperatingSystem -Property OSArchitecture -ErrorAction Stop).OSArchitecture}
    
        if ($Architecture -eq "64-bit") {

            $Installexe = $7za64
            $Velo_exe = $Velo_64

        } elseif ($Architecture -eq "32-bit") {

            $Installexe = $7za32
            $Velo_exe = $Velo_32

        } else {
        
            Write-Error ("Unknown system architecture ({0}) detected for {1}. Data was not gathered.)" -f $Architecture, $Session.ComputerName)
            Continue
        }

    } catch {
    
     Write-Error ("Unable to determine system architecture for {0}. Data was not gathered." -f $Session.ComputerName)
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
        $PathVerify = Invoke-Command -Session $Session -ScriptBlock {Get-Item $($args[0]) -ErrorAction SilentlyContinue} -ArgumentList $Item 

        if (!$PathVerify) {
           
            Write-Error "No item found at $Item. Skipping." -ErrorAction Continue
            Continue
        }

        if (!$PathVerify.PSIsContainer){

            #Get Item Attributes, create metadata file, and compress files
            Invoke-Command -Session $Session -ScriptBlock {

                try {
                    
                    $MD5_Hash = (Get-FileHash -Path $($args[0]) -Algorithm MD5 -ErrorAction Stop).Hash

                } catch {
                                        
                    $MD5_Hash = "Could not obtain MD5 hash. File was likely locked."
                }

                $MetaData = @{

                    Item = $($args[0])
                    CreationTimeUTC = (Get-Item $($args[0])).CreationTimeUtc
                    ModifiedTimeUTC = (Get-Item $($args[0])).LastWriteTimeUtc
                    AccessTimeUTC = (Get-Item $($args[0])).LastAccessTimeUtc
                    MD5 = $MD5_Hash
                } 

                $ExportPath = "C:\ProgramData\{0}_Metadata.csv" -f (Split-Path $($args[0]) -Leaf)

                [PSCustomObject]$MetaData | Select Item, CreationTimeUTC, ModifiedTimeUTC, AccessTimeUTC, MD5 | Export-CSV $ExportPath

                try {
                    
                    $FileStream = [System.IO.File]::Open($Item,'Open','Write')
                    $FileStream.Close()
                    $FileStream.Dispose()
                    $IsLocked = $false

                } catch {
                    
                    $IsLocked = $true
                }
            
            } -ArgumentList $Item
        }

        if ($PathVerify.PSIsContainer){

            Invoke-Command -Session $Session -ScriptBlock {

                $DirItems = Get-ChildItem -Path $($args[0]) -File -Recurse | Select -ExpandProperty FullName

                foreach ($DirItem in $DirItems){

                    try{

                        $MD5_Hash = (Get-FileHash -Path $DirItem -Algorithm MD5 -ErrorAction Stop).Hash

                    } catch {

                        $MD5_Hash = "Could not obtain MD5 hash. File was likely locked."
                    }

                    $MetaData = @{

                        Item = $DirItem
                        Directory = (Get-Item $DirItem).Directory
                        CreationTimeUTC = (Get-Item $DirItem).CreationTimeUtc
                        ModifiedTimeUTC = (Get-Item $DirItem).LastWriteTimeUtc
                        AccessTimeUTC = (Get-Item $DirItem).LastAccessTimeUtc
                        MD5 = $MD5_Hash
                    } 

                    $ExportPath = "C:\ProgramData\{0}_Metadata.csv" -f (Split-Path $($args[0]) -Leaf)

                    [PSCustomObject]$MetaData | Select Item, Directory, CreationTimeUTC, ModifiedTimeUTC, AccessTimeUTC, MD5 | Export-CSV $ExportPath -Append

                }

                foreach ($DirItem in $DirItems){

                    try {

                        $FileStream = [System.IO.File]::Open($DirItem,'Open','Write')
                        $FileStream.Close()
                        $FileStream.Dispose()
                        $IsLocked = $false

                    } catch {

                        $IsLocked = $true
                        Break
                    }
                }

            } -ArgumentList $Item
        } 

        $Locked = Invoke-Command -Session $Session -ScriptBlock {$IsLocked}
        #Process the $item based on IsLocked value

        if (!$Locked){

            Invoke-Command -Session $Session -ScriptBlock {

            #Create archive of Item and MetaData (separately)
            $ArchivePath = "C:\ProgramData\{0}.zip" -f (Split-Path $($args[1]) -Leaf)
            $Command_Compress = "C:\ProgramData\{0} a -pinfected -tzip {1} {2} {3}" -f ($($args[0]), $ArchivePath, $ExportPath, ($($args[1])))

            Invoke-Expression -Command $Command_Compress | Out-Null

            } -ArgumentList (Split-Path $Installexe -Leaf), $Item

            #Copy specified archive to $Output
            $ItemPath = "C:\ProgramData\{0}.zip" -f (Split-Path $Item -Leaf)

            Copy-Item -Path $ItemPath -Destination "$Output\" -FromSession $Session -Force -ErrorAction SilentlyContinue

            #Remove created files on remote machine as cleanup

            Invoke-Command -Session $Session -ScriptBlock {

                #Remove the archive

                Remove-Item -Path $ArchivePath -Force 
                    
                #Remove the Metadata file

                Remove-Item -Path $ExportPath -Force  

            }
        }

        if ($Locked){

            #Deploy Velociraptor

            $Test_Velo = Invoke-Command -Session $Session -ScriptBlock {Get-Item ("C:\ProgramData\{0}" -f $($args[0])) -ErrorAction SilentlyContinue} -ArgumentList (Split-Path $Velo_exe -Leaf)

            if (!$Test_Velo){

                try{

                    Copy-Item -Path $Velo_exe -Destination "C:\ProgramData" -ToSession $Session -ErrorAction Stop 

                }catch {

                    Throw ("Locked file detected at {0}, but could not deploy Velociraptor for retrieval. Quitting..." -f $Item)
                }

            }

            #Copy $Item with Velociraptor, compress, and copy back to origin machine

            #Collect $Item
            $FinalPath = "C:\ProgramData\{1}_{0}" -f $Session.ComputerName, (Split-Path $Item -Leaf)

            Invoke-Command -Session $Session -ScriptBlock {New-Item -Type Directory -Path $($args[0])} -Argumentlist $FinalPath | Out-Null

            $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(('& {0}\{1} fs --accessor ntfs cp \\.\{2} {3}') -f ($env:ProgramData, (Split-Path -Path $Velo_exe -Leaf), $Item, $FinalPath))
            Invoke-Command -Session $Session -ScriptBlock $ScriptBlock -ErrorAction SilentlyContinue | Out-Null
           
            #Compress    
            Invoke-Command -Session $Session -ScriptBlock {

                #Create archive of Item and MetaData (separately)
                $ArchivePath = ("C:\ProgramData\{0}.zip" -f (Split-Path $($args[1]) -Leaf))
                
                $Command_Compress = ("C:\ProgramData\{0} a -pinfected -tzip {1} {2} {3}" -f ($($args[0]), $ArchivePath, $ExportPath, ($($args[1]))))
                
                Invoke-Expression -Command $Command_Compress | Out-Null

            } -ArgumentList (Split-Path $Installexe -Leaf), $FinalPath
            
            #Copy $Item
            
            Copy-Item -Path ("C:\ProgramData\{0}.zip" -f (Split-Path $FinalPath -Leaf)) -Destination $Output -FromSession $Session
            
            #Remove created files on remote machine as cleanup
            
            Invoke-Command -Session $Session -ScriptBlock {

                #Remove the archive

                Remove-Item -Path $ArchivePath -Force 
                    
                #Remove the Metadata file

                Remove-Item -Path $ExportPath -Force  

                #Remove the Velociraptor archive 

                Remove-Item -Recurse -Path ("{0}" -f $($args[0])) -Force

            } -ArgumentList $FinalPath

        }
         
    }

    #Remove 7zip, Velociraptor

    Invoke-Command -Session $Session -ScriptBlock {Remove-Item -Path ("C:\ProgramData\{0}" -f ($($args[0]))) -Force} -Argumentlist (Split-Path $Installexe -Leaf)

    if ($Locked){

        Invoke-Command -Session $Session -ScriptBlock {Remove-Item -Path ("C:\ProgramData\{0}" -f ($($args[0]))) -Force} -Argumentlist (Split-Path $Velo_exe -Leaf)
    }

}