@{
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

    # ---------- Begin Hash Section ----------
    #   Algorithm - Hash algorithm to use for file integrity log (defaults to SHA256)
    #   FileName - integrity log file name (defaults to hashes.csv)
    Hash = @{
        # Algorithm = SHA256
        # FileName = hashes.csv
    }
    # ---------- End Hash Section ----------

    # ---------- Begin Authentication Section ----------
    #   Windows - administrative username (defaults to $ENV:UserName)
    UserName = @{
        # Windows = $ENV:UserName
    }
}
