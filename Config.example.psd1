@{
    # ---------- Begin Path Section ----------
    #   Bin - Location of the binary distribution folder (defaults to $PSScriptRoot\Bin)
    #   Logs - Location of the logs folder (defaults to $PSScriptRoot\Logs)
    #   Output - Location of the script output folder (defaults to $PSScriptRoot\Output)
    #   Plugins - Location of the plugins folder (defaults to $PSScriptRoot\Plugins)
    # Bin = $PSScriptRoot\Bin
    # Logs = $PSScriptRoot\Logs
    # Output = $PSScriptRoot\Output
    # Plugins = $PSScriptRoot\Plugins
    Path = @{
        # Bin = $PSScriptRoot\Bin
        # Logs = $PSScriptRoot\Logs
        # Output = $PSScriptRoot\Output
        # Plugins = $PSScriptRoot\Plugins
    }
    # ---------- End Path Section ----------

    # ---------- Begin Authentication Section ----------
    #   UserName - administrative username (defaults to $ENV:UserName)
    Authentication = @{
        # UserName = $ENV:UserName
    }
}
