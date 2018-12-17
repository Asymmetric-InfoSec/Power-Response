@{
    # --------- Begin General Section --------
    #   HashAlgorithm - Hash algorithm to use for file integrity log (defaults to SHA256)
    #   OutputType - Default output type for plugins (defaults to XML)
    #   PromptText - Text to show with your prompt (defaults to power-response)
    # HashAlgorithm = 'SHA256'
    # OutputType = 'XML'
    # PromptText = 'power-response'
    # --------- End General Section ----------

    # ---------- Begin Path Section ----------
    #   Bin - Location of the binary distribution folder (defaults to $PSScriptRoot\Bin)
    #   Logs - Location of the logs folder (defaults to $PSScriptRoot\Logs)
    #   Output - Location of the script output folder (defaults to $PSScriptRoot\Output)
    #   Plugins - Location of the plugins folder (defaults to $PSScriptRoot\Plugins)
    Path = @{
        # Bin = $PSScriptRoot\Bin
        # Logs = $PSScriptRoot\Logs
        # Output = $PSScriptRoot\Output
        # Plugins = $PSScriptRoot\Plugins
    }
    # ---------- End Path Section ----------

    # ---------- Begin Authentication Section ----------
    #   Windows - administrative username (defaults to $ENV:UserName)
    UserName = @{
        # Windows = $ENV:UserName
    }
    # ---------- End Authentication Section ----------
}
