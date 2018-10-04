function Get-Config {
    [CmdletBinding()]
    param (
        [String]$Path = ("{0}\Config.psd1" -f $PSScriptRoot),
        [String[]]$RootKeys = @('Path', 'UserName')
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
            UserName = @{
                Windows = $ENV:UserName
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
        if (!$Config.UserName) {
            $Config.UserName = $Default.UserName
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

        if (!$Config.UserName.Windows) {
            $Config.UserName.Windows = $Default.UserName.Windows
        }

        # Check for required $Config value existence (sanity check - should never fail with default values)
        if (!$Config.Path -or !$Config.UserName -or !$Config.Path.Bin -or !$Config.Path.Logs -or !$Config.Path.Output -or !$Config.Path.Plugins -or !$Config.UserName.Windows) {
            throw "Missing required configuration value"
        }

        # Ensure all $Config.Path directory values exist
        foreach ($DirPath in $Config.Path.Values) {
            # If the $DirPath doesn't exist, create it and get rid of the output
            if (!(Test-Path $DirPath)) {
                New-Item -Path $DirPath -ItemType Directory | Out-Null
            }
        }

        # Gather credentials for non-sessioned $UserName
        $Config.Credential = @{}
        foreach ($UserName in $Config.UserName.GetEnumerator()) {
            if ($UserName.Value -ne $ENV:UserName) {
                $Config.Credential.($UserName.Key) = Get-Credential -UserName $UserName.Value -Message ("Please enter {0} credentials" -f $UserName.Key)
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

        [Switch]$Back
    )

    begin {
        # Print Title
        Write-Host ("`n  {0}:" -f $Title)

        # Add the 'Back' option to $Choice
        if ($Back) {
            $Choice = @('..') + $Choice
        }
    }

    process {
        # Loop through the $Choice array and print off each line
        for ($i=0; $i -lt $Choice.Length; $i++) {
            # Line format: [#] - $Choice[#]
            $Line = "[{0}] - {1}" -f $i,$Choice[$i]

            Write-Host $Line
        }

        # Get user response with validation (0 <= $C < $Choice.Length)
        do {
            $C = Read-Host 'Choice'
        } while ((0..($Choice.Length-1)) -NotContains $C)
        
        return $Choice[$C]
    }
}

function Power-Response {
    process {
        # Get configuration data from file
        $Config = Get-Config

        # Initialize the current $Location to the $Config.Path.Plugins directory item
        $Location = Get-Item -Path $Config.Path.Plugins

        # While the $Location is a directory, and the directory has children (contents)
        while ($Location.PSIsContainer -and (Get-ChildItem $Location)) {
            # Compute $Title - Power-Response\CurrentPath
            $Title = 'Power-Response' + $Location.FullName -Replace [Regex]::Escape($PSScriptRoot)

            # Compute $Choice - directories starting with alphanumeric character | files ending in .ps1
            $Choice = Get-ChildItem -Path $Location | Where-Object { ($PSItem.PSIsContainer -and ($PSItem.Name -Match '^[A-Za-z0-9]')) -or (!$PSItem.PSIsContainer -and ($PSItem.Name -Match '\.ps1$')) } | Sort-Object -Property PSIsContainer,Name

            #Compute $Back - ensure we are not at the $Config.Path.Plugins
            $Back = $Location.FullName -ne (Get-Item -Path $Config.Path.Plugins | Select-Object -ExpandProperty FullName)

            # Get the next directory selection from the user, showing the back option if anywhere but the $Config.Path.Plugins
            $Selection = Get-Menu -Title $Title -Choice $Choice -Back:$Back

            # Get the selected $Location item
            $Location = Get-Item ("{0}\{1}" -f $Location.FullName,$Selection)
        }

        # Print out the full path of the resulting $Location
        Write-Host ("End Path: {0}" -f $Location.FullName)
    }
}

Power-Response
