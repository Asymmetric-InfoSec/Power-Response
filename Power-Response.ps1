function Get-Config {
    [CmdletBinding()]
    param (
        [String]$Path = ("{0}\Config.psd1" -f $PSScriptRoot),
        [String[]]$RootKeys = @('Path', 'Authentication')
    )

    process {
        Write-Verbose 'Begin Get-ConfigData'

        # Default 'Config' values
        $Default = @{
            Path = @{
               Bin = "{0}\Bin" -f $PSScriptRoot
               Logs = "{0}\Logs" -f $PSScriptRoot
               Output = "{0}\Output" -f $PSScriptRoot
               Plugins = "{0}\Plugins" -f $PSScriptRoot
            }
            Authentication = @{
                UserName = $ENV:UserName
            }
        }

        # Try to import the data, on failure set to default 
        try {
            if (!(Test-Path $Path)) {
                throw 'Path does not exist'
            }

            $File = Get-Item -Path $Path
            Import-LocalizedData -BindingVariable Config -BaseDirectory $File.PSParentPath -FileName $File.Name -ErrorAction Stop
        } catch {
            Write-Verbose ("Unable to import config on 'Path': '{0}'" -f $Path)
            $Config = $Default
        }

        # Check for unexpected values in Config
        if ($RootKeys) {
            $UnexpectedRootKeys = $Config.Keys | ? { $RootKeys -NotContains $PSItem }
            if ($UnexpectedRootKeys) {
                Write-Warning ("Discovered unexpected keys in config file '{0}':" -f $Path)
                Write-Warning ("    '{0}'" -f ($UnexpectedRootKeys -Join ', '))
                Write-Warning  "Removing these values from the Config hashtable"
                $UnexpectedRootKeys | % { $Config.Remove($PSItem) }
            }
        }

        # If no value is provided, set the default values
        if (!$Config.Path) {
            $Config.Path = $Default.Path
        }
        if (!$Config.Authentication) {
            $Config.Authentication = $Default.Authentication
        }

        if (!$Config.Path.Bin) {
            $Config.Path.Bin = $Default.Path.Bin
        } 
        if (!$Config.Path.Logs) {
            $Config.Path.Logs = $Default.Path.Logs
        }
        if (!$Config.Path.Output) {
            $Config.Path.Output = $Default.Path.Output
        } 
        if (!$Config.Path.Plugins) {
            $Config.Path.Plugins = $Default.Path.Plugins
        }

        if (!$Config.Authentication.UserName) {
            $Config.Authentication.Username = $Default.Authentication.UserName
        }

        # Check config value existence
        if (!$Config.Path -or !$Config.Authentication -or !$Config.Path.Bin -or !$Config.Path.Logs -or !$Config.Path.Output -or !$Config.Path.Plugins -or !$Config.Authentication.UserName) {
            throw "Missing required configuration value"
        }

        # Check for directory existence
        foreach ($Key in $Config.Path.Keys) {
            $Path = $Config.Path.$Key
            if (!(Test-Path $Path)) {
                New-Item -Path $Path -ItemType Directory
            }
        }

        return $Config
    }
}


function Get-Menu {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,Position=0)]
        [String]$Title,
        
        [Parameter(Mandatory=$true,Position=1)]
        [String[]]$Choice,
        
        [String[]]$Description
    )

    process {
        # Print Title
        Write-Host ("`n  {0}:" -f $Title)

        for ($i=0; $i -lt $Choice.Length; $i++) {
            $Line = "[{0}] - {1}" -f $i,$Choice[$i]
            if ($i -lt $Description.Length -and $Description[$i]) {
                $Line += " ({0})" -f $Description[$i]
            }
            Write-Host $Line
        }

        # Grab user response with validation
        do {
            $C = Read-Host 'Choice'
        } while ((0..($i-1)) -NotContains $C)
        
        return $Choice[$C]
    }
}

function Power-Response {
    process {
        $Config = Get-Config

        $Option = 'Power Response'
        $Location = Get-Item -Path $Config.Path.Plugins

        while ($Location.PSIsContainer -and (Get-ChildItem $Location)) {
            $Option = Get-Menu -Title $Option -Choice (Get-ChildItem -Path $Location | Sort-Object -Property Name)
            $Location = Get-Item ("{0}\{1}" -f $Location,$Option)
        }

        Write-Host ("End Path: {0}" -f $Location.FullName)
    }
}

Power-Response