@{
    # --------- Begin General Section --------
    ####   AdminUserName - Administrative user name (defaults to $ENV:UserName)
    ####   AutoAnalyze - Automatically analyze data collections (defaults to $true)
    ####   AutoClear - Automatically clear the screen following plugin execution (defaults to $true)
    ####   EncryptPassword - Password to encrypt archives with (defaults to infected)
    ####   HashAlgorithm - Hash algorithm to use for file integrity log (defaults to SHA256)
    ####   OutputType - Default output type for plugins (defaults to CSV,XLSX)
    ####   PromptText - Text to show with your prompt (defaults to power-response)
    ####   RemoteStageDirectory - Stage directory for any executables and file copies (defaults to C:\ProgramData\Power-Response)
    ####   ShowParametersAtStart - Display all configuration parameters on start up (defaults to $true)
    ####   ThrottleLimit - Maximum number of concurrent connections (defaults to 32)
    # AdminUserName = $ENV:UserName
    # AutoAnalyze = $true
    # AutoClear = $true
    # EncryptPassword = 'infected'
    # HashAlgorithm = 'SHA256'
    # OutputType = 'CSV','XLSX'
    # PromptText = 'power-response'
    # RemoteStagingDirectory = 'C:\ProgramData\Power-Response'
    # ShowParametersAtStart = $true
    # ThrottleLimit = 32
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
