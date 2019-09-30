<#

.SYNOPSIS
    Plugin-Name: Retrieve-ShimCache.ps1
    
.Description
    This plugin retrives system and user registry hives from a remote machine and 
    copies them back to the analysis machine for further review. Note, this plugin
    copies all forensically relevant registry hives if they have not been previously collected.
    This prevents hives from being manually retrieved multiple times for different
    plugins.

    Collected registry hives:

    %SYSTEMROOT%\System32\config\SAM
    %SYSTEMROOT%\System32\config\SAM.LOG1
    %SYSTEMROOT%\System32\config\SAM.LOG2
    %SYSTEMROOT%\System32\config\SYSTEM
    %SYSTEMROOT%\System32\config\SYSTEM.LOG1
    %SYSTEMROOT%\System32\config\SYSTEM.LOG2
    %SYSTEMROOT%\System32\config\SOFTWARE
    %SYSTEMROOT%\System32\config\SOFTWARE.LOG1
    %SYSTEMROOT%\System32\config\SOFTWARE.LOG2
    %SYSTEMROOT%\System32\config\SECURITY
    %SYSTEMROOT%\System32\config\SECURITY.LOG1
    %SYSTEMROOT%\System32\config\SECURITY.LOG2
    %SYSTEMROOT%\System32\config\RegBack\*

    %UserProfile%\NTUSER.DAT
    %UserProfile%\NTUSER.DAT.LOG1
    %UserProfile%\NTUSER.DAT.LOG2
    %UserProfile%\AppData\Local\Microsoft\Windows\UsrClass.dat
    %UserProfile%\AppData\Local\Microsoft\Windows\UsrClass.dat.LOG1
    %UserProfile%\AppData\Local\Microsoft\Windows\UsrClass.dat.LOG2

    Shimcache Plugin Specific Notes:  
    1) The system registry hive is retrieved for further analysis (Eric Zimmerman's AppCompatParser)
    2) The Shimcache is exported to a .reg file for further analysis (Mandiant's shimcacheparser.py)

.EXAMPLE

    Power-Response Execution

    Set ComputerName Test-PC
    Run

.NOTES
    Author: Drew Schmitt
    Date Created: 4/5/2019
    Twitter: @5ynax
    
    Last Modified By: Drew Schmitt
    Last Modified Date: 09/28/2019
    Twitter: @5ynax
  
#>

param (

    [Parameter(Mandatory=$true,Position=0)]
    [System.Management.Automation.Runspaces.PSSession]$Session

    )

process{

     #7zip checks
    $7zTestPath = "C:\ProgramData\7za*.exe"
    $7zFlag = Invoke-Command -Session $Session -ScriptBlock {Test-Path $($args[0])} -ArgumentList $7zTestPath

    #7zip BIN locations
    $7za32 = ("{0}\7za_x86.exe" -f (Get-PRPath -Bin))
    $7za64 = ("{0}\7za_x64.exe" -f (Get-PRPath -Bin))

    if (!$7zFlag){

        # Verify that 7za executables are located in (Get-PRPath -Bin)

        $7z64bitTestPath = Get-Item -Path $7za64 -ErrorAction SilentlyContinue
        $7z32bitTestPath = Get-Item -Path $7za32 -ErrorAction SilentlyContinue

        if (!$7z64bitTestPath) {

            Throw "64 bit version of 7za.exe not detected in Bin. Place 64bit executable in Bin directory and try again."

        } elseif (!$7z32bitTestPath) {

            Throw "32 bit version of 7za.exe not detected in Bin. Place 32bit executable in Bin directory and try again."
        }
    }

    #Determine if registry hives were already collected, if not, collect all of them

    $FinalOutputPath = (Get-PRPath -ComputerName $Session.ComputerName -Plugin 'Retrieve-RegistryHives.ps1' -Directory (('RegistryHives_{0:yyyyMMdd}' -f (Get-Date))))

    if (!(Test-Path $FinalOutputPath)) {

        Invoke-PRPlugin -Name Retrieve-RegistryHives.ps1 -Session $Session

    }

    # Set $Output for where to store recovered artifacts
    $ShimOutput= (Get-PRPath -ComputerName $Session.ComputerName -Directory ('ShimCache_{0:yyyyMMdd}' -f (Get-Date)))

    if (!(Test-Path $ShimOutput)){

        New-Item -Type Directory -Path $ShimOutput -Force | Out-Null
    }

    # Export shimcache into .reg file
    try{

        Invoke-Command -Session $Session -ScriptBlock {reg export 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\AppCompatCache' ('C:\ProgramData\{0}\Shimcache.reg' -f ($Using:Session.ComputerName))} | Out-Null

    } catch {

        Write-Warning ("There was a problem exporting stand alone Shimcache reg key or value on {0)" -f $Session.ComputerName)
    }

    #Copy .reg file back to output directory on local machine
    try {

        Copy-Item -Path ('C:\ProgramData\{0}\Shimcache.reg' -f ($Using:Session.ComputerName)) -Destination $ShimOutput -FromSession $Session -Force

    } catch {

        Write-Warning ("There was a problem copying Shimcache reg export on {0}" -f $Session.ComputerName)
    }

    #Remove .reg from remote machine
    try {

        Invoke-Command -Session $Session -ScriptBlock {Remove-Item ('C:\ProgramData\{0}\Shimcache.reg' -f ($Using:Session.ComputerName)) -Force}

    } catch {

        Write-Warning ("Could not delete .reg file on {0}, manual removal is needed." -f $Session.ComputerName)
    }
}