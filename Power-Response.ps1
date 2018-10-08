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
        [Parameter(Mandatory=$true)]
        [String]$Title,
        
        [String[]]$Choice,

        [Switch]$Back
    )

    begin {
        # Print Title
        Write-Host ("`n  {0}:" -f $Title)

        # Add the 'Back' option to $Choice
        if ($Back) {
            [String[]]$Choice = @('..') + $Choice | Where-Object { $PSItem }
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

function Write-Parameter {
    param (
        [String[]]$Arguments
    )

    process {
        # Filter $Arguments to remove invalid $CommandParameters.Keys
        $Arguments = $Arguments | Where-Object { $script:CommandParameters.Keys -Contains $PSItem }

        # If $Arguments array is empty
        if ($Arguments.Count -eq 0) {
            # List of $System scoped parameters
            $System = @('WarningAction','Debug','InformationAction','ErrorVariable','InformationVariable','WarningVariable','Verbose','ErrorAction','OutVariable','OutBuffer','PipelineVariable')

            # Get all $UserCommandParameters (non-system generated parameters)
            $UserCommandParameters = $script:CommandParameters.GetEnumerator() | Where-Object { $System -NotContains $PSItem.Key }

            # Set $Arguments to $UserCommandParameters.Key to return full list
            $Arguments = $UserCommandParameters.Key
        }

        # Initialize empty $Param(eter) return hashtable
        $Param = @{}

        # Set the key of $Param to the $Parameter.$Key value
        $Arguments | Foreach-Object { $Param.$PSItem=$script:Parameters.$PSItem }

        # Get alphabetical order of $Arguments keys
        $Property = $Arguments | Sort-Object

        # Cast the HashTable to a PSCustomObject and format as an alphabetical-order list object
        [PSCustomObject]$Param | Select-Object -Property $Property | Format-List
    }
}

function Set-Parameter {
    param (
        [String[]]$Arguments
    )

    process {
        # Set command requires a parameter as an argument
        if ($Arguments.Count -lt 1) {
            Write-Warning 'Improper ''set'' command usage'
            Write-Help -Arguments 'set'
            return
        }

        # Ensure parameter passed has a matching parameter for selected script
        if ($script:CommandParameters.Keys -NotContains $Arguments[0]) {
            Write-Warning ("Unknown parameter '{0}'" -f $Arguments[0])
            return
        }

        # Set the $Parameter key and value specified by $Arguments
        $script:Parameters.($Arguments[0]) = $Arguments[1]

        # Show the newly set value
        Write-Parameter -Arguments $Arguments[0]
    }
}

function Write-Help {
    param (
        [String[]]$Arguments
    )

    process {
        # Load possible $Commands name, usage, and description
        $Commands = @(
            @{ Name='set'; Usage='set <parameter> [value]'; Description='sets a parameter to a value' },
            @{ Name='show'; Usage='show [parameters...]'; Description='shows a list of all or specified parameters and values' },
            @{ Name='help'; Usage='help [commands...]'; Description='displays the help for all or specified commands'},
            @{ Name='run'; Usage='run'; Description='runs the selected script with parameters set in environment' },
            @{ Name='quit'; Usage='quit'; Description='quits the selected script' },
            @{ Name='exit'; Usage='exit'; Description='exits the selected script' }
        ) | Foreach-Object { [PSCustomObject]$PSItem }

        # Filter $Arguments to remove invalid $Commands.Name
        $Arguments = $Arguments | Where-Object { $Commands.Name -Contains $PSItem }

        # If $Arguments are blank, assume full 'help' display
        if ($Arguments.Count -eq 0) {
            $Arguments = $Commands.Name
        }

        # If $Arguments and $Command.Name are different
        if ($Commands.Name | Where-Object { $Arguments -NotContains $PSItem }) {
            # Specific 'help <command>' show the Usage and Description
            $Property = @('Usage','Description')
        } else {
            # Generic 'help' show the Name and Description
            $Property = @('Name','Description')
        }

        # Print out the rows of $Commands specified by $Arguments and the columns specified by $Property
        $Commands | Where-Object { $Arguments -Contains $PSItem.Name } | Select-Object -Property $Property | Format-Table
    }
}

function Power-Response {
    process {
        # Get configuration data from file
        $Config = Get-Config

        # Get the $Plugins directory item
        $Plugins = Get-Item -Path $Config.Path.Plugins

        # Initialize the current $Location to the $Config.Path.Plugins directory item
        $Location = $Plugins

        # Ensure we have at least one plugin installed
        if (!(Get-ChildItem $Location)) {
            throw 'No Power-Response plugins detected'
        }

        # Loop through searching for a script file and setting parameters
        do {
            # While the $Location is a directory
            while ($Location.PSIsContainer) {
                # Compute $Title - Power-Response\CurrentPath
                $Title = 'Power-Response' + ($Location.FullName -Replace ('^' + [Regex]::Escape($PSScriptRoot)))

                # Compute $Choice - directories starting with alphanumeric character | files ending in .ps1
                $Choice = Get-ChildItem -Path $Location | Where-Object { ($PSItem.PSIsContainer -and ($PSItem.Name -Match '^[A-Za-z0-9]')) -or (!$PSItem.PSIsContainer -and ($PSItem.Name -Match '\.ps1$')) } | Sort-Object -Property PSIsContainer,Name

                #Compute $Back - ensure we are not at the $Config.Path.Plugins
                $Back = $Plugins.FullName -NotMatch [Regex]::Escape($Location.FullName)

                # Get the next directory selection from the user, showing the back option if anywhere but the $Config.Path.Plugins
                $Selection = Get-Menu -Title $Title -Choice $Choice -Back:$Back

                # Get the selected $Location item
                try {
                    $Location = Get-Item ("{0}\{1}" -f $Location.FullName,$Selection) -ErrorAction Stop
                } catch {
                    Write-Warning 'Something went wrong, please try again'
                }
            }

            # Get the $CommandParameters of the selected script file
            $script:CommandParameters = Get-Command -Name $Location.FullName | Select-Object -ExpandProperty Parameters

            # Initialize input parameters to empty hashtable (will eventually pull stored session data)
            $script:Parameters = @{}

            # Write the list of parameters to the screen
            Write-Parameter

            # Until the user specifies to run, quit, or exit the program, set the parameters
            do {
                # Get user input
                $UserInput = Read-Host ('Enter Command' + $HelpText)

                # Initialize HelpText to null string before command processing
                $HelpText = ''

                # $Keyword will be the first word of the user input
                $Keyword = $UserInput -Split ' ' | Select-Object -First 1

                # $Arguments will be any following words
                $Arguments = $UserInput -Split ' ' | Select-Object -Skip 1

                # Determine which $Keyword we are executing
                switch($Keyword) {
                    'set' {
                        Set-Parameter -Arguments $Arguments
                    }
                    'show' {
                        Write-Parameter -Arguments $Arguments
                    }
                    'help' {
                        Write-Help -Arguments $Arguments
                    }
                    'run' {
                        Write-Host ('Would execute: ' + $Location.FullName)
                        Write-Host 'With Parameters:'
                        Write-Parameter
                    }
                    'quit' {
                        Write-Host 'Quitting...'
                    }
                    'exit' {
                        Write-Host 'Exiting...'
                    }
                    default {
                        # Didn't understand keyword specified, write warning to screen and add help text to next prompt
                        if ($Keyword) {
                            Write-Warning ("Unknown Command '{0}'" -f $Keyword)
                        }
                        $HelpText = ' (''help'' will display a list of commands)'
                    }
                }
            } while (@('run','quit','exit') -NotContains $Keyword)

            # Set $Location to the previous directory
            $Location = Get-Item -Path ($Location.FullName -Replace ('\\[^\\]+$'))
        } while (@('quit','exit') -NotContains $Keyword)
    }
}

Power-Response
