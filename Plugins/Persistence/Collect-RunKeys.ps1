<#

.SYNOPSIS
    Plugin-Name: Collect-RunKeys.ps1
    
.Description
    Collects many well known run keys from the registry for all users on a machine.

.EXAMPLE
    Stand Alone Execution

    .\Collect-RunKeys.ps1 -ComputerName Test-PC

    Power-Response Execution

    set ComputerName Test-PC
    run

.NOTES
    Author: Drew Schmitt
    Date Created: 3/8/2019
    Twitter: @5ynax
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param (

    [Parameter(Mandatory=$true,Position=0)]
    [string[]]$ComputerName

    )

process {

    foreach ($Computer in $ComputerName){

        $Session = New-PSSession -ComputerName $Computer -SessionOption (New-PSSessionOption -NoMachineProfile)

        Invoke-Command -Session $Session -ScriptBlock {
            
            #Create PSDrive to be able to mount HKEY_USERS
            New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS | Out-Null

            #Create PSDrive to be able to mount HKEY_CLASSES_ROOT
            New-PSDrive -PSProvider Registry -Name HKR -Root HKEY_CLASSES_ROOT | Out-Null

            #Get list of SIDs from HKU for further processing
            $UserAccounts = (Get-ChildItem 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\ProfileList').Name
            
            foreach ($User in $UserAccounts){
                
                [string[]]$UserSIDs += $User.Split("\")[-1]

            }

            #Retrieve HKEY_USERS keys

            $HKUKeys = @(

                "Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders",
                "Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders",
                "Software\Microsoft\Windows\CurrentVersion\Run",
                "Software\Microsoft\Windows\CurrentVersion\RunOnce",
                "Software\Microsoft\Windows\CurrentVersion\RunServices"

                )

            #Loop through by SID and collect run keys

            foreach ($SID in $UserSids){

                foreach ($HKUKey in $HKUKeys){

                    $RoundKey = ("HKU:\{0}\{1}") -f $SID, $HKUKey
                    $Properties = Get-Item $RoundKey -ErrorAction SilentlyContinue | Select -ExpandProperty property 
                    foreach ($Property in $Properties){

                        try{

                            $OutHash = @{

                                Type = "HKEY_USERS"
                                User = $SID
                                Key = $HKUKey
                                Property = $Property
                                Value = (Get-Item $Roundkey).GetValue($Property)

                            }

                        }catch{

                            $OutHash = @{

                                Type = "HKEY_USERS"
                                User = $SID
                                Key = $HKUKey
                                Property = $Property
                                Value = "Null-Check Value Manually"

                            }

                        }

                        [PSCustomObject]$OutHash | Select Type, User, Key, Property, Value
                    }
                }
            }

            #Retrieve HKLM and HKR Key values

            $HKLMKeys = @(

                "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunServices",
                "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunServicesOnce",
                "HKLM:\\Software\Microsoft\Windows\CurrentVersion\Run",
                "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
                "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\Shell",
                "HKLM:\Software\Microsoft\Active Setup\Installed Components\KeyName",
                "HKLM:\Software\Microsoft\Windows\CurrentVersion\explorer\User Shell Folders",
                "HKLM:\Software\Microsoft\Windows\CurrentVersion\explorer\Shell Folders",
                "HKLM\SOFTWARE\WOW6432NODE\MICROSOFT\WINDOWS\CURRENTVERSION\RUNONCE",
                "HKLM\SOFTWARE\WOW6432NODE\MICROSOFT\WINDOWS\CURRENTVERSION\RUN"

                ) 

            foreach ($HKLMKey in $HKLMKeys){

                $Properties = Get-Item $HKLMKey -ErrorAction SilentlyContinue | Select -ExpandProperty property 

                foreach ($Property in $Properties){

                    try{
                        $OutHash = @{

                            Type = "HKEY_LOCAL_MACHINE"
                            User = ""
                            Key = $HKLMKey
                            Property = $Property
                            Value = (Get-Item $HKLMKey).GetValue($Property)

                        }

                    }catch{

                        $OutHash = @{

                            Type = "HKEY_LOCAL_MACHINE"
                            User = ""
                            Key = $HKLMKey
                            Property = $Property
                            Value = "NULL-Check Value Manually"

                        }

                    }

                    [PSCustomObject]$OutHash | Select Type, User, Key, Property, Value
                }

            }

            $ShellOpenKeys = @(

                "HKR:\exefile\shell\open\command",
                "HKR:\comfile\shell\open\command",
                "HKR:\batfile\shell\open\command",
                "HKR:\htafile\shell\open\command",
                "HKR:\piffile\shell\open\command",
                "HKLM:\Software\CLASSES\batfile\shell\open\command",
                "HKLM:\Software\CLASSES\comfile\shell\open\command",
                "HKLM:\Software\CLASSES\exefile\shell\open\command",
                "HKLM:\Software\CLASSES\htafile\shell\open\command",
                "HKLM:\Software\CLASSES\piffile\shell\open\command"
                
                )

            foreach ($ShellOpenKey in $ShellOpenKeys){

                $Properties = Get-Item $ShellOpenKey -ErrorAction SilentlyContinue | Select -ExpandProperty property 

                foreach ($Property in $Properties){

                    try {

                        $OutHash = @{

                            Type = "HKLM/HKCR SHELL OPEN KEYS"
                            User = ""
                            Key = $ShellOpenKey
                            Property = $Property
                            Value = (Get-Item $ShellOpenKey).GetValue("")

                            }

                    }catch{

                        $OutHash = @{

                            Type = "HKLM/HKCR SHELL OPEN KEYS"
                            User = ""
                            Key = $ShellOpenKey
                            Property = $Property
                            Value = (Get-Item $ShellOpenKey).GetValue($Property)

                            }
                    }

                    [PSCustomObject]$OutHash | Select Type, User, Key, Property, Value
                    
                }
            }
        }

        $Session | Remove-PSSession
    }
}
