<#

.SYNOPSIS
    Plugin-Name: Retrieve-FLSBody.ps1
    
.Description
    This plugin runs FLS on the remote host to create a body file
    for file system triage using mactime or something similar

    Dependencies:

    PowerShell remoting
    The Sleuth Kit

.EXAMPLE

    PowerResponse Execution
    Set ComputerName Test-PC
    Run

.NOTES
    Author: Drew Schmitt
    Date Created: 6/1/2019
    Twitter: @5ynax
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param (

    [Parameter(Mandatory=$true,Position=0)]
    [System.Management.Automation.Runspaces.PSSession]$Session,

    [Parameter(Mandatory=$false,Position=1)]
    [String] $SystemDrive="$env:SystemDrive"

    )

process{

    #Set $Output for where to store recovered files
    $Output= (Get-PRPath -ComputerName $Session.ComputerName -Directory ('FLSBody_{0:yyyyMMdd}' -f (Get-Date)))

    # Create Subdirectory in $global:PowerResponse.OutputPath for out
    If (!(Test-Path $Output)) {

        New-Item -Type Directory -Path $Output | Out-Null
    }   

    #Dependency locations
    $FLSExe = ("{0}\fls\fls.exe" -f (Get-PRPath -Bin))
    $Libewf = ("{0}\fls\libewf.dll" -f (Get-PRPath -Bin))
    $Libvhdi = ("{0}\fls\libvhdi.dll" -f (Get-PRPath -Bin))
    $Libvmdk = ("{0}\fls\libvmdk.dll" -f (Get-PRPath -Bin))
    $Zlib = ("{0}\fls\zlib.dll" -f (Get-PRPath -Bin))

    $Dependencies = $FLSExe,$Libewf,$Libvhdi,$Libvmdk,$Zlib

    #Verify binaries exist in Bin
    foreach ($Dependency in $Dependencies){

        try {

            Get-Item -Path $Dependency -ErrorAction Stop

        } catch {

            Throw "{0} not detected in Bin. Place The Sleuth Kit executables in Bin directory and try again." -f $Dependency
        }   
    }
    
    #Copy dependencies to remote host
    $LocalPath = ("{0}\fls" -f (Get-PRPath -Bin))
    $RemotePath = "C:\ProgramData"

    try {
        
        Copy-Item -Path $LocalPath -Destination $RemotePath -Recurse -ToSession $Session -ErrorAction Stop

    } catch {
        
        Throw ("An unexpected error occurred while copying FLS to {0}. Data was not gathered." -f $Session.ComputerName)
        
    }

    #Run on the remote host and collect data
    $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(("& '{0}\fls\fls.exe' -r -m '{1}' '\\.\{1}' | Out-File '{0}\FLSi.body'") -f ($RemotePath,$SystemDrive))
    
    Invoke-Command -Session $Session -ScriptBlock $ScriptBlock

    #Format the FLS body file so that it works with all operating systems and not just Windows because CRLF 

    $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(("Get-Content '{0}\FLSi.body' -raw | ForEach-Object {{`$_ -replace `"``r`", `"`"}} | Set-Content -NoNewLine '{0}\FLS.body'") -f ($RemotePath))
    
    Invoke-Command -Session $Session -ScriptBlock $ScriptBlock

    #Compress output before copying to analysis machine
    $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(("Compress-Archive -Path {0}\FLS.body -Destination {0}\FLS.zip -Force") -f ($RemotePath))

    Invoke-Command -Session $Session -ScriptBlock $ScriptBlock | Out-Null

    #Copy data to analysis system
    $DataPath = ("{0}\FLS.zip" -f $RemotePath)
    Copy-Item -Path $DataPath -Destination "$Output" -FromSession $Session -Force -ErrorAction SilentlyContinue

    #Cleanup artifacts on remote system
    $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(("Remove-Item -Recurse -Force {0}\fls, {0}\FLSi.body, {0}\FLS.body, {0}\FLS.zip") -f $RemotePath)

    Invoke-Command -Session $Session -ScriptBlock $ScriptBlock | Out-Null
}
