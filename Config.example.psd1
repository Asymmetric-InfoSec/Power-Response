@{
    # --------- Begin General Section --------
    ####   AdminUserName - Administrative user name (defaults to $ENV:UserName)
    ####   HashAlgorithm - Hash algorithm to use for file integrity log (defaults to SHA256)
    ####   OutputType - Default output type for plugins (defaults to XML,CSV)
    ####   PromptText - Text to show with your prompt (defaults to power-response)
    # AdminUserName = $ENV:UserName
    # HashAlgorithm = 'SHA256'
    # OutputType = 'XML','CSV'
    # PromptText = 'power-response'
    # --------- End General Section ----------

    # ---------- Begin Path Section ----------
    #### Path - Group of important path locations
    ####   Bin - Location of the binary distribution folder (defaults to $PSScriptRoot\Bin)
    ####   Logs - Location of the logs folder (defaults to $PSScriptRoot\Logs)
    ####   Output - Location of the script output folder (defaults to $PSScriptRoot\Output)
    ####   Plugins - Location of the plugins folder (defaults to $PSScriptRoot\Plugins)
    Path = @{
        # Bin = $PSScriptRoot\Bin
        # Logs = $PSScriptRoot\Logs
        # Output = $PSScriptRoot\Output
        # Plugins = $PSScriptRoot\Plugins
    }
    # ---------- End Path Section ----------

    # ---------- Begin PSSession Section ----------
    #### PSSession - Group of parameters provided to New-PSSessionOption cmdlet for remoting options
    ####   NoMachineProfile - Option to not create a user profile on connected systems (defaults to $true)
    PSSession = @{
        # NoMachineProfile = $true
    }
    # ---------- End PSSession Section ----------
}
