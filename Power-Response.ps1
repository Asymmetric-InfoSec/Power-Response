[CmdletBinding()]
param(
    [String]$ConfigPath = ('{0}\Config.psd1' -f $PSScriptRoot),
    [String[]]$ComputerName
)

# UserInput class is designed to separate user input strings to successfully casted string type parameters
# Essentially acts like a string for our purposes
$UserInputType = [System.AppDomain]::CurrentDomain.GetAssemblies() | Foreach-Object { $PSItem.GetTypes() | Where-Object { $PSItem.Name -eq 'UserInput' } }
if (!$UserInputType) {
    Write-Log -Message 'Creating UserInput class'
    class UserInput {
        [String]$Value

        UserInput([String]$Value) {
            $this.Value = $Value
        }

        [String] ToString() {
            return $this.Value
        }
    }
}

function Format-Parameter {
    param (
        [String[]]$Arguments
    )

    process {
        # Gather to $global:PowerResponse.Location's $CommandParameters
        $CommandParameters = Get-Command -Name $global:PowerResponse.Location | Select-Object -ExpandProperty Parameters

        # If we are passed no $Arguments, assume full $Parameter format check
        if ($Arguments.Count -eq 0) {
            $Arguments = $CommandParameters.Keys
        }

        # Narrow the scope of $Arguments to the $CommandParameters that have a stored value in $global:PowerResponse.Parameters
        $Arguments = $Arguments | Where-Object { $CommandParameters.Keys -Contains $PSItem -and $global:PowerResponse.Parameters.$PSItem }

        # Foreach $CommandParam listed in $Arguments
        foreach ($CommandParam in $Arguments) {
            # Gather the $CommandParameter $ParameterType
            $ParameterType = $CommandParameters.$CommandParam.ParameterType

            # Gather the $global:PowerResponse.Parameters.$CommandParameter $ValueType
            $ValueType = $global:PowerResponse.Parameters.$CommandParam.GetType()

            # Initialize $Commands array and $ExpressionResult and $i
            [String[]]$Commands = @()
            $ExpressionResult = $null
            $i = 0

            # If we have a UserInput object, attempt expression and array expansion
            if ($ValueType.FullName -eq 'Power-Response.UserInput') {
                # Convert UserInput object to String for more complex casting
                $global:PowerResponse.Parameters.$CommandParam = $global:PowerResponse.Parameters.$CommandParam.ToString()

                # If the input value is not a file path, try to execute it as a PowerShell expression
                if (!(Test-Path $global:PowerResponse.Parameters.$CommandParam)) {
                    # Build a $Commands string to check for PowerShell expressions '[TYPE]($global:PowerResponse.Parameters.VALUE)'
                    $Commands += '[{0}]({1})' -f $ParameterType.FullName,$global:PowerResponse.Parameters.$CommandParam
                }

                # If we have an array $ParameterType and string $ValueType
                if ($ParameterType.BaseType.FullName -eq 'System.Array') {
                    # Build a $Commands string to check for array comma expansion '[TYPE]($global:PowerResponse.Parameters.VALUE -Split "\s*,\s*")'
                    $Commands += '[{0}]($global:PowerResponse.Parameters.$CommandParam -Split "\s*,\s*|\s+" | Where-Object {{ $PSItem }})' -f $ParameterType.FullName
                }
            }

            # Build a $Commands string to check for direct input typecasts '[TYPE]$global:PowerResponse.Parameters.VALUE'
            $Commands += '[{0}]$global:PowerResponse.Parameters.$CommandParam' -f $ParameterType.FullName

            # Loop while we haven't resolved a successful $ExpressionResult and we still have more $Commands to try
            do {
                # Try to evaluate the $Commands string
                try { $ExpressionResult = Invoke-Expression -Command $Commands[$i] } catch {}

                # Increment $i
                $i += 1
            } while (!$ExpressionResult -and $i -lt $Commands.Length)

            # If successful command execution
            if ($ExpressionResult) {
                # Set $global:PowerResponse.Parameters.$CommandParam to $ExpressionResult
                $global:PowerResponse.Parameters.$CommandParam = $ExpressionResult
            } else {
                # Determine if it was a casting or expression issue
                if ($ValueType.FullName -eq 'Power-Response.UserInput') {
                    $Warning = 'Parameter ''{0}'' removed: cannot interpret value ''{1}'' as a valid PowerShell expression. Have you tried using quotes?' -f $CommandParam,$global:PowerResponse.Parameters.$CommandParam
                } else {
                    $Warning = 'Parameter ''{0}'' removed: cannot convert value ''{1}'' to type ''{2}''. Have you tried using quotes?' -f $CommandParam,$global:PowerResponse.Parameters.$CommandParam,$CommandParameters.$CommandParam.ParameterType.Name
                }

                # Write an appropriate $Warning
                Write-Warning -Message $Warning

                # Write an appropriate log
                Write-Log -Message $Warning

                # Remove the $CommandParam key from $global:PowerResponse.Parameters
                $global:PowerResponse.Parameters.Remove($CommandParam) | Out-Null
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

            # Import the Config data file and bind it to the $Config variable
            Import-LocalizedData -BindingVariable 'Config' -BaseDirectory $File.PSParentPath -FileName $File.Name -ErrorAction Stop
        } catch {
            # Either intentionally threw an error on file absense, or Import-LocalizedData failed
            Write-Verbose ('Unable to import config on ''Path'': ''{0}''' -f $Path)
            $Config = $Default
        }

        # Check for unexpected values in Config file
        if ($RootKeys) {
            # Iterate through Config.Keys and keep any values not contained in expected $RootKeys 
            $UnexpectedRootKeys = $Config.Keys | Where-Object { $RootKeys -NotContains $PSItem }

            # If we found unexpected keys, print a warning message
            if ($UnexpectedRootKeys) {
                Write-Warning ('Discovered unexpected keys in config file ''{0}'':' -f $Path)
                Write-Warning ('    ''{0}''' -f ($UnexpectedRootKeys -Join ''', '''))
                Write-Warning  'Removing these values from the Config hashtable'

                # Remove any detected unexpected keys from $Config
                $UnexpectedRootKeys | % { $Config.Remove($PSItem) | Out-Null }
            }
        }

        # If no value is provided in the config file, set the default values
        if (!$Config.HashAlgorithm) {
            $Config.HashAlgorithm = $Default.HashAlgorithm
        }
        if (!$Config.OutputType) {
            $Config.OutputType = $Default.OutputType
        }
        if (!$Config.PromptText) {
            $Config.PromptText = $Default.PromptText
        }
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
        if (!$Config.HashAlgorithm -or !$Config.Path -or !$Config.UserName -or !$Config.Path.Bin -or !$Config.Path.Logs -or !$Config.Path.Output -or !$Config.Path.Plugins -or !$Config.UserName.Windows) {
            throw 'Missing required configuration value'
        }

        $global:PowerResponse.Config = $Config

        # Loop through $DirPath
        $global:PowerResponse.Regex = @{}
        foreach ($DirPath in $Config.Path.GetEnumerator()) {
            # If the $DirPath doesn't exist, create it and get rid of the output
            if (!(Test-Path $DirPath.Key)) {
                New-Item -Path $DirPath.Key -ItemType Directory | Out-Null
            }

            # Store each path as a regular expressions for string replacing later
            $global:PowerResponse.Regex.($DirPath.Key) = '^{0}' -f [Regex]::Escape($DirPath.Value -Replace ('{0}$' -f $DirPath.Key))
        }

        # Gather credentials for non-sessioned $UserName
        $global:PowerResponse.Credential = @{}
        foreach ($UserName in $Config.UserName.GetEnumerator()) {
            if ($UserName.Value -ne $ENV:UserName) {
                $global:PowerResponse.Credential.($UserName.Key) = Get-Credential -UserName $UserName.Value -Message ('Please enter {0} credentials' -f $UserName.Key)
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

function Invoke-ClearCommand {
    [Alias("Invoke-CLSCommand")]
    param (
        [String[]]$Arguments
    )

    process {
        # Clear the console
        [System.Console]::Clear()
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

        # If $global:PowerResponse.Location is a directory
        if ($global:PowerResponse.Location.PSIsContainer) {
            # Don't show 'back' or 'run' or 'clear' as command options
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
    param (
        [String[]]$Arguments
    )

    process {
        # If $Arguments are blank and we have selected a file $global:PowerResponse.Location
        if ($Arguments.Count -eq 0 -and !$global:PowerResponse.Location.PSIsContainer) {
            # Assume 'remove' all tracked command parameters
            $Arguments = Get-Command -Name $global:PowerResponse.Location | Select-Object -ExpandProperty Parameters | Select-Object -ExpandProperty Keys
        } elseif ($Arguments.Count -eq 0) {
            # Assume 'remove' all tracked $global:PowerResponse.Parameters
            $Arguments = $global:PowerResponse.Parameters | Select-Object -ExpandProperty Keys
        }

        # Filter $Arguments to remove invalid $global:PowerResponse.Parameters.Keys
        $Arguments = $Arguments | Where-Object { $global:PowerResponse.Parameters.Keys -Contains $PSItem }

        # If we have $Arguments to remove
        if ($Arguments.Count -ne 0) {
            # Remove $Arguments from $global:PowerResponse.Parameters
            $Arguments | Foreach-Object { $global:PowerResponse.Parameters.Remove($PSItem) | Out-Null }

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
        # If we have selected a file $global:PowerResponse.Location
        if ($global:PowerResponse.Location -and !$global:PowerResponse.Location.PSIsContainer) {
            Write-Host -Object ('Plugin Execution Started at {0}' -f (Get-Date))

            # Gather to $global:PowerResponse.Location's $CommandParameters
            $CommandParameters = Get-Command -Name $global:PowerResponse.Location | Select-Object -ExpandProperty Parameters

            # Initialize $ReleventParameters Hashtable
            $ReleventParameters = @{}

            # Parse the $ReleventParameters from $global:PowerResponse.Parameters
            $global:PowerResponse.Parameters.GetEnumerator() | Where-Object { $CommandParameters.Keys -Contains $PSItem.Key } | Foreach-Object { $ReleventParameters.($PSItem.Key) = $PSItem.Value }

            # Write execution log
            Write-Log -Message ('Began execution with Parameters: ''{0}''' -f ($ReleventParameters.Keys -Join ''', '''))

            # Set up $ComputerName array to run at least once
            $ComputerName = @('RUNONCE')

            # if a $ReleventParameters.ComputerName is tracked as a String[], cycle through the contained array
            if ($ReleventParameters.ComputerName -ne $null) {
                $ComputerName = $ReleventParameters.ComputerName
            }

            foreach ($Computer in $ComputerName) {
                if ($ReleventParameters.ComputerName -ne $null) {
                    # Force the current $Computer as the $ReleventParameters.ComputerName
                    $ReleventParameters.ComputerName = $Computer

                    # Format $Computer into $ComputerText for future $Message composition
                    $ComputerText = ' for {0}' -f $Computer
                } else {
                    # Format $Computer into $ComputerText as null for future $Message
                    $ComputerText = ''
                }

                # Set $global:PowerResponse.OutputPath for use in the plugin and Out-PRFile
                $global:PowerResponse.OutputPath = '{0}\{1:yyyy-MM-dd}\{2}' -f $global:PowerResponse.Config.Path.Output,$Date,$Computer

                try {
                    # Execute the $global:PowerResponse.Location with the $ReleventParameters
                    & $global:PowerResponse.Location.FullName @ReleventParameters | Out-PRFile

                    $Message = "Plugin Execution Succeeded{0}" -f $ComputerText

                    # Write execution success message
                    Write-Host -Object $Message
                    
                } catch {
                    # Format warning $Message
                    $Message = 'Plugin execution error{0}: {1}' -f $ComputerText,$PSItem
                    
                    # Write warning $Message to screen along with an admin
                    Write-Warning -Message ("{0}`nAre you running as admin?" -f $Message)
                }

                # Write execution $Message to log
                Write-Log -Message $Message

                # Clear $global:PowerResponse.OutputPath so legacy data doesn't stick around
                $global:PowerResponse.OutputPath = $null

            }
        } else {
            Write-Warning 'No plugin selected for execution. Press Enter to Continue.'
            Read-Host | Out-Null
            Invoke-ClearCommand
            break

        }

        # Write plugin execution completion message and verify with input prior to clearing
         Write-Host ("Plugin execution complete. Review status messages above or consult the Power-Response log.`r`nPress Enter to Continue Forensicating") -ForegroundColor Cyan -Backgroundcolor Black

        # Somewhat janky way of being able to have a message acknowledged and still have it show in color
         Read-Host | Out-Null

        # Clear screen once completion acknowledged
        Invoke-ClearCommand
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

        # Set the $global:PowerResponse.Parameters key and value specified by $Arguments
        $global:PowerResponse.Parameters.($Arguments[0]) = [UserInput](($Arguments | Select-Object -Skip 1) -Join ' ')

        # If we are provided a blank set command, remove the key from $global:PowerResponse.Parameters
        if ($global:PowerResponse.Parameters.($Arguments[0]) -eq '') {
            return Invoke-RemoveCommand -Arguments $Arguments
        }

        # Write a set parameter log
        Write-Log -Message ('Set Parameter: ''{0}'' = ''{1}''' -f $Arguments[0], $global:PowerResponse.Parameters.($Arguments[0]))

        # If we have a file $global:PowerResponse.Location, format the $global:PowerResponse.Parameters
        if (!$global:PowerResponse.Location.PSIsContainer) {
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
        # If we have selected a file $global:PowerResponse.Location
        if (!$global:PowerResponse.Location.PSIsContainer) {
            # Gather to $global:PowerResponse.Location's $CommandParameters
            $CommandParameters = Get-Command -Name $global:PowerResponse.Location | Select-Object -ExpandProperty Parameters

            # Filter $Arguments to remove invalid $CommandParameters.Keys
            $Arguments = $Arguments | Where-Object { $CommandParameters.Keys -Contains $PSItem }

            # If $Arguments array is empty
            if ($Arguments.Count -eq 0) {
                # List of $System scoped parameters
                $System = @('WarningAction','Debug','InformationAction','ErrorVariable','InformationVariable','WarningVariable','Verbose','ErrorAction','OutVariable','OutBuffer','PipelineVariable')

                # Get all $UserCommandParameters (non-system generated parameters)
                $UserCommandParameters = $CommandParameters.GetEnumerator() | Where-Object { $System -NotContains $PSItem.Key -or $global:PowerResponse.Parameters.($PSItem.Key) }

                # Set $Arguments to $UserCommandParameters.Key to return full list
                $Arguments = $UserCommandParameters.Key
            }
        } else {
            # Ensure $CommandParameters is blank
            $CommandParameters = @{}

            # If $Arguments array is empty
            if ($Arguments.Count -eq 0) {
                # Set $Arguments to all Keys of $global:PowerResponse.Parameters
                $Arguments = $global:PowerResponse.Parameters.Keys
            }
        }

        # Initialize empty $Param(eter) return HashTable
        $Param = @{}
        
        #For plugins with no parameters, write-host to run plugin
        if ($CommandParameters.Count -eq 0 -and !$global:PowerResponse.Location.PSIsContainer) {
            Write-Host "`r`nNo parameters detected. Type run to execute plugin."
        }
        elseif ($CommandParameters.Count -gt 0) {
            # Set $Param.[Type]$Key to the $global:PowerResponse.Parameters.$Key value
            $Arguments | Sort-Object | Foreach-Object { $Param.('[{0}]{1}' -f $CommandParameters.$PSItem.ParameterType.Name,$PSItem)=$global:PowerResponse.Parameters.$PSItem }
        } else {
            # Set $Param.$Key to the $global:PowerResponse.Parameters.$Key value
            $Arguments | Sort-Object | Foreach-Object { $Param.$PSItem=$global:PowerResponse.Parameters.$PSItem }
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

        # If no $Keyword is not provided or we have no $global:PowerResponse.Location and were provided a number return early
        if (!$Keyword -or ($global:PowerResponse.Location.PSIsContainer -and $Keyword -Match '^[0-9]$')) {
            return
        }

        # Try to execute function corresponding to command passed
        try {
            & ('Invoke-{0}Command' -f $Keyword) -Arguments $Arguments
        } catch {
            # Didn't understand keyword specified, write warning to screen
            Write-Warning ('Unknown Command ''{0}'', ''help'' prints a list of available commands' -f $Keyword)
            Write-Verbose $PSItem
        }
    }
}

function Out-PRFile {
    param (
        [Parameter(ValueFromPipeline=$true)]
        [PSObject]$InputObject,

        [ValidateSet('CSV','XML')]
        [String[]]$OutputType = $global:PowerResponse.Parameters.OutputType,

        [String]$Directory
    )

    begin {
        # Get UTC $Date
        $Date = (Get-Date).ToUniversalTime()

        # Create the destination file $Name: {UTC TIMESTAMP}_{PLUGIN}
        $Name = '{0:yyyy-MM-dd_HH-mm-ss-fff}_{1}' -f $Date, $global:PowerResponse.Location.BaseName.ToLower()

        # Set up $FullName based on $Directory and $Name
        $DirectoryPath = '{0}\{1}' -f $global:PowerResponse.OutputPath,$Directory

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

        # If the $Directory doesn't exist, create it
        if (!(Test-Path -Path $DirectoryPath)) {
            New-Item -Path $DirectoryPath -Type 'Directory' | Out-Null
        }

        try {
            # Initialize $Paths to empty array
            $Path = @()

            # Export the $Objects into specified format
            switch($OutputType) {
                'CSV' { $Objects | Export-Csv -NoTypeInformation -Path ('{0}\{1}.{2}' -f $DirectoryPath,$Name,$PSItem.ToLower()); $Path += ('{0}\{1}.{2}' -f $DirectoryPath,$Name,$PSItem.ToLower()) }
                'XML' { $Objects | Export-CliXml -Path ('{0}\{1}.{2}' -f $DirectoryPath,$Name,$PSItem.ToLower()); $Path += ('{0}\{1}.{2}' -f $DirectoryPath,$Name,$PSItem.ToLower()) }
                default { Write-Warning ('Unexpected Out-PRFile OutputType: {0}' -f $OutputType); exit }
            }
        } catch {
            # Caught error exporting $Objects
            $Message = '{0} output export error: {1}' -f ($OutputType -Join ','), $PSItem

            # Write output object export warning
            Write-Warning -Message $Message

            # Write output object export error log
            Write-Log -Message $Message

            # Remove the created $Path file
            Remove-Item -Force -Path $Path
        }

        Protect-PRFile -Path $Path
    }
}

function Protect-PRFile {
    param (
        [Parameter(Mandatory=$true,Position=0)]
        [String[]]$Path,

        [ValidateSet('SHA1','SHA256','SHA384','SHA512','MACTripleDES','MD5','RIPEMD160')]
        [String]$HashAlgorithm = $global:PowerResponse.Config.HashAlgorithm
    )

    process {
        # Make $Path items ReadOnly
        Set-ItemProperty -Path $Path -Name 'IsReadOnly' -Value $true -ErrorAction 'SilentlyContinue'

        # Write the new output file log with Hash for each entity in $Path
        Get-FileHash -Algorithm $HashAlgorithm -Path $Path -ErrorAction 'SilentlyContinue' | Foreach-Object {
            $Message = 'Protected file: ''{0}'' with {1} hash: ''{2}''' -f ($PSItem.Path -Replace $global:PowerResponse.Regex.Output), $PSItem.Algorithm, $PSItem.Hash

            # Write protection and integrity log
            Write-Log -Message $Message
        }
    }
}

function Read-PRHost {
    process {
        # Set up $Prompt text
        $Prompt = '{0}> ' -f $global:PowerResponse.Config.PromptText

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
        $LogPath = '{0}\{1:yyyy-MM-dd}.csv' -f $global:PowerResponse.Config.Path.Logs, $Date

        # Determine Plugin or Menu context
        if (!$global:PowerResponse.Location -or $global:PowerResponse.Location.PSIsContainer) {
            $Context = 'Menu'
        } else {
            $Context = $global:PowerResponse.Location.FullName -Replace $global:PowerResponse.Regex.Plugins
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

# $Banner for Power-Response
$Banner = @'
    ____                                ____                                      
   / __ \____ _      _____  _____      / __ \___  _________  ____  ____  ________ 
  / /_/ / __ \ | /| / / _ \/ ___/_____/ /_/ / _ \/ ___/ __ \/ __ \/ __ \/ ___/ _ \
 / ____/ /_/ / |/ |/ /  __/ /  /_____/ _, _/  __(__  ) /_/ / /_/ / / / (__  )  __/
/_/    \____/|__/|__/\___/_/        /_/ |_|\___/____/ .___/\____/_/ /_/____/\___/ 
                                                   /_/                            

Authors: Drew Schmitt | Matt Weikert | Gavin Prentice

'@

Write-Host $Banner

# Initialize $globalPowerResponse hashtable
$global:PowerResponse = @{}

# Import $global:PowerResponse.Config from data file
Import-Config

# Write a log to indicate framework startup
Write-Log -Message 'Began the Power-Response framework'

# Save the execution location
$SavedLocation = Get-Location

# Set the location to Bin folder to allow easy asset access
Set-Location -Path $global:PowerResponse.Config.Path.Bin

# Get the $Plugins directory item
$Plugins = Get-Item -Path $global:PowerResponse.Config.Path.Plugins

# Initialize the current $global:PowerResponse.Location to the $global:PowerResponse.Config.Path.Plugins directory item
$global:PowerResponse.Location = $Plugins

# Ensure we have at least one plugin installed
if (!(Get-ChildItem $global:PowerResponse.Location)) {
    Write-Error 'No Power-Response plugins detected'
    Read-Host 'Press Enter to Exit'
    exit
}

# Initialize tracked $global:PowerResponse.Parameters to $global:PowerResponse.Config data
$global:PowerResponse.Parameters = @{ OutputType = $global:PowerResponse.Config.OutputType; ComputerName = $ComputerName }

# If we have gathered a credential object from the Config, add it to the $global:PowerResponse.Parameters hashtable
if ($global:PowerResponse.Credential.Windows) {
    $global:PowerResponse.Parameters.Credential = $global:PowerResponse.Credential.Windows
}

# Trap 'exit's and Ctrl-C interrupts
try {
    # Loop through searching for a script file and setting parameters
    do {
        # While the $global:PowerResponse.Location is a directory
        while ($global:PowerResponse.Location.PSIsContainer) {
            # Compute $Title - Power-Response\CurrentPath
            $Title = $global:PowerResponse.Location.FullName -Replace $global:PowerResponse.Regex.Plugins

            # Compute $Choice - directories starting with alphanumeric character | files ending in .ps1
            $Choice = Get-ChildItem -Path $global:PowerResponse.Location.FullName | Where-Object { ($PSItem.PSIsContainer -and ($PSItem.Name -Match '^[A-Za-z0-9]')) -or (!$PSItem.PSIsContainer -and ($PSItem.Name -Match '\.ps1$')) } | Sort-Object -Property PSIsContainer,Name

            #Compute $Back - ensure we are not at the $global:PowerResponse.Config.Path.Plugins
            $Back = $Plugins.FullName -NotMatch [Regex]::Escape($global:PowerResponse.Location.FullName)

            # Get the next directory selection from the user, showing the back option if anywhere but the $global:PowerResponse.Config.Path.Plugins
            $Selection = Get-Menu -Title $Title -Choice $Choice -Back:$Back

            # Get the selected $global:PowerResponse.Location item
            try {
                $global:PowerResponse.Location = Get-Item ('{0}\{1}' -f $global:PowerResponse.Location.FullName,$Selection) -ErrorAction Stop
            } catch {
                Write-Warning 'Something went wrong, please try again'
            }
        }

        # Format all the $global:PowerResponse.Parameters to form to the selected $global:PowerResponse.Location
        Format-Parameter

        # Show all of the $global:PowerResponse.Parameters relevent to the selected $CommandParameters
        Invoke-ShowCommand

        # Until the user specifies to 'run' the program or go 'back', interpret $UserInput as commands
        do {
            # Get $UserInput
            $UserInput = Read-PRHost

            # Interpret $UserInput as a command and pass the $global:PowerResponse.Location
            if ($UserInput) {
                Invoke-PRCommand -UserInput $UserInput | Out-Default
            }
        } while (@('run','back','..') -NotContains $UserInput)

        # Set $global:PowerResponse.Location to the previous directory
        $global:PowerResponse.Location = Get-Item -Path ($global:PowerResponse.Location.FullName -Replace ('\\[^\\]+$'))
    } while ($True)
} finally {
    # Set location back to original $SavedLocation
    Set-Location -Path $SavedLocation

    # Write a log to indicate framework exit
    Write-Log -Message 'Exited the Power-Response framework'

    # Remove $global:PowerResponse hashtable
    Remove-Variable -Name 'PowerResponse' -Scope 'global'

    Write-Host "`nExiting..."
}
