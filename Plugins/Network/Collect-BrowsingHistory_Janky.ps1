<#

.SYNOPSIS
    Plugin-Name: Collect-BrowsingHistory_Janky.ps1
    
.Description

    ***USE THIS PLUGIN WITH CAUTION***
    This plugin does a crap job of retrieving the browsing history from Chrome and Firefox if these
    browsers are being used. The method of retrieving these files is extremely janky and should
    be used with caution. This plugin closes Chrome and Firefox, retrives the files, and then restarts
    the processes accordingly. Users *should* not lose any data. 

    Honestly, I wouldn't recommend running this unless absolutely necessary. Or you're a bit crazy.

.EXAMPLE

    Stand Alone Execution: 

    .\Collect-BrowsingHistory.ps1 -ComputerName Test-PC

    Note: This will create the output directory in C:\BrowsingHistory

    Power-Response Execution:

    Set ComputerName Test-PC
    Run

.NOTES
    Author: Drew Schmitt
    Date Created: 2/2/2019
    Twitter: @5ynax
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param (

    [Parameter(Mandatory=$true,Position=0)]
    [string[]]$ComputerName,
    [Parameter(Mandatory=$False,Position=1)]
    [string[]]$User="*"
    
    )

process{

    #Set $Output for where to store recovered browsing history
    $Output= ("{0}\BrowserHistory" -f $global:PowerResponse.OutputPath)

    # Create Subdirectory in $global:PowerResponse.OutputPath for storing browsing history
    If (-not (Test-Path $Output)) {
        New-Item -Type Directory -Path $Output | Out-Null
    }

    foreach ($Computer in $ComputerName) {

        # Create session on remote host
        $Session = New-PSSession -ComputerName "$Computer"

        # Get all user profiles on the PC if default, continue if not 
        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock("Get-ChildItem C:\Users")
        $UserProfiles = Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock 

        foreach ($UserProfile in $UserProfiles) {

            # Chrome Browsing History - Janky workaround for locked files

            $chrome = Get-Process chrome
            If ($chrome) {
                Stop-Process $chrome
                Copy-Item "C:\Users\$UserProfile\AppData\Local\Google\Chrome\User Data\Default\History" -Destination "$Output\${UserProfile}_History" -FromSession $Session -Force -ErrorAction SilentlyContinue
                Start-Process "C:\Program Files (x86)\Google\Chrome\Application\Chrome.exe" -ArgumentList '--start-maximized'

            } else {

                Copy-Item "C:\Users\$UserProfile\AppData\Local\Google\Chrome\User Data\Default\History" -Destination "$Output\${UserProfile}_History" -FromSession $Session -Force -ErrorAction SilentlyContinue
            }

            # Firefox Browsing History - Janky workaround for locked files

            $firefox = Get-Process *firefox*
            If ($firefox) {
                Stop-Process $firefox
                Copy-Item "C:\Users\$UserProfile\AppData\Roaming\Mozilla\Firefox\Profiles\*\places.sqlite" -Destination "$Output\${UserProfile}_places.sqlite" -FromSession $Session -Force -ErrorAction SilentlyContinue

                try {

                    Start-Process "C:\Program Files\Mozilla Firefox\firefox.exe"

                } catch {

                    Start-Process "C:\Program Files(x86)\Mozilla Firefox\firefox.exe"
                }

            } else {

            Copy-Item "C:\Users\$UserProfile\AppData\Roaming\Mozilla\Firefox\Profiles\*\places.sqlite" -Destination "$Output\${UserProfile}_places.sqlite" -FromSession $Session -Force -ErrorAction SilentlyContinue

            }
        }

        $Session | Remove-PSSession

    }

}

