function Format-Parameter {
    param (
        [String[]]$Arguments
    )

    process {
        # Gather to $script:Location's $CommandParameters
        $CommandParameters = Get-Command -Name $script:Location | Select-Object -ExpandProperty Parameters

        # If we are passed no $Arguments, assume full $Parameter format check
        if ($Arguments.Count -eq 0) {
            $Arguments = $CommandParameters.Keys
        }

        # Narrow the scope of $Arguments to the $CommandParameters that have a stored value in $script:Parameters
        $Arguments = $Arguments | Where-Object { $CommandParameters.Keys -Contains $PSItem -and $script:Parameters.$PSItem }

        # Foreach $CommandParam listed in $Arguments
        foreach ($CommandParam in $Arguments) {
            # Gather the $CommandParameter $ParameterType
            $ParameterType = $CommandParameters.$CommandParam.ParameterType.FullName

            # Gather the $script:Parameters.$CommandParameter $ValueType
            $ValueType = $script:Parameters.$CommandParam.GetType().FullName

            # Ignore string $ParameterType with an existing string $script:Parameters.CommandParam value
            if ($ParameterType -ne $ValueType -and !($ParameterType -Match '\[\]$' -and $ValueType -eq 'System.Object[]')) {
                # Build the $Command string '[TYPE]($script:Parameters.VALUE)'
                $Command = '[{0}]({1})' -f $ParameterType,$script:Parameters.$CommandParam
                try {
                    # Try to interpret the $Command expression and store it back to $script:Parameters.$CommandParam
                    $script:Parameters.$CommandParam = Invoke-Expression -Command $Command
                } catch {
                    # Failed to interpret the $Command expression, determine if it was a casting or expression issue
                    if ($Error[0] -and $Error[0].FullyQualifiedErrorId -eq 'ConvertToFinalInvalidCastException') {
                        $Warning = 'Parameter ''{0}'' removed: cannot convert value ''{1}'' to type ''{2}''. Have you tried using quotes?' -f $CommandParam,$script:Parameters.$CommandParam,$CommandParameters.$CommandParam.ParameterType.Name
                    } else {
                        $Warning = 'Parameter ''{0}'' removed: cannot interpret value ''{1}'' as a valid PowerShell expression. Have you tried using quotes?' -f $CommandParam,$script:Parameters.$CommandParam
                    }

                    # Write an appropriate $Warning
                    Write-Warning $Warning

                    # Write an appropriate log
                    Write-Log -Message $Warning

                    # remove the $CommandParam key from $script:Parameters
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
                $Line = '[{0}] - {1}' -f $i,$Choice[$i]

                Write-Host $Line
            }

            # Write an extra line for formatting
            Write-Host ''

            # Get $UserInput
            $UserInput = Read-PRHost

            # Try to interpret the $UserInput as a command
            if ($UserInput) {
                Invoke-PRCommand -UserInput $UserInput | Out-Default
            }
        } while (!$UserInput -or (0..($Choice.Length-1)) -NotContains $UserInput)

        return $Choice[$UserInput]
    }
}

function Import-Config {
    param (
        [String]$Path = ('{0}\Config.psd1' -f $PSScriptRoot),
        [String[]]$RootKeys = @('HashAlgorithm', 'OutputType', 'PromptText', 'Path', 'UserName')
    )

    process {
        Write-Verbose 'Begin Get-ConfigData'

        # Default 'Config' values
        $Default = @{
            HashAlgorithm = 'SHA256'
            OutputType = @('XML','CSV')
            PromptText = 'power-response'

            # C:\Path\To\Power-Response\{FolderName}
            Path = @{
               Bin = '{0}\Bin' -f $PSScriptRoot
               Logs = '{0}\Logs' -f $PSScriptRoot
               Output = '{0}\Output' -f $PSScriptRoot
               Plugins = '{0}\Plugins' -f $PSScriptRoot
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
            Import-LocalizedData -BindingVariable script:Config -BaseDirectory $File.PSParentPath -FileName $File.Name -ErrorAction Stop
        } catch {
            # Either intentionally threw an error on file absense, or Import-LocalizedData failed
            Write-Verbose ('Unable to import config on ''Path'': ''{0}''' -f $Path)
            $script:Config = $Default
        }

        # Check for unexpected values in Config file
        if ($RootKeys) {
            # Iterate through Config.Keys and keep any values not contained in expected $RootKeys 
            $UnexpectedRootKeys = $script:Config.Keys | Where-Object { $RootKeys -NotContains $PSItem }

            # If we found unexpected keys, print a warning message
            if ($UnexpectedRootKeys) {
                Write-Warning ('Discovered unexpected keys in config file ''{0}'':' -f $Path)
                Write-Warning ('    ''{0}''' -f ($UnexpectedRootKeys -Join ''', '''))
                Write-Warning  'Removing these values from the Config hashtable'

                # Remove any detected unexpected keys from $script:Config
                $UnexpectedRootKeys | % { $script:Config.Remove($PSItem) | Out-Null }
            }
        }

        # If no value is provided in the config file, set the default values
        if (!$script:Config.HashAlgorithm) {
            $script:Config.HashAlgorithm = $Default.HashAlgorithm
        }
        if (!$script:Config.OutputType) {
            $script:Config.OutputType = $Default.OutputType
        }
        if (!$script:Config.PromptText) {
            $script:Config.PromptText = $Default.PromptText
        }
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
        if (!$script:Config.HashAlgorithm -or !$script:Config.Path -or !$script:Config.UserName -or !$script:Config.Path.Bin -or !$script:Config.Path.Logs -or !$script:Config.Path.Output -or !$script:Config.Path.Plugins -or !$script:Config.UserName.Windows) {
            throw 'Missing required configuration value'
        }

        # Loop through $DirPath
        $script:Regex = @{}
        foreach ($DirPath in $script:Config.Path.GetEnumerator()) {
            # If the $DirPath doesn't exist, create it and get rid of the output
            if (!(Test-Path $DirPath.Key)) {
                New-Item -Path $DirPath.Key -ItemType Directory | Out-Null
            }

            # Store each path as a regular expressions for string replacing later
            $script:Regex.($DirPath.Key) = '^{0}' -f [Regex]::Escape($DirPath.Value -Replace ('{0}$' -f $DirPath.Key))
        }

        # Gather credentials for non-sessioned $UserName
        $script:Credential = @{}
        foreach ($UserName in $script:Config.UserName.GetEnumerator()) {
            if ($UserName.Value -ne $ENV:UserName) {
                $script:Credential.($UserName.Key) = Get-Credential -UserName $UserName.Value -Message ('Please enter {0} credentials' -f $UserName.Key)
            }
        }
    }
}

function Invoke-BackCommand {
    [Alias('Invoke-..Command')]
    param (
        [String[]]$Arguments
    )
    process {
        Write-Host 'Going back...'
    }
}

function Invoke-ExitCommand {
    [Alias('Invoke-QuitCommand')]
    param (
        [String[]]$Arguments
    )
    process {
        exit
    }
}

function Invoke-HelpCommand {
    [Alias('Invoke-?Command')]
    param (
        [String[]]$Arguments
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
            @{ Name='clear'; Usage='clear'; Description='clears the screen of clutter while running plugins' }
        ) | Foreach-Object { [PSCustomObject]$PSItem }

        # If $script:Location is a directory
        if ($script:Location.PSIsContainer) {
            # Don't show 'back' or 'run' or 'clear' as command options
            $Commands = $Commands | Where-Object { @('back','run', 'clear') -NotContains $PSItem.Name }
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
    param (
        [String[]]$Arguments
    )

    process {
        # If $Arguments are blank and we have selected a file $script:Location
        if ($Arguments.Count -eq 0 -and !$script:Location.PSIsContainer) {
            # Assume 'remove' all tracked command parameters
            $Arguments = Get-Command -Name $script:Location | Select-Object -ExpandProperty Parameters | Select-Object -ExpandProperty Keys
        } elseif ($Arguments.Count -eq 0) {
            # Assume 'remove' all tracked $script:Parameters
            $Arguments = $script:Parameters | Select-Object -ExpandProperty Keys
        }

        # Filter $Arguments to remove invalid $script:Parameters.Keys
        $Arguments = $Arguments | Where-Object { $script:Parameters.Keys -Contains $PSItem }

        # If we have $Arguments to remove
        if ($Arguments.Count -ne 0) {
            # Remove $Arguments from $script:Parameters
            $Arguments | Foreach-Object { $script:Parameters.Remove($PSItem) | Out-Null }

            # Write parameter removal log
            Write-Log ('Removed Parameter(s): ''{0}''' -f ($Arguments -Join ''', '''))
        }

        # Show the new parameter list
        Invoke-ShowCommand
    }
}

function Invoke-RunCommand {
    param (
        [String[]]$Arguments
    )

    process {
        # If we have selected a file $script:Location
        if ($script:Location -and !$script:Location.PSIsContainer) {
            # Gather to $script:Location's $CommandParameters
            $CommandParameters = Get-Command -Name $script:Location | Select-Object -ExpandProperty Parameters

            # Initialize $ReleventParameters Hashtable
            $ReleventParameters = @{}

            # Parse the $ReleventParameters from $script:Parameters
            $script:Parameters.GetEnumerator() | Where-Object { $CommandParameters.Keys -Contains $PSItem.Key } | Foreach-Object { $ReleventParameters.($PSItem.Key) = $PSItem.Value }

            # Initialize $OutputParameters Hashtable
            $OutputParameters = @{}

            # Parse the $OutputParameters from $script:Parameters
            $script:Parameters.GetEnumerator() | Where-Object { @('OutputType') -Contains $PSItem.Key } | Foreach-Object { $OutputParameters.($PSItem.Key) = $PSItem.Value }

            # Write execution log
            Write-Log -Message ('Began execution with Parameters: ''{0}''' -f ($ReleventParameters.Keys -Join ''', '''))

            try {
                # Execute the $script:Location with the $ReleventParameters
                & $script:Location.FullName @ReleventParameters | Out-PRFile @OutputParameters

                # Write execution success log
                Write-Log -Message 'Plugin execution succeeded'
            } catch {
                Write-Warning ('Plugin execution error: {0}' -f $PSItem)

                # Write execution error log
                Write-Log -Message ('Plugin execution error: {0}' -f $PSItem)
            }
        } else {
            Write-Warning 'No plugin selected for execution'
        }
    }
}

function Invoke-ClearCommand {
   param (
        [String[]]$Arguments
    )

    process {
        
        [System.Console]::Clear()
    }

}

function Invoke-SetCommand {
    param (
        [String[]]$Arguments
    )

    process {
        # Set command requires a parameter as an argument
        if ($Arguments.Count -lt 1) {
            Write-Warning 'Improper ''set'' command usage'
            return Invoke-HelpCommand -Arguments 'set'
        }

        # Set the $script:Parameters key and value specified by $Arguments
        $script:Parameters.($Arguments[0]) = ($Arguments | Select-Object -Skip 1) -Join ' '

        # If we are provided a blank set command, remove the key from $script:Parameters
        if ($script:Parameters.($Arguments[0]) -eq '') {
            return Invoke-RemoveCommand -Arguments $Arguments
        }

        # Write a set parameter log
        Write-Log -Message ('Set Parameter: ''{0}'' = ''{1}''' -f $Arguments[0], $script:Parameters.($Arguments[0]))

        # If we have a file $script:Location, format the $script:Parameters
        if (!$script:Location.PSIsContainer) {
            Format-Parameter -Arguments $Arguments[0]
        }

        # Show the newly set value
        return Invoke-ShowCommand -Arguments $Arguments[0]
    }
}

function Invoke-ShowCommand {
    param (
        [String[]]$Arguments
    )

    process {
        # If we have selected a file $script:Location
        if (!$script:Location.PSIsContainer) {
            # Gather to $script:Location's $CommandParameters
            $CommandParameters = Get-Command -Name $script:Location | Select-Object -ExpandProperty Parameters

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
                # Set $Arguments to all Keys of $script:Parameters
                $Arguments = $script:Parameters.Keys
            }
        }

        # Initialize empty $Param(eter) return HashTable
        $Param = @{}
        
        #For plugins with no parameters, write-host to run plugin
        if ($CommandParameters.Count -eq 0 -and !$script:Location.PSIsContainer) {
            Write-Host "`r`nNo parameters detected. Type run to execute plugin."
        }
        elseif ($CommandParameters.Count -gt 0) {
            # Set $Param.[Type]$Key to the $script:Parameters.$Key value
            $Arguments | Sort-Object | Foreach-Object { $Param.('[{0}]{1}' -f $CommandParameters.$PSItem.ParameterType.Name,$PSItem)=$script:Parameters.$PSItem }
        } else {
            # Set $Param.$Key to the $script:Parameters.$Key value
            $Arguments | Sort-Object | Foreach-Object { $Param.$PSItem=$script:Parameters.$PSItem }
        }

        # Cast the HashTable to a PSCustomObject and format as an alphabetical-order list object
        return [PSCustomObject]$Param | Format-List
    }
}

function Invoke-PRCommand {
    param (
        [String]$UserInput
    )

    process {
        # $Keyword will be the first word of the user input
        $Keyword = $UserInput -Split ' ' | Select-Object -First 1

        # $Arguments will be any following words
        $Arguments = $UserInput -Split ' ' | Select-Object -Skip 1

        # If no $Keyword is not provided or we have no $script:Location and were provided a number return early
        if (!$Keyword -or ($script:Location.PSIsContainer -and $Keyword -Match '^[0-9]$')) {
            return
        }

        # Try to execute function corresponding to command passed
        try {
            & ('Invoke-{0}Command' -f $Keyword) -Arguments $Arguments
        } catch {
            # Didn't understand keyword specified, write warning to screen
            Write-Warning ('Unknown Command ''{0}'', ''help'' prints a list of available commands' -f $Keyword)
        }
    }
}

function Out-PRFile {
    param (
        [Parameter(ValueFromPipeline=$true)]
        [PSObject]$InputObject,

        [ValidateSet('CSV','XML')]
        [String[]]$OutputType = $script:Config.OutputType
    )

    begin {
        # Get UTC $Date
        $Date = (Get-Date).ToUniversalTime()

        # Create the destination file $BaseName: {UTC TIMESTAMP}_{PLUGIN}
        $BaseName = '{0:yyyy-MM-dd_HH-mm-ss-fff}_{1}' -f $Date, $script:Location.BaseName.ToLower()

        # Set up $Path based on $BaseName and $OutputType
        $Path = '{0}\{1}' -f $script:Config.Path.Output, $BaseName

        # Initialize $Objects array for pipeline handling
        $Objects = @()
    }

    process {
        $Objects += $InputObject
    }

    end {
        if ($Objects.Count -eq 0) {
            # Return early if there is no output data
            return
        }

        try {
            # Initialize $Paths to empty array
            $Paths = @()

            # Export the $Objects into specified format
            switch($OutputType) {
                'CSV' { $Objects | Export-Csv -NoTypeInformation -Path ('{0}.{1}' -f $Path, $PSItem.ToLower()); $Paths += ('{0}.{1}' -f $Path, $PSItem.ToLower()) }
                'XML' { $Objects | Export-CliXml -Path ('{0}.{1}' -f $Path, $PSItem.ToLower()); $Paths += ('{0}.{1}' -f $Path, $PSItem.ToLower()) }
                default { Write-Warning ('Unexpected Out-PRFile OutputType: {0}' -f $OutputType); exit }
            }
        } catch {
            # Caught error exporting $Objects
            Write-Warning ('{0} output export error: {1}' -f ($OutputType -Join ','), $PSItem)

            # Write output object export error log
            Write-Log -Message ('{0} output export error: {1}' -f ($OutputType -Join ','), $PSItem)

            # Remove the created $Path file
            Remove-Item -Force -Path $Path

            # Return early on error
            return
        }

        # Make the $Paths ReadOnly
        Set-ItemProperty -Path $Paths -Name 'IsReadOnly' -Value $true

        # Write the new output file log with Hash for each entity in $Paths
        Get-FileHash -Algorithm $script:Config.HashAlgorithm -Path $Paths | Foreach-Object { Write-Log -Message ('Created output file: ''{0}'' with {1} hash: ''{2}''' -f ($PSItem.Path -Replace $script:Regex.Output), $PSItem.Algorithm, $PSItem.Hash) }
    }
}

function Read-PRHost {
    process {
        # Set up $Prompt text
        $Prompt = '{0}> ' -f $script:Config.PromptText

        # Write the $Prompt to the host
        Write-Host $Prompt -NoNewLine

        # Return the line entered by the user
        return $Host.UI.ReadLine()
    }
}

function Write-Log {
    param (
        [Parameter(Mandatory=$true)]
        [String]$Message
    )

    process {
        # Get UTC $Date
        $Date = (Get-Date).ToUniversalTime()

        # Build the $LogPath
        $LogPath = '{0}\{1:yyyy-MM-dd}.csv' -f $script:Config.Path.Logs, $Date

        # Determine Plugin or Menu context
        if (!$script:Location -or $script:Location.PSIsContainer) {
            $Context = 'Menu'
        } else {
            $Context = $script:Location.FullName -Replace $script:Regex.Plugins
        }

        # Build $LogLine
        $LogLine = [PSCustomObject]@{
            Date = '{0:u}' -f $Date
            UserName = $ENV:UserName
            Context = $Context
            Message = $Message
        }

        $LogLine | Export-Csv -NoTypeInformation -Append -Path $LogPath
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

        # Write a log to indicate framework startup
        Write-Log -Message 'Began the Power-Response framework'

        # Save the execution location
        $SavedLocation = Get-Location

        # Set the location to Bin folder to allow easy asset access
        Set-Location $script:Config.Path.Bin

        # Get the $Plugins directory item
        $Plugins = Get-Item -Path $script:Config.Path.Plugins

        # Initialize the current $script:Location to the $script:Config.Path.Plugins directory item
        $script:Location = $Plugins

        # Ensure we have at least one plugin installed
        if (!(Get-ChildItem $script:Location)) {
            Write-Error 'No Power-Response plugins detected'
            Read-Host 'Press Enter to Exit'
            exit
        }

        # Initialize tracked $script:Parameters to $script:Config data
        $script:Parameters = @{ OutputType = $script:Config.OutputType }

        # Trap 'exit's and Ctrl-C interrupts
        try {
            # Loop through searching for a script file and setting parameters
            do {
                # While the $script:Location is a directory
                while ($script:Location.PSIsContainer) {
                    # Compute $Title - Power-Response\CurrentPath
                    $Title = $script:Location.FullName -Replace $script:Regex.Plugins

                    # Compute $Choice - directories starting with alphanumeric character | files ending in .ps1
                    $Choice = Get-ChildItem -Path $script:Location.FullName | Where-Object { ($PSItem.PSIsContainer -and ($PSItem.Name -Match '^[A-Za-z0-9]')) -or (!$PSItem.PSIsContainer -and ($PSItem.Name -Match '\.ps1$')) } | Sort-Object -Property PSIsContainer,Name

                    #Compute $Back - ensure we are not at the $script:Config.Path.Plugins
                    $Back = $Plugins.FullName -NotMatch [Regex]::Escape($script:Location.FullName)

                    # Get the next directory selection from the user, showing the back option if anywhere but the $script:Config.Path.Plugins
                    $Selection = Get-Menu -Title $Title -Choice $Choice -Back:$Back

                    # Get the selected $script:Location item
                    try {
                        $script:Location = Get-Item ('{0}\{1}' -f $script:Location.FullName,$Selection) -ErrorAction Stop
                    } catch {
                        Write-Warning 'Something went wrong, please try again'
                    }
                }

                #Clear $error.count for future validation 
                $Error.Clear()

                # Format all the $script:Parameters to form to the selected $script:Location
                Format-Parameter

                # Show all of the $script:Parameters relevent to the selected $CommandParameters
                Invoke-ShowCommand

                # Until the user specifies to 'run' the program or go 'back', interpret $UserInput as commands
                do {
                    # Get $UserInput
                    $UserInput = Read-PRHost

                    # Interpret $UserInput as a command and pass the $script:Location
                    if ($UserInput -Contains 'run') {
                        Write-Host 'Executing Plugin, please wait...'
                        Invoke-PRCommand -UserInput $UserInput | Out-Default
                    } elseif ($UserInput) {
                        Invoke-PRCommand -UserInput $UserInput | Out-Default
                    }
                } while (@('run','back') -NotContains $UserInput)

                #Confirm plugin execution complete. If errors, wait for user confirmation prior to continuing

                if ($Error.Count -eq 0 -and $UserInput -ne "back") {
                    Write-Host "The plugin has executed successfully. Go forth and forensicate!"
                    Start-Sleep -s 2
                    Invoke-ClearCommand
                } elseif ($Error.Count -gt 0 -and $UserInput -ne "back"){
                    Read-Host "`r`nThe plugin has executed with errors. Review the errors and press Enter to continue"
                    Invoke-ClearCommand
                }
                
                # Set $script:Location to the previous directory
                $script:Location = Get-Item -Path ($script:Location.FullName -Replace ('\\[^\\]+$'))
            } while ($True)
        } finally {
            # Set location back to original $SavedLocation
            Set-Location -Path $SavedLocation

            # Write a log to indicate framework exit
            Write-Log -Message 'Exited the Power-Response framework'

            Write-Host "`nExiting..."
        }
    }
}

Power-Response
