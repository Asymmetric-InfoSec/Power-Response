function Format-Parameter {
    param (
        [String[]]$Arguments,
        [String]$Location
    )

    process {
        # Gather to $Location's $CommandParameters
        $CommandParameters = Get-Command $Location | Select-Object -ExpandProperty Parameters

        # If we are passed no $Arguments, assume full $Parameter format check
        if ($Arguments.Count -eq 0) {
            $Arguments = $CommandParameters.Keys
        }

        # Narrow the scope of $Arguments to the $CommandParameters that have a stored value in $Parameters
        $Arguments = $Arguments | Where-Object { $CommandParameters.Keys -Contains $PSItem -and $script:Parameters.$PSItem }

        # Foreach $CommandParam listed in $Arguments
        foreach ($CommandParam in $Arguments) {
            # Gather the $CommandParameter $ParameterType
            $ParameterType = $CommandParameters.$CommandParam.ParameterType.FullName

            # Ignore string $ParameterType with an existing string $Parameters.CommandParam value
            if ($ParameterType -ne $script:Parameters.$CommandParam.GetType().FullName) {
                # Build the $Command string '[TYPE]($Parameters.VALUE)'
                $Command = "[{0}]({1})" -f $ParameterType,$script:Parameters.$CommandParam
                try {
                    # Try to interpret the $Command expression and store it back to $Parameters.$CommandParam
                    $script:Parameters.$CommandParam = Invoke-Expression -Command $Command
                } catch {
                    # Failed to interpret the $Command expression, determine if it was a casting or expression issue
                    if ($Error[0] -and $Error[0].FullyQualifiedErrorId -eq 'ConvertToFinalInvalidCastException') {
                        $Warning = "Cannot convert parameter '{0}' of value '{1}' to type '{2}'" -f $CommandParam,$script:Parameters.$CommandParam,$CommandParameters.$CommandParam.ParameterType.Name
                    } else {
                        $Warning = "Cannot interpret parameter '{0}' of value '{1}' as a valid PowerShell expression" -f $CommandParam,$script:Parameters.$CommandParam
                    }

                    # Write an appropriate $Warning
                    Write-Warning $Warning

                    # remove the $CommandParam key from $Parameters
                    $script:Parameters.Remove($CommandParam) | Out-Null
                }
            }
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

function Import-Config {
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

            # Import the Config data file and bind it to the $script:Config variable
            Import-LocalizedData -BindingVariable Config -BaseDirectory $File.PSParentPath -FileName $File.Name -ErrorAction Stop
        } catch {
            # Either intentionally threw an error on file absense, or Import-LocalizedData failed
            Write-Verbose ("Unable to import config on 'Path': '{0}'" -f $Path)
            $script:Config = $Default
        }

        # Check for unexpected values in Config file
        if ($RootKeys) {
            # Iterate through Config.Keys and keep any values not contained in expected $RootKeys 
            $UnexpectedRootKeys = $script:Config.Keys | Where-Object { $RootKeys -NotContains $PSItem }

            # If we found unexpected keys, print a warning message
            if ($UnexpectedRootKeys) {
                Write-Warning ("Discovered unexpected keys in config file '{0}':" -f $Path)
                Write-Warning ("    '{0}'" -f ($UnexpectedRootKeys -Join ', '))
                Write-Warning  "Removing these values from the Config hashtable"

                # Remove any detected unexpected keys from $script:Config
                $UnexpectedRootKeys | % { $script:Config.Remove($PSItem) }
            }
        }

        # If no value is provided in the config file, set the default values
        if (!$script:Config.Path) {
            $script:Config.Path = $Default.Path
        }
        if (!$script:Config.UserName) {
            $script:Config.UserName = $Default.UserName
        }

        if (!$script:Config.Path.Bin) {
            $script:Config.Path.Bin = $Default.Path.Bin
        } 
        if (!$script:Config.Path.Logs) {
            $script:Config.Path.Logs = $Default.Path.Logs
        }
        if (!$script:Config.Path.Output) {
            $script:Config.Path.Output = $Default.Path.Output
        } 
        if (!$script:Config.Path.Plugins) {
            $script:Config.Path.Plugins = $Default.Path.Plugins
        }

        if (!$script:Config.UserName.Windows) {
            $script:Config.UserName.Windows = $Default.UserName.Windows
        }

        # Check for required $script:Config value existence (sanity check - should never fail with default values)
        if (!$script:Config.Path -or !$script:Config.UserName -or !$script:Config.Path.Bin -or !$script:Config.Path.Logs -or !$script:Config.Path.Output -or !$script:Config.Path.Plugins -or !$script:Config.UserName.Windows) {
            throw "Missing required configuration value"
        }

        # Ensure all $script:Config.Path directory values exist
        foreach ($DirPath in $script:Config.Path.Values) {
            # If the $DirPath doesn't exist, create it and get rid of the output
            if (!(Test-Path $DirPath)) {
                New-Item -Path $DirPath -ItemType Directory | Out-Null
            }
        }

        # Gather credentials for non-sessioned $UserName
        $script:Config.Credential = @{}
        foreach ($UserName in $script:Config.UserName.GetEnumerator()) {
            if ($UserName.Value -ne $ENV:UserName) {
                $script:Config.Credential.($UserName.Key) = Get-Credential -UserName $UserName.Value -Message ("Please enter {0} credentials" -f $UserName.Key)
            }
        }
    }
}

function Invoke-BackCommand {
    [Alias('Invoke-..Command')]
    param (
        [String[]]$Arguments,
        [String]$Location
    )
    process {
        Write-Host 'Going back...'
    }
}

function Invoke-ExitCommand {
    [Alias('Invoke-QuitCommand')]
    param (
        [String[]]$Arguments,
        [String]$Location
    )
    process {
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
            @{ Name='remove'; Usage='remove [parameters...]'; Description='removes all or a specified parameter values' },
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

function Invoke-RemoveCommand {
    [Alias('Invoke-RMCommand')]
    [Alias('Invoke-DelCommand')]
    param (
        [String[]]$Arguments,
        [String]$Location
    )

    process {
        # If $Arguments are blank and we have selected a file $Location
        if ($Arguments.Count -eq 0 -and $Location -and !(Get-Item $Location | Select-Object -ExpandProperty PSIsContainer)) {
            # Assume 'remove' all tracked command parameters
            $Arguments = Get-Command $Location | Select-Object -ExpandProperty Parameters | Select-Object -ExpandProperty Keys
        } elseif ($Arguments.Count -eq 0) {
            # Assume 'remove' all tracked $Parameters
            $Arguments = $script:Parameters | Select-Object -ExpandProperty Keys
        }

        # Filter $Arguments to remove invalid $Parameters.Keys
        $Arguments = $Arguments | Where-Object { $script:Parameters.Keys -Contains $PSItem }

        # If we have $Arguments to remove
        if ($Arguments.Count -ne 0) {
            # Remove $Arguments from $Parameters
            $Arguments | Foreach-Object { $script:Parameters.Remove($PSItem) | Out-Null }
        }

        # Show the new parameter list
        Invoke-ShowCommand -Location $Location
    }
}

function Invoke-RunCommand {
    param (
        [String[]]$Arguments,
        [String]$Location
    )

    process {
        # If we have selected a file $Location
        if ($Location -and !(Get-Item $Location | Select-Object -ExpandProperty PSIsContainer)) {
            # Gather to $Location's $CommandParameters
            $CommandParameters = Get-Command $Location | Select-Object -ExpandProperty Parameters

            # Initialize $ReleventParameters Hashtable
            $ReleventParameters = @{}

            # Parse the $ReleventParameters from $Parameters
            $script:Parameters.GetEnumerator() | Where-Object { $CommandParameters.Keys -Contains $PSItem.Key } | Foreach-Object { $ReleventParameters.($PSItem.Key) = $PSItem.Value }

            try {
                # Execute the $Location with the $ReleventParameters
                & $Location @ReleventParameters
            } catch {
                Write-Warning ('Command execution error: {0}' -f $PSItem)
            }
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
            return Invoke-HelpCommand -Arguments 'set'
        }

        # Set the $Parameters key and value specified by $Arguments
        $script:Parameters.($Arguments[0]) = ($Arguments | Select-Object -Skip 1) -Join ' '

        # If we are provided a blank set command, remove the key from $Parameters
        if ($script:Parameters.($Arguments[0]) -eq '') {
            return Invoke-RemoveCommand -Arguments $Arguments -Location $Location
        }

        # If we have a selected $Location, format the $Parameters
        if ($Location) {
            Format-Parameter -Location $Location -Arguments $Arguments[0]
        }

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
            # Gather to $Location's $CommandParameters
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

        # Import $script:Config from data file
        Import-Config

        # Save the execution location
        $SavedLocation = Get-Location

        # Set the location to Bin folder to allow easy asset access
        Set-Location $script:Config.Path.Bin

        # Get the $Plugins directory item
        $Plugins = Get-Item -Path $script:Config.Path.Plugins

        # Initialize the current $Location to the $script:Config.Path.Plugins directory item
        $Location = $Plugins

        # Ensure we have at least one plugin installed
        if (!(Get-ChildItem $Location)) {
            Write-Error 'No Power-Response plugins detected'
            Read-Host 'Press Enter to Exit'
            exit
        }

        # Initialize tracked $Parameters to $script:Config data
        $script:Parameters = @{}

        # Trap 'exit's and Ctrl-C interrupts
        try {
            # Loop through searching for a script file and setting parameters
            do {
                # While the $Location is a directory
                while ($Location.PSIsContainer) {
                    # Compute $Title - Power-Response\CurrentPath
                    $Title = 'Power-Response' + ($Location.FullName -Replace ('^' + [Regex]::Escape($PSScriptRoot)))

                    # Compute $Choice - directories starting with alphanumeric character | files ending in .ps1
                    $Choice = Get-ChildItem -Path $Location.FullName | Where-Object { ($PSItem.PSIsContainer -and ($PSItem.Name -Match '^[A-Za-z0-9]')) -or (!$PSItem.PSIsContainer -and ($PSItem.Name -Match '\.ps1$')) } | Sort-Object -Property PSIsContainer,Name

                    #Compute $Back - ensure we are not at the $script:Config.Path.Plugins
                    $Back = $Plugins.FullName -NotMatch [Regex]::Escape($Location.FullName)

                    # Get the next directory selection from the user, showing the back option if anywhere but the $script:Config.Path.Plugins
                    $Selection = Get-Menu -Title $Title -Choice $Choice -Back:$Back

                    # Get the selected $Location item
                    try {
                        $Location = Get-Item ("{0}\{1}" -f $Location.FullName,$Selection) -ErrorAction Stop
                    } catch {
                        Write-Warning 'Something went wrong, please try again'
                    }
                }

                # Format all the $Parameters to form to the selected $Location
                Format-Parameter -Location $Location

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
        } finally {
            # Set location back to original $SavedLocation
            Set-Location -Path $SavedLocation

            Write-Host "`nExiting..."
        }
    }
}

Power-Response
