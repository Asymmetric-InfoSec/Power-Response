<#

.SYNOPSIS
    Setup.ps1
    
.Description
	Setup Power-Response for first time use. This script will retrieve
	all Power-Response binary dependencies, rename them to the proper name
	for use with Power-Response. Additionally, the script will prepare the
	host for running Power-Response by unblocking all Power-Response related
	.ps1 files since they are not digitally signed. Power-Response shoud 
	be ready for use immediately after running this script.

.EXAMPLE
	Setup.ps1 
	*This will run in the initial mode and complete all Setup

.NOTES
    Author: Drew Schmitt
    Date Created: 4/22/2019
    Twitter: @5ynax
    
    Last Modified By: Drew Schmitt
    Last Modified Date: 9/30/2019
    Twitter: @5ynax
  
#>
[CmdletBinding()]

param (

	)

process{

    # $ErrorActionPreference of 'Stop' and $ProgressPreference of 'SilentlyContinue'
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'

    #Say Hello!
    Write-Host "Starting Setup"

    #Ensure that all files with alternate data streams are unblocked (for users that download a zip from the repo) to avoid PowerShell from not running Power-Response

    Get-ChildItem -Path $PSScriptRoot -Recurse *.ps1 | Unblock-File

    #Install the ImportExcel module from PSGallery
    $Excel_Test = Get-Module -ListAvailable -Name 'ImportExcel'
    if (!$Excel_Test) {

        Write-Host -Object "Installing 'ImportExcel' module"

        try {

            Install-Module -Force -Name "ImportExcel"

        } catch {

            Write-Warning -Message "Installing module in current user ($ENV:UserName) context. To install the module system-wide, run the 'Setup.ps1' script as admin"
            Install-Module -Force -Name "ImportExcel" -Scope "CurrentUser"

        }
    }

    #Verify that Bin exists and is ready for Setup process

    $Bin_Test = Test-Path "$PSScriptRoot\Bin"

    if ($Bin_Test) {

        Remove-Item -Force -Recurse -Path "$PSScriptRoot\Bin"
    }
    
    New-Item -Type Directory -Path "$PSScriptRoot\Bin" -Force | Out-Null

    #Verify that 7zip is installed and ready for use (needed for 7za standalone application)
    $7zip_Test = Test-Path "C:\Program Files\7-Zip"
    $7zaFlag = $false

    if (!$7zip_Test) {

        Write-Warning "7zip not detected locally, 7za will need to be manually unpacked." -ErrorAction SilentlyContinue
        #Set flag to true so that 7zip file is still moved to BIN for manual extraction
        $7zaFlag = $true
    }

    # Download Power-Response binary dependencies
    $Binary_Deps = @(

        @{

            Name = "Autorunsc" ; URL = 'https://download.sysinternals.com/files/Autoruns.zip'; Rename = ''; Type = 'zipped_sysinternals'

            },

         @{

            Name = "Sigcheck"; URL = 'https://download.sysinternals.com/files/Sigcheck.zip'; Rename = ''; Type = 'zipped_sysinternals' 

            },

        @{

            Name = "Handle"; URL = 'https://download.sysinternals.com/files/Handle.zip'; Rename = ''; Type = 'zipped_sysinternals'

            },

        @{

            Name = "Winpmem"; URL = 'https://github.com/Velocidex/c-aff4/releases/download/3.2/winpmem_3.2.exe'; Rename = 'winpmem.exe'; Type = 'binary'

            },

        @{

            Name = "7za"; URL = 'https://www.7-zip.org/a/7z1900-extra.7z'; Rename = ''; Type = '7za'

            },

        @{

            Name = "PECmd"; URL = 'https://f001.backblazeb2.com/file/EricZimmermanTools/PECmd.zip' ;Rename = ''; Type = 'zipped_zimmerman'

            },

        @{

            Name = "JLECmd"; URL = 'https://f001.backblazeb2.com/file/EricZimmermanTools/JLECmd.zip'; Rename = ''; Type = 'zipped_zimmerman'

            },

        @{

            Name = "LECmd"; URL = 'https://f001.backblazeb2.com/file/EricZimmermanTools/LECmd.zip'; Rename = ''; Type = 'zipped_zimmerman'

            },

        @{

            Name = "MFTECmd"; URL = 'https://f001.backblazeb2.com/file/EricZimmermanTools/MFTECmd.zip'; Rename = ''; Type = 'zipped_zimmerman'

            },

        @{

            Name = "AppCompatParser"; URL = 'https://f001.backblazeb2.com/file/EricZimmermanTools/AppCompatCacheParser.zip'; Rename = ''; Type = 'zipped_zimmerman'

            },

        @{

            Name = "AmcacheParser"; URL = 'https://f001.backblazeb2.com/file/EricZimmermanTools/AmcacheParser.zip'; Rename = ''; Type = 'zipped_zimmerman'

            },

        @{

            Name = "ShellBagsExplorer"; URL = 'https://f001.backblazeb2.com/file/EricZimmermanTools/ShellBagsExplorer.zip'; Rename = ''; Type = 'zipped_zimmerman_ShellBagsExplorer'

            },

        @{

            Name = "RBCmd"; URL = 'https://f001.backblazeb2.com/file/EricZimmermanTools/RBCmd.zip'; Rename = ''; Type = 'zipped_zimmerman'

            },

        @{

            Name = "RegistryExplorer"; URL = 'https://f001.backblazeb2.com/file/EricZimmermanTools/RegistryExplorer_RECmd.zip'; Rename = ''; Type = 'zipped_zimmerman_RegistryExplorer'

            },

        @{

            Name = "EvtxExplorer"; URL = 'https://f001.backblazeb2.com/file/EricZimmermanTools/EvtxExplorer.zip'; Rename = ''; Type = 'zipped_zimmerman'

            },

        @{

            Name = "FLS"; URL = 'https://github.com/sleuthkit/sleuthkit/releases/download/sleuthkit-4.6.6/sleuthkit-4.6.6-win32.zip'; Rename = 'fls'; Type = 'fls'

        },

        @{

            Name = "LogParser"; URL = 'https://download.microsoft.com/download/f/f/1/ff1819f9-f702-48a5-bbc7-c9656bc74de8/LogParser.msi'; Rename = ''; Type = 'logparser'
        }
    )

    #Introduction Message 

    Write-Host "Collecting Dependencies..."

    #Accept all TLS versions
    [System.Net.ServicePointManager]::SecurityProtocol = "Tls12","Tls11","Tls" 

    #Create netclient for use in config
    $Client = New-Object System.Net.WebClient 

    #Create staging location
    $Stage_Path = "$PSScriptRoot\Stage"
    New-Item -Type Directory -Path $Stage_Path | Out-Null

    #Loop through each hash table and process accordingly
    foreach ($Binary_Dep in $Binary_Deps) {

        #Process each type according to how they need to be handled
        switch ($Binary_Dep.Type) {

            zipped_sysinternals {

                try {

                    #Create the staging location
                    $Stage_Location = ("{0}\{1}.zip" -f $Stage_Path, $Binary_Dep.Name)
                    
                    #Download the zip
                    $Client.DownloadFile($Binary_Dep.URL,$Stage_Location)

                    #Extract the files
                    Expand-Archive -Path $Stage_Location -Destination $Stage_Path -Force

                    #Copy the files to the BIN folder
                    $Copy_Path = ("{0}/{1}*.exe" -f $Stage_Path, $Binary_Dep.Name)
                    $Final_Destination = "$PSScriptRoot\Bin"
                    Copy-Item -Path $Copy_Path -Destination $Final_Destination -Force

                } catch {

                    $Message = ("Setup of {0} failed. Download manually." -f $Binary_Dep.Name)
                    Write-Warning $Message -ErrorAction SilentlyContinue
                }    
            }

            binary {

                try {

                    #Dowload binary to the proper location
                    $Binary_Path = "$PSScriptRoot\Bin"
                    $Binary_Dest = "{0}\{1}.exe" -f $Binary_Path,$Binary_Dep.Name
                    $Client.DownloadFile($Binary_Dep.URL,$Binary_Dest)

                } catch {

                    $Message = ("Setup of {0} failed. Download manually." -f $Binary_Dep.Name)
                    Write-Warning $Message -ErrorAction SilentlyContinue
                }
            }

            7za{

                try {

                    #Create the staging location
                    $Stage_Location = ("{0}\{1}.7z" -f $Stage_Path, $Binary_Dep.Name)
                    
                    #Download the zip
                    $Client.DownloadFile($Binary_Dep.URL,$Stage_Location)

                    if ($7zaFlag) {

                        #Copy the .7z file to BIN for manual extraction later
                        Copy-Item -Path $Stage_Location -Destination "$PSScriptRoot\Bin\"

                    } else {

                        #Extract the files
                        $7zip_Path = 'C:\Program Files\7-zip\7z.exe'
                        $Command = (("& '{0}' x {1} -o{2}") -f ($7zip_Path, $Stage_Location,$Stage_Path))
                        Invoke-Expression -Command $Command | Out-Null

                        #Copy files to Bin
                        $7za64_Path = ("{0}\x64\7za.exe" -f $Stage_Path)
                        $7za32_Path = ("{0}\7za.exe" -f $Stage_Path)
                        
                        Copy-Item -Path $7za64_Path -Destination "$PSScriptRoot\Bin\7za_x64.exe" -Force
                        Copy-Item -Path $7za32_Path -Destination "$PSScriptRoot\Bin\7za_x86.exe" -Force

                    }

                } catch {

                    $Message = ("Setup of {0} failed. Download manually." -f $Binary_Dep.Name)
                    Write-Warning $Message -ErrorAction SilentlyContinue
                }
            }

            zipped_zimmerman{

                try{

                    #Create the staging location
                    $Stage_Location = ("{0}\{1}.zip" -f $Stage_Path, $Binary_Dep.Name)
                    
                    #Download the zip
                    $Client.DownloadFile($Binary_Dep.URL,$Stage_Location)

                    #Extract the files into their final resting place
                    $Expand_Path = ("{0}\Bin" -f $PSScriptRoot)
                    Expand-Archive -Path $Stage_Location -Destination $Expand_Path -Force

                } catch {

                    $Message = ("Setup of {0} failed. Download manually." -f $Binary_Dep.Name)
                    Write-Warning $Message -ErrorAction SilentlyContinue
                } 
            }

            zipped_zimmerman_ShellBagsExplorer{

                try{ 

                    #Create the staging location
                    $Stage_Location = ("{0}\{1}.zip" -f $Stage_Path, $Binary_Dep.Name)
                    
                    #Download the zip
                    $Client.DownloadFile($Binary_Dep.URL,$Stage_Location)

                    #Extract the files
                    Expand-Archive -Path $Stage_Location -Destination $Stage_Path -Force

                    #Copy files to their final resting place
                    $Shell_Path = ("{0}\{1}\SBECmd.exe" -f $Stage_Path, $Binary_Dep.Name)
                    $Final_Shell_Path = ("{0}\Bin" -f $PSScriptRoot)
                    Copy-Item -Path $Shell_Path -Destination $Final_Shell_Path -Force

                    } catch {

                        $Message = ("Setup of {0} failed. Download manually." -f $Binary_Dep.Name)
                        Write-Warning $Message -ErrorAction SilentlyContinue
                    }
            }

            zipped_zimmerman_RegistryExplorer{

                try{

                    #Create the staging location
                    $Stage_Location = ("{0}\{1}.zip" -f $Stage_Path, $Binary_Dep.Name)
                    
                    #Download the zip
                    $Client.DownloadFile($Binary_Dep.URL,$Stage_Location)

                    #Extract the files
                    $Expand_Path = ("{0}\Bin" -f $PSScriptRoot)
                    Expand-Archive -Path $Stage_Location -Destination $Expand_Path -Force

                    #Copy the files to their final resting place
                    $Batch_Path = "$PSScriptRoot\Bin\RegistryExplorer\BatchExamples\RECmd_Batch_MC.reb"
                    $Final_Batch_Path = "$PSScriptRoot\Bin\RegistryExplorer\RECmd_Batch_MC.reb"
                    Copy-Item -Path $Batch_Path -Destination $Final_Batch_Path -Force

                } catch {

                    $Message = ("Setup of {0} failed. Download manually." -f $Binary_Dep.Name)
                    Write-Warning $Message -ErrorAction SilentlyContinue
                }
            }

            fls{

                try{

                    #Create the staging location
                    $Stage_Location = ("{0}\{1}.zip" -f $Stage_Path, $Binary_Dep.Name)
                        
                    #Download the zip
                    $Client.DownloadFile($Binary_Dep.URL,$Stage_Location)

                    #Extract the files
                    $Expand_Stage = ("{0}\fls" -f $Stage_Path)
                    Expand-Archive -Path $Stage_Location -Destination $Expand_Stage -Force

                    #Copy relevant files to final location
                    $Expand_Path =  ("{0}\Bin\fls" -f $PSScriptRoot)
                    New-Item -Type Directory -Path $Expand_Path -Force | Out-Null
                    Copy-Item "$Expand_Stage\sleuthkit-*-win32\bin\fls.exe" -Destination $Expand_Path -Force
                    Copy-Item "$Expand_Stage\sleuthkit-*-win32\bin\libewf.dll" -Destination $Expand_Path -Force
                    Copy-Item "$Expand_Stage\sleuthkit-*-win32\bin\libvhdi.dll" -Destination $Expand_Path -Force
                    Copy-Item "$Expand_Stage\sleuthkit-*-win32\bin\libvmdk.dll" -Destination $Expand_Path -Force
                    Copy-Item "$Expand_Stage\sleuthkit-*-win32\bin\zlib.dll" -Destination $Expand_Path -Force
                    Copy-Item "$Expand_Stage\sleuthkit-*-win32\bin\msvcp140.dll" -Destination $Expand_Path -Force
                    Copy-Item "$Expand_Stage\sleuthkit-*-win32\bin\vcruntime140.dll" -Destination $Expand_Path -Force
                    Copy-Item "$Expand_Stage\sleuthkit-*-win32\bin\concrt140.dll" -Destination $Expand_Path -Force
                    Copy-Item "$Expand_Stage\sleuthkit-*-win32\bin\libtsk_jni.dll" -Destination $Expand_Path -Force
                    Copy-Item "$Expand_Stage\sleuthkit-*-win32\bin\ucrtbase.dll" -Destination $Expand_Path -Force
                    Copy-Item "$Expand_Stage\sleuthkit-*-win32\bin\vccorlib140.dll" -Destination $Expand_Path -Force

                } catch {

                    $Message = ("Setup of {0} failed. Download manually." -f $Binary_Dep.Name)
                    Write-Warning $Message -ErrorAction SilentlyContinue
                }  
            }

            logparser {

                #Verify if log parser is already installed
                $LogInstalled = Test-Path "C:\Program Files (x86)\Log Parser*"

                if (!$LogInstalled) {

                    try{

                        #Set the download location
                        $Stage_Location = ("{0}\LogParser.msi" -f $Stage_Path)
                        
                        #Download the msi
                        $Client.DownloadFile($Binary_Dep.URL,$Stage_Location)

                        #Install LogParser
                        $MsiPath = ("{0}" -f $Stage_Location)
                        $arguments = "/i `"$MsiPath`" /quiet"
                        Start-Process msiexec.exe -ArgumentList $arguments -Wait

                    }catch {

                        $Message = ("Setup of {0} failed. Download manually." -f $Binary_Dep.Name)
                        Write-Warning $Message -ErrorAction SilentlyContinue

                    }    
                }

                #Create LogParser directory in BIN
                $Expand_Path = ("{0}\Bin\LogParser" -f $PSScriptRoot)
                New-Item -Type Directory -Path $Expand_Path | Out-Null

                #Copy LogParser files to BIN for use in Power-Response
                Copy-Item -Path "C:\Program files (x86)\Log Parser*\LogParser.exe" -Destination $Expand_Path -Force
                Copy-Item -Path "C:\Program files (x86)\Log Parser*\LogParser.dll" -Destination $Expand_Path -Force
                Copy-Item -Path "C:\Program files (x86)\Log Parser*\COM\" -Destination $Expand_Path -Recurse -Force
            }
        }
    }
    
    #Remove staging location
    Remove-Item -Recurse -Path $Stage_Path -Force

    #Say Goodbye
    Write-Host "Setup Complete! Go forth and forensicate!"
}