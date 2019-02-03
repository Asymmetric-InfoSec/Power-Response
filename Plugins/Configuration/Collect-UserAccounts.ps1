<#

.SYNOPSIS
    Plugin-Name: Collect-UserAccounts
    
.Description

    Gets local and network user accounts on a system.

.EXAMPLE

    Stand Alone:

    .\Collect-Process_Dlls -ComputerName Test-PC

    Power-Response:

    Set ComputerName Test-PC
    Run


.NOTES
    Author: Gavin Prentice
    Date Created: 2/2/2019
    Twitter: @valrkey

    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param (
    [String[]]$ComputerName = 'localhost'
)

process {
    # Collect the local and network user data from the remote systems
    $Local = Invoke-Command -ComputerName $ComputerName -ScriptBlock { Get-CIMInstance -Class "Win32_UserAccount" }
    $Network = Invoke-Command -ComputerName $ComputerName -ScriptBlock { Get-CIMInstance -Class 'Win32_NetworkLoginProfile' }

    # If we are providing PowerResponse output, explicitly send data to separate files
    if (Get-Command -Name 'Out-PRFile' -ErrorAction 'SilentlyContinue') {
        $Local | Select-Object -Property 'Name','Caption','Disabled','AccountType','SID','Domain','Description' | Out-PRFile -Append 'Local'
        $Network | Select-Object -Property 'Name','UserID','Caption','Profile','LastLogon','NumberOfLogons','BadPasswordCount' | Out-PRFile -Append 'Network'
    } else {
        # Else, return the objects to the console
        $Local
        $Network
    }
}
