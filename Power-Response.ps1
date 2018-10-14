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

function Invoke-BackCommand {
    [Alias('Invoke-..Command')]
    param (
        [String[]]$Arguments,
        [String]$Location
    )
    process {
        Write-Verbose 'Chose to go back'
    }
}

function Invoke-ExitCommand {
    [Alias('Invoke-QuitCommand')]
    param (
        [String[]]$Arguments,
        [String]$Location
    )
    process {
        Write-Host 'Exiting...'
        exit
    }
}

function Invoke-HelpCommand {
    [Alias('Invoke-?Command')]
    param (
        [String[]]$Arguments,
        [String]$Location
    )

    process {
        # Load possible $Commands name, usage, and description
        $Commands = @(
            @{ Name='back'; Usage='back'; Description='de-select a script file and move back to menu context' },
            @{ Name='exit'; Usage='exit'; Description='exits Power Response' },
            @{ Name='help'; Usage='help [commands...]'; Description='displays the help for all or specified commands'},
            @{ Name='run'; Usage='run'; Description='runs the selected script with parameters set in environment' },
            @{ Name='set'; Usage='set <parameter> [value]'; Description='sets a parameter to a value' },
            @{ Name='show'; Usage='show [parameters...]'; Description='shows a list of all or specified parameters and values' }
        ) | Foreach-Object { [PSCustomObject]$PSItem }

        # If there is no $Location set
        if (!$Location) {
            # Don't show 'back' or 'run' as command options
            $Commands = $Commands | Where-Object { @('back','run') -NotContains $PSItem.Name }
        }

        # Filter $Arguments to remove invalid $Commands.Name
        $Arguments = $Arguments | Where-Object { $Commands.Name -Contains $PSItem }

        # If $Arguments are blank
        if ($Arguments.Count -eq 0) {
            # Assume full 'help' display
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
        return $Commands | Where-Object { $Arguments -Contains $PSItem.Name } | Select-Object -Property $Property | Format-Table
    }
}

function Invoke-RunCommand {
    param (
        [String[]]$Arguments,
        [String]$Location
    )

    process {
        if ($Location) {
            & $Location @script:Parameters
        } else {
            Write-Warning 'No file selected for execution'
        }
    }
}

function Invoke-SetCommand {
    param (
        [String[]]$Arguments,
        [String]$Location
    )

    process {
        # Set command requires a parameter as an argument
        if ($Arguments.Count -lt 1) {
            Write-Warning 'Improper ''set'' command usage'
            Invoke-HelpCommand -Arguments 'set'
            return
        }

        # Set the $Parameter key and value specified by $Arguments
        $script:Parameters.($Arguments[0]) = $Arguments[1]

        # Show the newly set value
        return Invoke-ShowCommand -Arguments $Arguments[0]
    }
}

function Invoke-ShowCommand {
    param (
        [String[]]$Arguments,
        [String]$Location
    )

    process {
        # If we have selected a file $Location
        if ($Location -and !(Get-Item $Location | Select-Object -ExpandProperty PSIsContainer)) {
            # Conform to $Location's $CommandParameters
            $CommandParameters = Get-Command $Location | Select-Object -ExpandProperty Parameters

            # Filter $Arguments to remove invalid $CommandParameters.Keys
            $Arguments = $Arguments | Where-Object { $CommandParameters.Keys -Contains $PSItem }

            # If $Arguments array is empty
            if ($Arguments.Count -eq 0) {
                # List of $System scoped parameters
                $System = @('WarningAction','Debug','InformationAction','ErrorVariable','InformationVariable','WarningVariable','Verbose','ErrorAction','OutVariable','OutBuffer','PipelineVariable')

                # Get all $UserCommandParameters (non-system generated parameters)
                $UserCommandParameters = $CommandParameters.GetEnumerator() | Where-Object { $System -NotContains $PSItem.Key -or $script:Parameters.($PSItem.Key) }

                # Set $Arguments to $UserCommandParameters.Key to return full list
                $Arguments = $UserCommandParameters.Key
            }
        } else {
            # Ensure $CommandParameters is blank
            $CommandParameters = @{}

            # If $Arguments array is empty
            if ($Arguments.Count -eq 0) {
                # Set $Arguments to all Keys of $Parameters
                $Arguments = $script:Parameters.Keys
            }
        }


        # Initialize empty $Param(eter) return HashTable
        $Param = @{}

        if ($CommandParameters.Count -gt 0) {
            # Set $Param.[Type]$Key to the $Parameters.$Key value
            $Arguments | Sort-Object | Foreach-Object { $Param.("[{0}]{1}" -f $CommandParameters.$PSItem.ParameterType.Name,$PSItem)=$script:Parameters.$PSItem }
        } else {
            # Set $Param.$Key to the $Parameters.$Key value
            $Arguments | Sort-Object | Foreach-Object { $Param.$PSItem=$script:Parameters.$PSItem }
        }

        # Cast the HashTable to a PSCustomObject and format as an alphabetical-order list object
        return [PSCustomObject]$Param | Format-List
    }
}

function Invoke-PowerCommand {
    param (
        [String]$UserInput,
        [String]$Location
    )

    process {
        # $Keyword will be the first word of the user input
        $Keyword = $UserInput -Split ' ' | Select-Object -First 1

        # $Arguments will be any following words
        $Arguments = $UserInput -Split ' ' | Select-Object -Skip 1

        # If no $Keyword is not provided or we have no $Location and were provided a number return early
        if (!$Keyword -or (!$Location -and $Keyword -Match '^[0-9]$')) {
            return
        }

        # Try to execute function corresponding to command passed
        try {
            & ("Invoke-{0}Command" -f $Keyword) -Arguments $Arguments -Location $Location
        } catch {
            # Didn't understand keyword specified, write warning to screen
            Write-Warning ("Unknown Command '{0}', 'help' prints a list of available commands" -f $Keyword)
        }
    }
}

function Get-Menu {
    param (
        [String]$Title,
        [String[]]$Choice,
        [Switch]$Back
    )

    process {
        # Add the 'Back' option to $Choice
        if ($Back) {
            [String[]]$Choice = @('..') + $Choice | Where-Object { $PSItem }
        }

        # Loop until $UserInput exists and is 0 <= $UserInput <= $Choice.Length-1
        do {
            # Print Title
            Write-Host ("`n  {0}:" -f $Title)

            # Loop through the $Choice array and print off each line
            for ($i=0; $i -lt $Choice.Length; $i++) {
                # Line format: [#] - $Choice[#]
                $Line = "[{0}] - {1}" -f $i,$Choice[$i]

                Write-Host $Line
            }

            # Get $UserInput
            $UserInput = Read-Host 'Enter Choice or Command'

            # Try to interpret the $UserInput as a command
            if ($UserInput) {
                Invoke-PowerCommand -UserInput $UserInput | Out-Default
            }
        } while (!$UserInput -or (0..($Choice.Length-1)) -NotContains $UserInput)

        return $Choice[$UserInput]
    }
}

function Power-Response {
    process {
        # $Banner for Power-Response
        $Banner = @'
    ____                                ____                                      
   / __ \____ _      _____  _____      / __ \___  _________  ____  ____  ________ 
  / /_/ / __ \ | /| / / _ \/ ___/_____/ /_/ / _ \/ ___/ __ \/ __ \/ __ \/ ___/ _ \
 / ____/ /_/ / |/ |/ /  __/ /  /_____/ _, _/  __(__  ) /_/ / /_/ / / / (__  )  __/
/_/    \____/|__/|__/\___/_/        /_/ |_|\___/____/ .___/\____/_/ /_/____/\___/ 
                                                   /_/                            

Authors: 5ynax | 5k33tz | Valrkey

'@

        Write-Host $Banner

        # Get $Config from data file
        $Config = Get-Config

        # Get the $Plugins directory item
        $Plugins = Get-Item -Path $Config.Path.Plugins

        # Initialize the current $Location to the $Config.Path.Plugins directory item
        $Location = $Plugins

        # Ensure we have at least one plugin installed
        if (!(Get-ChildItem $Location)) {
            Write-Error 'No Power-Response plugins detected'
            Read-Host 'Press Enter to Exit'
            exit
        }

        # Initialize tracked $Parameters to $Config data
        $script:Parameters = @{}

        # Loop through searching for a script file and setting parameters
        do {
            # While the $Location is a directory
            while ($Location.PSIsContainer) {
                # Compute $Title - Power-Response\CurrentPath
                $Title = 'Power-Response' + ($Location.FullName -Replace ('^' + [Regex]::Escape($PSScriptRoot)))

                # Compute $Choice - directories starting with alphanumeric character | files ending in .ps1
                $Choice = Get-ChildItem -Path $Location.FullName | Where-Object { ($PSItem.PSIsContainer -and ($PSItem.Name -Match '^[A-Za-z0-9]')) -or (!$PSItem.PSIsContainer -and ($PSItem.Name -Match '\.ps1$')) } | Sort-Object -Property PSIsContainer,Name

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

            # Show all of the $Parameters relevent to the selected $CommandParameters
            Invoke-ShowCommand -Location $Location

            # Until the user specifies to 'run' the program or go 'back', interpret $UserInput as commands
            do {
                # Get $UserInput
                $UserInput = Read-Host 'Enter Command'

                # Interpret $UserInput as a command and pass the $Location
                if ($UserInput) {
                    Invoke-PowerCommand -UserInput $UserInput -Location $Location | Out-Default
                }
            } while (@('run','back') -NotContains $UserInput)

            # Set $Location to the previous directory
            $Location = Get-Item -Path ($Location.FullName -Replace ('\\[^\\]+$'))
        } while ($True)
    }
}

Power-Response
