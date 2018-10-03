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
            # C:\Path\To\Power-Response\{FolderName}
            Path = @{
               Bin = "{0}\Bin" -f $PSScriptRoot
               Logs = "{0}\Logs" -f $PSScriptRoot
               Output = "{0}\Output" -f $PSScriptRoot
               Plugins = "{0}\Plugins" -f $PSScriptRoot
            }

            # Executing UserName
            Authentication = @{
                UserName = $ENV:UserName
            }
        }

        # Try to import the data, on failure set to default 
        try {
            # If the Config file $Path does not exist, throw an error to skip to catch block
            if (!(Test-Path $Path)) {
                throw 'Path does not exist'
            }

            # Get the Config file at $Path
            $File = Get-Item -Path $Path

            # Import the Config data file and bind it to the $Config variable
            Import-LocalizedData -BindingVariable Config -BaseDirectory $File.PSParentPath -FileName $File.Name -ErrorAction Stop
        } catch {
            # Either intentionally threw an error on file absense, or Import-LocalizedData failed
            Write-Verbose ("Unable to import config on 'Path': '{0}'" -f $Path)
            $Config = $Default
        }

        # Check for unexpected values in Config file
        if ($RootKeys) {
            # Iterate through Config.Keys and keep any values not contained in expected $RootKeys 
            $UnexpectedRootKeys = $Config.Keys | Where-Object { $RootKeys -NotContains $PSItem }

            # If we found unexpected keys, print a warning message
            if ($UnexpectedRootKeys) {
                Write-Warning ("Discovered unexpected keys in config file '{0}':" -f $Path)
                Write-Warning ("    '{0}'" -f ($UnexpectedRootKeys -Join ', '))
                Write-Warning  "Removing these values from the Config hashtable"

                # Remove any detected unexpected keys from $Config
                $UnexpectedRootKeys | % { $Config.Remove($PSItem) }
            }
        }

        # If no value is provided in the config file, set the default values
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

        # Check for required $Config value existence (sanity check - should never fail with default values)
        if (!$Config.Path -or !$Config.Authentication -or !$Config.Path.Bin -or !$Config.Path.Logs -or !$Config.Path.Output -or !$Config.Path.Plugins -or !$Config.Authentication.UserName) {
            throw "Missing required configuration value"
        }

        # Ensure all $Config.Path directory values exist
        foreach ($DirPath in $Config.Path.Values) {
            # If the $DirPath doesn't exist, create it and get rid of the output
            if (!(Test-Path $DirPath)) {
                New-Item -Path $DirPath -ItemType Directory | Out-Null
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
    )

    process {
        # Print Title
        Write-Host ("`n  {0}:" -f $Title)

        # Loop through the $Choice array and print off each line
        for ($i=0; $i -lt $Choice.Length; $i++) {
            # Line format: [#] - $Choice[#]
            $Line = "[{0}] - {1}" -f $i,$Choice[$i]

            Write-Host $Line
        }

        # Get user response with validation (0 <= $C < $Choice.Length)
        do {
            $C = Read-Host 'Choice'
        } while ((0..($i-1)) -NotContains $C)
        
        return $Choice[$C]
    }
}

function Power-Response {
    process {
        # Get configuration data from file
        $Config = Get-Config

        # Initialize the menu $Title to 'Power Response'
        $Title = 'Power Response'

        # Initialize the current $Location to the $Config.Path.Plugins directory item
        $Location = Get-Item -Path $Config.Path.Plugins

        # While the $Location is a directory, and the directory has children (contents)
        while ($Location.PSIsContainer -and (Get-ChildItem $Location)) {
            # Get the next directory selection from the user
            $Title = Get-Menu -Title $Title -Choice (Get-ChildItem -Path $Location | Sort-Object -Property Name)

            # Get the selected $Location item
            $Location = Get-Item ("{0}\{1}" -f $Location.FullName,$Title)
        }

        # Print out the full path of the resulting $Location
        Write-Host ("End Path: {0}" -f $Location.FullName)
    }
}

Power-Response