<#

.SYNOPSIS
    Plugin-Name: Collect-UserAssist.ps1
    
.Description
    Collects the User Assist data for all users for Executable and Shortcut executions

.EXAMPLE
    Stand Alone Execution

    .\Collect-UserAssist.ps1 -ComputerName Test-PC

    Power-Response Execution

    set ComputerName Test-PC
    run

.NOTES
    Author: Drew Schmitt
    Date Created: 3/7/2019
    Twitter: @5ynax
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param (

    )

process {

    #Create PSDrive to be able to mount HKU
    New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS | Out-Null
    
    #Well Known Folder GUIDs - For ease of analysis
    $FolderGuids = @{

        "DE61D971-5EBC-4F02-A3A9-6C82895E5C04" = "Get Programs (Virtual Folder)"
        "724EF170-A42D-4FEF-9F26-B60E846FBA4F" = "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Administrative Tools"
        "A520A1A4-1780-4FF6-BD18-167343C5AF16" = "%USERPROFILE%\AppData\LocalLow"
        "A305CE99-F527-492B-8B1A-7E76FA98D6E4" = "Installed Updates (Virtual Folder)"
        "9E52AB10-F80D-49DF-ACB8-4330F5687855" = "%LOCALAPPDATA%\Microsoft\Windows\Burn\Burn"
        "DF7266AC-9274-4867-8D55-3BD661DE872D" = "Programs and Features (Virtual Folder)"
        "D0384E7D-BAC3-4797-8F14-CBA229B392B5" = "%ALLUSERSPROFILE%\Microsoft\Windows\Start Menu\Programs\Administrative Tools"
        "C1BAE2D0-10DF-4334-BEDD-7AA20B227A9D" = "%ALLUSERSPROFILE%\OEM Links"
        "0139D44E-6AFE-49F2-8690-3DAFCAE6FFB8" = "%ALLUSERSPROFILE%\Microsoft\Windows\Start Menu\Programs"
        "A4115719-D62E-491D-AA7C-E74B8BE3B067" = "%ALLUSERSPROFILE%\Microsoft\Windows\Start Menu"
        "82A5EA35-D9CD-47C5-9629-E15D2F714E6E" = "%ALLUSERSPROFILE%\Microsoft\Windows\Start Menu\Programs\StartUp"
        "B94237E7-57AC-4347-9151-B08C6C32D1F7" = "%ALLUSERSPROFILE%\Microsoft\Windows\Templates"
        "0AC0837C-BBF8-452A-850D-79D08E667CA7" = "Computer (Virtual Folder)"
        "4BFEFB45-347D-4006-A5BE-AC0CB0567192" = "Conflicts (Virtual Folder)"
        "6F0CD92B-2E97-45D1-88FF-B0D186B8DEDD" = "Network Connections (Virtual Folder)"
        "56784854-C6CB-462B-8169-88E350ACB882" = "%USERPROFILE%\Contacts"
        "82A74AEB-AEB4-465C-A014-D097EE346D63" = "ControlPanel (Virtual Folder"
        "2B0F765D-C0E9-4171-908E-08A611B84FF6" = "%APPDATA%\Microsoft\Windows\Cookies"
        "B4BFCC3A-DB2C-424C-B029-7FE99A87C641" = "%USERPROFILE%\Desktop"
        "FDD39AD0-238F-46AF-ADB4-6C85480369C7" = "%USERPROFILE%\Documents"
        "374DE290-123F-4565-9164-39C4925E467B" = "%USERPROFILE%\Downloads"
        "1777F761-68AD-4D8A-87BD-30B759FA33DD" = "%USERPROFILE%\Favorites"
        "FD228CB7-AE11-4AE3-864C-16F3910AB8FE" = "%windir%\Fonts"
        "CAC52C1A-B53D-4EDC-92D7-6B2E8AC19434" = "Games (Virtual Folder"
        "054FAE61-4DD8-4787-80B6-090220C4B700" = "%LOCALAPPDATA%\Microsoft\Windows\GameExplorer"
        "D9DC8A3B-B784-432E-A781-5A1130A75963" = "%LOCALAPPDATA%\Microsoft\Windows\History"
        "4D9F7874-4E0C-4904-967B-40B0D20C3E4B" = "Internet (Virtual Folder)"
        "352481E8-33BE-4251-BA85-6007CAEDCF9D" = "%LOCALAPPDATA%\Microsoft\Windows\Temporary Internet Files"
        "BFB9D5E0-C6A9-404C-B2B2-AE6DB6AF4968" = "%USERPROFILE%\Links"
        "F1B32785-6FBA-4FCF-9D55-7B8E7F157091" = "%LOCALAPPDATA% (%USERPROFILE%\AppData\Local)"
        "2A00375E-224C-49DE-B8D1-440DF7EF3DDC" = "%windir%\resources\0409 (code page)"
        "4BD8D571-6D19-48D3-BE97-422220080E43" = "%USERPROFILE%\Music"
        "C5ABBF53-E17F-4121-8900-86626FC2C973" = "%APPDATA%\Microsoft\Windows\Network Shortcuts"
        "D20BEEC4-5CA8-4905-AE3B-BF251EA09B53" = "Network (Virtual Folder)"
        "2C36C0AA-5812-4B87-BFD0-4CD0DFB19B39" = "%LOCALAPPDATA%\Microsoft\Windows Photo Gallery\Original Images"
        "69D2CF90-FC33-4FB7-9A0C-EBB0F0FCB43C" = "%USERPROFILE%\Pictures\Slide Showss"
        "33E28130-4E1E-4676-835A-98395C3BC3BB" = "%USERPROFILE%\Pictures"
        "DE92C1C7-837F-4F69-A3BB-86E631204A23" = "%USERPROFILE%\Music\Playlists"
        "76FC4E2D-D6AD-4519-A663-37BD56068185" = "Printers (Virtual Folder)"
        "9274BD8D-CFD1-41C3-B35E-B13F55A758F4" = "%APPDATA%\Microsoft\Windows\Printer Shortcuts"
        "5E6C858F-0E22-4760-9AFE-EA3317B67173" = "%USERPROFILE% (%SystemDrive%\Users\%USERNAME%)"
        "62AB5D82-FDC1-4DC3-A9DD-070D1D495D97" = "%ALLUSERSPROFILE% (%ProgramData%, %SystemDrive%\ProgramData)"
        "905E63B6-C1BF-494E-B29C-65B732D3D21A" = "%ProgramFiles% (%SystemDrive%\Program Files)"
        "F7F1ED05-9F6D-47A2-AAAE-29D317C6F066" = "%ProgramFiles%\Common Files"
        "6365D5A7-0F0D-45E5-87F6-0DA56B6A4F7D" = "%ProgramFiles%\Common Files (x64)"
        "DE974D24-D9C6-4D3E-BF91-F4455120B917" = "%ProgramFiles%\Common Files (x86)"
        "6D809377-6AF0-444B-8957-A3773F02200E" = "%ProgramFiles% (%SystemDrive%\Program Files) (x64)"
        "7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E" = "%ProgramFiles% (%SystemDrive%\Program Files) (x86)"
        "A77F5D77-2E2B-44C3-A6A2-ABA601054A51" = "%APPDATA%\Microsoft\Windows\Start Menu\Programs"
        "DFDF76A2-C82A-4D63-906A-5644AC457385" = "%PUBLIC% (%SystemDrive%\Users\Public)"
        "C4AA340D-F20F-4863-AFEF-F87EF2E6BA25" = "%PUBLIC%\Desktop"
        "ED4824AF-DCE4-45A8-81E2-FC7965083634" = "%PUBLIC%\Documents"
        "3D644C9B-1FB8-4F30-9B45-F670235F79C0" = "%PUBLIC%\Downloads"
        "DEBF2536-E1A8-4C59-B6A2-414586476AEA" = "%ALLUSERSPROFILE%\Microsoft\Windows\GameExplorer"
        "3214FAB5-9757-4298-BB61-92A9DEAA44FF" = "%PUBLIC%\Music"
        "B6EBFB86-6907-413C-9AF7-4FC2ABF07CC5" = "%PUBLIC%\Pictures"
        "2400183A-6185-49FB-A2D8-4A392A602BA3" = "%PUBLIC%\Videos"
        "52A4F021-7B75-48A9-9F6B-4B87A210BC8F" = "%APPDATA%\Microsoft\Internet Explorer\Quick Launch"
        "AE50C081-EBD2-438A-8655-8A092E34987A" = "%APPDATA%\Microsoft\Windows\Recent"
        "BD85E001-112E-431E-983B-7B15AC09FFF1" = "RecordedTV"
        "B7534046-3ECB-4C18-BE4E-64CD4CB7D6AC" = "RecycleBin (Virtual Folder)"
        "8AD10C31-2ADB-4296-A8F7-E4701232C972" = "%windir%\Resources"
        "3EB685DB-65F9-4CF6-A03A-E3EF65729F3D" = "%APPDATA% (%USERPROFILE%\AppData\Roaming)"
        "B250C668-F57D-4EE1-A63C-290EE7D1AA1F" = "%PUBLIC%\Music\Sample Music"
        "C4900540-2379-4C75-844B-64E6FAF8716B" = "%PUBLIC%\Pictures\Sample Pictures"
        "15CA69B3-30EE-49C1-ACE1-6B5EC372AFB5" = "%PUBLIC%\Music\Sample Playlists"
        "859EAD94-2E85-48AD-A71A-0969CB56A6CD" = "%PUBLIC%\Videos\Sample Videos"
        "4C5C32FF-BB9D-43B0-B5B4-2D72E54EAAA4" = "%USERPROFILE%\Saved Games"
        "7D1D3A04-DEBB-4115-95CF-2F29DA2920DA" = "%USERPROFILE%\Searches"
        "EE32E446-31CA-4ABA-814F-A5EBD2FD6D5E" = "Offline Files (Virtual Folder)"
        "98EC0E18-2098-4D44-8644-66979315A281" = "Microsoft Office Outlook (Virtual Folder)"
        "190337D1-B8CA-4121-A639-6D472D16972A" = "Search Results (Virtual Folder)"
        "8983036C-27C0-404B-8F08-102D10DCFD74" = "%APPDATA%\Microsoft\Windows\SendTo"
        "7B396E54-9EC5-4300-BE0A-2482EBAE1A26" = "%ProgramFiles%\Windows Sidebar\Gadgets"
        "A75D362E-50FC-4FB7-AC2C-A8BEAA314493" = "%LOCALAPPDATA%\Microsoft\Windows Sidebar\Gadgets"
        "625B53C3-AB48-4EC1-BA1F-A1EF4146FC19" = "%APPDATA%\Microsoft\Windows\Start Menu"
        "B97D20BB-F46A-4C97-BA10-5E3608430854" = "%APPDATA%\Microsoft\Windows\Start Menu\Programs\StartUp"
        "43668BF8-C14E-49B2-97C9-747784D784B7" = "Sync Center (Virtual Folder)"
        "289A9A43-BE44-4057-A41B-587A76D7E7F9" = "Sync Results (Virtual Folder"
        "0F214138-B1D3-4A90-BBA9-27CBC0C5389A" = "Sync Setup (Virtual Folder"
        "1AC14E77-02E7-4E5D-B744-2EB1AE5198B7" = "%windir%\system32"
        "D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27" = "%windir%\system32 (x86)"
        "A63293E8-664E-48DB-A079-DF759E0509F7" = "%APPDATA%\Microsoft\Windows\Templates"
        "5B3749AD-B49F-49C1-83EB-15370FBD4882" = "TreeProperties"
        "0762D272-C50A-4BB0-A382-697DCD729B80" = "%SystemDrive%\Users"
        "F3CE0F7C-4901-4ACC-8648-D5D44B04EF8F" = "UsersFiles (Virtual Folder)"
        "18989B1D-99B5-455B-841C-AB7C74E4DDFC" = "%USERPROFILE%\Videos"
        "F38BF404-1D43-42F2-9305-67DE0B28FC23" = "%windir%"

    }

    # Rot-13 function to decrypt user assist keys that are encrypted with ROT-13. Note: Stores decrypted value in $DecryptedString.
    function ROT-13 {

        param (

            [String]$RotText

            )

        process {

            $RotText.ToCharArray() | ForEach-Object {
                if((([int] $_ -ge 97) -and ([int] $_ -le 109)) -or (([int] $_ -ge 65) -and ([int] $_ -le 77))){
                    
                    $DecryptedString += [char] ([int] $_ + 13);

                }elseif((([int] $_ -ge 110) -and ([int] $_ -le 122)) -or (([int] $_ -ge 78) -and ([int] $_ -le 90))){
                    
                    $DecryptedString += [char] ([int] $_ - 13);
                }else{

                    $DecryptedString += $_
                   
                }
            }

            return $DecryptedString
        }
    }
          
    #Get list of SIDs from HKU for further processing
    $UserAccounts = (Get-ChildItem 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\ProfileList').Name

    Foreach ($User in $UserAccounts){
        
        [string[]]$UserSIDs += $User.Split("\")[-1]

    }

    # Loop through by SID and collect User Assist Details

    foreach ($SID in $UserSIDs) {

        # Get User Assist Values for CEBFF5CD - executable file execution
        $EFE = Get-Item "HKU:\$SID\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist\{CEBFF5CD*\Count" -ErrorAction SilentlyContinue | Select -ExpandProperty Property 

        foreach ($Value in $EFE) {

            $GUID = Rot-13 -RotText ($Value.Split("\")[0].Trim('{}'))
            $ROTValue = ROT-13 -RotText $Value
            $EFEHash =@{ Type = 'Executable File Execution'; SID = $SID; UserAssist = $ROTValue ; GUID = $FolderGuids.Item($GUID)}
            [PSCustomObject]$EFEHash | Select Type, SID, UserAssist, GUID

        }

        # Get User Assist Values for F4E57C4B - shortcut file execution
        $SFE = Get-Item "HKU:\$SID\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist\{F4E57C4B*\Count" -ErrorAction SilentlyContinue | Select -ExpandProperty Property 

        foreach ($Value in $SFE) {

            $GUID = Rot-13 -RotText ($Value.Split("\")[0].Trim('{}'))
            $ROTValue = ROT-13 -RotText $Value
            $EFEHash =@{ Type = 'Shortcut File Execution'; SID = $SID; UserAssist = $ROTValue ; GUID = $FolderGuids.Item($GUID)}
            [PSCustomObject]$EFEHash | Select Type, SID, UserAssist, GUID

        }                
    } 
}