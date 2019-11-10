<#

.SYNOPSIS
    Plugin-Name: Retrieve-ChromeExtensions.ps1
    
.Description
    Retrieves the Chrome (and Chromium) extensions listing and translates the extensions to their common name.

.EXAMPLE

    Power-Response Execution

    set ComputerName Test-PC
    run

.NOTES
    Author: Gavin Prentice
    Date Created: 10/25/2019
    Twitter: @Valrkey
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param (
    [Parameter(Mandatory=$true,Position=0)]
    [System.Management.Automation.Runspaces.PSSession[]]$Session
)

begin {
    function Resolve-ChromeExtension {
        param (
            [Parameter(ValueFromPipeline=$true)]
            [String]$ExtensionID
        )

        process {
            $Response = @{}
            try {
                $Response = Invoke-WebRequest -Uri "https://chrome.google.com/webstore/detail/$ExtensionID"
            } catch [System.Net.WebException] {
                Write-Verbose -Message "ExtensionID: $ExtensionID is unknown"
            } catch {
                Write-Warning -Message "An unexpected Invoke-WebRequest error has occurred: $PSItem"
            }

            if ($Response.Content -Match '<title>(.+) - Chrome Web Store</title>' -and $Matches.Count -gt 1) {
                return $Matches[1]
            } else {
                return ''
            }
        }
    }
}

process {
    # Get all the chome extensions
    $ChromeExtensions = @(
        'C:\Users\*\AppData\Local\Google\Chrome\User Data\Default\Extensions\*',
        'C:\Users\*\AppData\Local\Chromium\User Data\Default\Extensions\*'
    )

    # Gather the extension list
    $Extensions = Invoke-Command -Session $Session -ScriptBlock { Get-Item -Path $using:ChromeExtensions }

    return $Extensions | Select-Object -Property @{Name='ExtensionID'; Expression={$PSItem.Name}},@{Name='ExtensionName'; Expression={Resolve-ChromeExtension -ExtensionID $PSItem.Name}},@{Name='User'; Expression={$PSItem.FullName -Split '\\' | Select-Object -First 1 -Skip 2}},@{Name='Path'; Expression={$PSItem.FullName}},'LastWriteTime','PSComputerName'
}
