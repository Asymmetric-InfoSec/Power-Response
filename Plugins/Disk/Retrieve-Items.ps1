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
    
    Last Modified By: Gavin Prentice
    Last Modified Date: 9/3/2019
    Twitter: @valrkey
  
#>
[CmdletBinding(DefaultParameterSetName='Items')]

param (

    [Parameter(Position=0,Mandatory=$true)]
    [System.Management.Automation.Runspaces.PSSession[]]$Session,

    [Parameter(Position=1,Mandatory=$true,ParameterSetName='Items')]
    [String[]]$ItemPath,

    [Parameter(Position=1,Mandatory=$true,ParameterSetName='List')]
    [String]$ListPath,

    [Parameter(Position=2)]
    [String]$EncryptPassword = 'infected',

    [Parameter(Position=3)]
    [Switch]$NoEncrypt
)

process {

    # Resolve parameter set differences
    switch ($PSCmdlet.ParameterSetName) {
        'Items' { [String[]]$Items = $ItemPath }
        'List' { [String[]]$Items = (Import-Csv -Path $ListPath | Select-Object -ExpandProperty 'Path') }
    }

    # Ensure we have something to grab
    if (!$Items) {
        throw ('Value for ItemPath not detected for {0}. Add item path and try again' -f $Session.ComputerName)
    }

    # Define stage directory
    $RemoteStageDirectory = 'C:\ProgramData\Power-Response\'

    # Define $7za tracking structure
    $7za = @{
        Path = @{
            '32-bit' = Join-Path -Path (Get-PRPath -Bin) -ChildPath '7za_x86.exe'
            '64-bit' = Join-Path -Path (Get-PRPath -Bin) -ChildPath '7za_x64.exe'
        }
    }

    # Test path for existing 7zip deploys
    $7zTestPath = Join-Path -Path $RemoteStageDirectory -ChildPath '7za*.exe'

    # Track Sessions where 7zip is already on remote machine
    $7za.Deploy = Invoke-Command -Session $Session -ScriptBlock { Test-Path -Path $($args[0]) } -ArgumentList $7zTestPath | Where-Object { !$PSItem } | Foreach-Object { Get-PSSession -InstanceId $PSItem.RunspaceId }

    foreach ($Instance in $7za.Deploy) {
        try {
            # Determine system $Architecture and select proper 7za.exe
            $Architecture = Invoke-Command -Session $Instance -ScriptBlock { if (!(Test-Path -Path $using:RemoteStageDirectory -PathType 'Container')) { $null = New-Item -Path $using:RemoteStageDirectory -ItemType 'Directory' }; Get-WmiObject -Class 'Win32_OperatingSystem' -Property 'OSArchitecture' -ErrorAction 'Stop' | Select-Object -ExpandProperty 'OSArchitecture' }
        } catch {
            # Unable to get $Architecture information
            Write-Warning ('Unable to determine system architecture for {0}. Data was not gathered.' -f $Instance.ComputerName)
            continue
        }

        # Ensure we are tracking a sensible $Architecture
        if ($7za.Path.Keys -NotContains $Architecture) {
            Write-Error ('Unknown system architecture ({0}) detected for {1}. Data was not gathered.)' -f $Architecture, $Instance.ComputerName)
            continue
        }

        # Verify the each $7za $Exe exists
        if (!(Test-Path -Path $7za.Path.$Architecture -PathType 'Leaf')) {
            throw ('{0} version of 7za.exe not detected in Bin. Place {0} executable in Bin directory and try again.' -f $Architecture)
        }

        # Compute the $Remote7za path
        $Remote7za = Join-Path -Path $RemoteStageDirectory -ChildPath (Split-Path -Leaf -Path $7za.Path.$Architecture)

        try {
            # Copy 7zip executable to the remote machine
            Copy-Item -Path $7za.Path.$Architecture -Destination $Remote7za -ToSession $Instance -Force -ErrorAction 'Stop'
        } catch {
            # Failed to copy 7zip
            throw 'Could not copy 7zip to remote machine. Quitting.'
        }
    }

    try {
        # Copy the files
        Copy-PRItem -Path $Items -Destination $RemoteStageDirectory -Session $Session
    } catch {
        # Caught an error
        Write-Error -Message "Copy-PRItem error: $PSItem" -ErrorAction 'Continue'
    }

    # Used for unique naming of zip archive
    $Seconds = (Get-Date -UFormat %s).Split('.')[0]

    # Remote archive path
    $Archive = '{0}\RetrievedItems_{1}.zip' -f $RemoteStageDirectory,$Seconds

    # Compress the non-exe files in the remote stage directory
    Invoke-Command -Session $Session -ScriptBlock {
        # Get actual 7zip path
        $7zipPath = Get-Item -Path $using:7zTestPath | Select-Object -First 1 -ExpandProperty 'FullName'

        # Get all non-exe paths in the remote stage directory
        $Path = Get-ChildItem -Force -Path $using:RemoteStageDirectory -Exclude '*.exe' | Select-Object -ExpandProperty 'FullName'

        # Create compression command
        $Command = "$7zipPath a -p$using:EncryptPassword -tzip $using:Archive {0}" -f ($Path -Join ' ')

        # Execute compression command
        $null = Invoke-Expression -Command $Command
    }

    foreach ($Instance in $Session) {
        # Set output for each specific instance of session
        $Output = Get-PRPath -ComputerName $Instance.ComputerName -Directory ('RetrievedItems_{0:yyyyMMdd}' -f (Get-Date))

        # Create directory if it doesn't exist
        if (!(Test-Path -Path $Output -PathType 'Container')) {
            $null = New-Item -ItemType 'Directory' -Path $Output
        }

        # Copy each item to 
        Copy-Item -Path $Archive -Destination $Output -FromSession $Instance
    }

    # Remove created files on remote machine as cleanup
    Invoke-Command -Session $Session -ScriptBlock {
        # Get all non-exe items in remote stage directory
        $Path = Get-ChildItem -Force -Path $using:RemoteStageDirectory -Exclude '*.exe' | Select-Object -ExpandProperty 'FullName'

        # Remove the archive
        Remove-Item -Force -Recurse -Path $Path 
    }

    # Remove 7zip if deployed by plugin
    if (!$7za.Deploy) {

        Invoke-Command -Session $7za.Deploy -ScriptBlock {
            # Get all elements in the Power-Response deploy directory
            $Path = Get-ChildItem -Force -Path (Split-Path -Parent -Path $7zipPath)


            # Remove entire parent directory if 7zip is only child
            if ($Path.Count -eq 1 -and $Path.FullName -eq $7zipPath) {
                Remove-Item -Recurse -Force -Path $Path
            } else {
                Remove-Item -Recurse -Force -Path $7zipPath
            }
        } -Argumentlist $7zTestPath
    }
}
