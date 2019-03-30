[CmdletBinding()]
param(
    [String]$ConfigPath = ('{0}\Config.psd1' -f $PSScriptRoot),
    [String[]]$ComputerName = 'LOCALHOST',
    [PSCredential]$Credential
)

# $ErrorActionPreference of 'Stop' and $ProgressPreference of 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# UserInput class is designed to separate user input strings to successfully casted string type parameters
# Essentially acts like a string for our purposes
[Object[]]$UserInputType = [System.AppDomain]::CurrentDomain.GetAssemblies() | Foreach-Object { $PSItem.GetTypes() | Where-Object { $PSItem.Name -eq 'UserInput' } }
if ($UserInputType.Count -eq 0) {
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
        $CommandParameters = Get-Command -Name $global:PowerResponse.Location | Select-Object -ExpandProperty 'Parameters'

        # If $CommandParameters does not contain a 'ComputerName' entry
        if ($CommandParameters.Keys -NotContains 'ComputerName') {
            # Add a fake 'ComputerName' parameter to $CommandParameters
            $CommandParameters.Add('ComputerName',(New-Object -TypeName 'System.Management.Automation.ParameterMetadata' -ArgumentList 'ComputerName',([String[]])))
        }

        # If $CommandParameters does not contain a 'ComputerName' entry
        if ($CommandParameters.Keys -NotContains 'OutputType') {
            # Add a fake 'ComputerName' parameter to $CommandParameters
            $CommandParameters.Add('OutputType',(New-Object -TypeName 'System.Management.Automation.ParameterMetadata' -ArgumentList 'OutputType',([String[]])))
        }

        # If we are passed no $Arguments, assume full $Parameter format check
        if ($Arguments.Count -eq 0) {
            $Arguments = $CommandParameters.Keys
        }

        # Narrow the scope of $Arguments to the $CommandParameters that have a stored value in $global:PowerResponse.Parameters
        $Arguments = $Arguments | Where-Object { $CommandParameters.Keys -Contains $PSItem -and $global:PowerResponse.Parameters.$PSItem }

        # Foreach $CommandParam listed in $Arguments
        foreach ($CommandParam in $Arguments) {
            # Gather the $CommandParameters $ParameterType
            $ParameterType = $CommandParameters.$CommandParam.ParameterType

            # Gather the $global:PowerResponse.Parameters.$CommandParameter $ValueType
            $ValueType = $global:PowerResponse.Parameters.$CommandParam.GetType()

            # Initialize $Commands array and $ExpressionResult and $i
            [String[]]$Commands = @()
            $ExpressionResult = $null
            $i = 0

            # If we have a UserInput object, attempt expression and array expansion
            if ($ValueType.FullName -Like '*UserInput') {
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
                $null = $global:PowerResponse.Parameters.Remove($CommandParam)
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

function Get-OnlineComputer {
    param (
        [String[]]$ComputerName
    )

    process {
        # Initialize $OnlineComputers array
        $OnlineComputers = @()

        # Loop through tracked $global:PowerResponse.Parameters.ComputerName
        foreach ($Computer in $ComputerName) {
            # If the $ComputerName is online
            if (Test-Connection -ComputerName $Computer -Count 1 -Quiet) {
                # Add $ComputerName to $ReleventParameters.ComputerName
                $OnlineComputers += $Computer

                # Format the online $Message
                $Message = 'Machine: {0} is online and ready for processing' -f $Computer

                # Write the $Message to verbose
                Write-Verbose -Message $Message
            } else {
                # Format the offline $Message
                $Message = 'Skipping offline machine: {0}' -f $Computer

                # Write $Message to host
                Write-Host -Object $Message
            }

            # Write the $Message to log
            Write-Log -Message $Message
        }

        # Return $OnlineComputers array
        return $OnlineComputers
    }
}

function Import-Config {
    param (
        [String]$Path = ('{0}\Config.psd1' -f $PSScriptRoot),
        [String[]]$RootKeys
    )

    process {
        Write-Verbose 'Begin Import-Config'

        # Default 'Config' values
        $Default = @{
            AdminUserName = $ENV:UserName
            AutoAnalyze = $true
            AutoClear = $true
            HashAlgorithm = 'SHA256'
            OutputType = @('XML','CSV')
            PromptText = 'power-response'
            ThrottleLimit = 32

            # C:\Path\To\Power-Response\{FolderName}
            Path = @{
               Bin = '{0}\Bin' -f $PSScriptRoot
               Logs = '{0}\Logs' -f $PSScriptRoot
               Output = '{0}\Output' -f $PSScriptRoot
               Plugins = '{0}\Plugins' -f $PSScriptRoot
            }

            # Executing UserName
            PSSession = @{
                NoMachineProfile = $true
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
            Import-LocalizedData -BindingVariable 'Config' -BaseDirectory $File.PSParentPath -FileName $File.Name
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
                $null = $UnexpectedRootKeys | % { $Config.Remove($PSItem) }
            }
        }

        # If no value is provided in the config file, set the default values
        if (!$Config.AdminUserName) {
            $Config.AdminUserName = $Default.AdminUserName
        }
        if (!$Config.AutoAnalyze) {
            $Config.AutoAnalyze = $Default.AutoAnalyze
        }
        if (!$Config.AutoClear) {
            $Config.AutoClear = $Default.AutoClear
        }
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
        if (!$Config.PSSession) {
            $Config.PSSession = $Default.PSSession
        }
        if (!$Config.ThrottleLimit) {
            $Config.ThrottleLimit = $Default.ThrottleLimit
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

        if (!$Config.PSSession.NoMachineProfile) {
            $Config.PSSession.NoMachineProfile = $Default.PSSession.NoMachineProfile
        }

        # Check for required $Config value existence (sanity check - should never fail with default values)
        if (!$Config.AdminUserName -or !$Config.HashAlgorithm -or !$Config.Path -or !$Config.PSSession -or !$Config.Path.Bin -or !$Config.Path.Logs -or !$Config.Path.Output -or !$Config.Path.Plugins -or !$Config.PSSession.NoMachineProfile) {
            throw 'Missing required configuration value'
        }

        $global:PowerResponse.Config = $Config

        # Loop through $DirPath
        $global:PowerResponse.Regex = @{}
        foreach ($DirPath in $Config.Path.GetEnumerator()) {
            # If the $DirPath doesn't exist, create it and get rid of the output
            if (!(Test-Path $DirPath.Key)) {
                $null = New-Item -Path $DirPath.Key -ItemType 'Directory'
            }

            # Store each path as a regular expressions for string replacing later
            $global:PowerResponse.Regex.($DirPath.Key) = '^{0}' -f [Regex]::Escape($DirPath.Value -Replace ('{0}$' -f $DirPath.Key))
        }
    }
}

function Get-PRPath {
    [CmdletBinding(DefaultParameterSetName='Output-Specific')]
    param (
        [Parameter(ParameterSetName='Bin',Mandatory=$true)]
        [Switch]$Bin,

        [Parameter(ParameterSetName='Output',Mandatory=$true)]
        [Switch]$Output,

        [Parameter(ParameterSetName='Output-Specific',Mandatory=$true)]
        [String]$ComputerName,
        [Parameter(ParameterSetName='Output-Specific')]
        [String]$Directory
    )

    process {
        switch ($PSCmdlet.ParameterSetName) {
            'Bin' { $global:PowerResponse.Config.Bin }
            'Output' { $global:PowerResponse.Config.Path.Output }
            'Output-Specific' { '{0}\{1}\{2:yyyy-MM-dd}\{3}' -f $global:PowerResponse.Config.Path.Output,$ComputerName.ToUpper(),(Get-Date),$Directory -Replace '\\+','\' -Replace '\\$' }
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
            $Arguments = Get-Command -Name $global:PowerResponse.Location | Select-Object -ExpandProperty 'Parameters' | Select-Object -ExpandProperty 'Keys'
        } elseif ($Arguments.Count -eq 0) {
            # Assume 'remove' all tracked $global:PowerResponse.Parameters
            $Arguments = $global:PowerResponse.Parameters | Select-Object -ExpandProperty 'Keys'
        }

        # Filter $Arguments to remove invalid $global:PowerResponse.Parameters.Keys
        $Arguments = $Arguments | Where-Object { $global:PowerResponse.Parameters.Keys -Contains $PSItem }

        # If we have $Arguments to remove
        if ($Arguments.Count -ne 0) {
            # Remove $Arguments from $global:PowerResponse.Parameters
            $null = $Arguments | Foreach-Object { $global:PowerResponse.Parameters.Remove($PSItem) }

            # Write parameter removal log
            Write-Log ('Removed Parameter(s): ''{0}''' -f ($Arguments -Join ''', '''))
        }

        # If ComputerName parameter got removed
        if (!$global:PowerResponse.Parameters.ComputerName) {
            # Set it back to LOCALHOST
            $global:PowerResponse.Parameters.ComputerName = 'LOCALHOST'
        }

        # If OutputType parameter got removed
        if (!$global:PowerResponse.Parameters.OutputType) {
            # Set it back to the $global:PowerResponse.Config.OutputType
            $global:PowerResponse.Parameters.OutputType = $global:PowerResponse.Config.OutputType
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
        # Gather $OnlineComputers
        $OnlineComputers = Get-OnlineComputer -ComputerName $global:PowerResponse.Parameters.ComputerName

        # If we have selected a file $global:PowerResponse.Location
        if ($OnlineComputers -and $global:PowerResponse.Location -and !$global:PowerResponse.Location.PSIsContainer) {
            # Gather to $global:PowerResponse.Location's $CommandParameters
            $CommandParameters = Get-Command -Name $global:PowerResponse.Location | Select-Object -ExpandProperty 'Parameters'

            # Gather the $SessionOption from $global:PowerResponse.Config.PSSession
            $SessionOption = $global:PowerResponse.Config.PSSession

            # Gather $SessionParameters
            $SessionParameters = @{
                ComputerName = $OnlineComputers.ToUpper()
                ErrorAction = 'SilentlyContinue'
                Name = $OnlineComputers.ToUpper()
                SessionOption = New-PSSessionOption @SessionOption
            }

            # Add Credential parameter if we are tracking one
            if ($global:PowerResponse.Parameters.Credential) {
                $SessionParameters.Credential = $global:PowerResponse.Parameters.Credential
            }

            # Create the $Sessions array
            $Sessions = New-PSSession @SessionParameters

            # Write execution to host
            Write-Host -Object ('Plugin Execution Started at {0}' -f (Get-Date))

            # Write execution log
            Write-Log -Message ('Began execution with Parameters: ''{0}''' -f ($ReleventParameters.Keys -Join ''', '''))

            # If $CommandParameters doesn't contain 'Session'
            if ($CommandParameters.Keys -NotContains 'Session') {
                # Clear $Error log
                $Error.Clear()

                # Compile $InvokeCommandParameters HashTable
                $InvokeCommandParameters = @{
                    ArgumentList = $CommandParameters.Keys | Foreach-Object { $global:PowerResponse.Parameters.$PSItem }
                    AsJob = $true
                    FilePath = $global:PowerResponse.Location.FullName
                    JobName = $global:PowerResponse.Location.BaseName
                    Session = $Sessions
                    ThrottleLimit = $global:PowerResponse.Config.ThrottleLimit
                }

                try {
                    # Invoke the script file as a $Job with the $ArgumentList
                    $Job = Invoke-Command @InvokeCommandParameters
                } catch {
                    # Format remoting warning $Message
                    $Message = 'Plugin Job Creation Error: {0}' -f $PSItem

                    # Write warning $Message
                    Write-Warning -Message $Message

                    # Write log $Message
                    Write-Log -Message $Message
                }

                # If we successfully created the $Job
                if ($Job) {
                    # Wait for the $Job to complete
                    $null = Wait-Job -Job $Job

                    # Receive the $Results of the $Job and group them by PSComputerName
                    $Results = Receive-Job -Job $Job -ErrorAction 'SilentlyContinue' | Group-Object -Property 'PSComputerName'

                    # Loop through $Result groups
                    foreach ($Result in $Results) {
                        # Send each $Result to it's specific PR output file based on ComputerName
                        $Result.Group | Out-PRFile -ComputerName $Result.Name

                        # Format the remote execution success $Message
                        $Message = 'Plugin Execution Succeeded for {0}' -f $Result.Name

                        # Write host $Message
                        Write-Host -Object $Message

                        # Write log $Message
                        Write-Log -Message $Message
                    }

                    # Gather the $RemoteError
                    $RemoteErrors = $Error | Where-Object { $PSItem -is [System.Management.Automation.Runspaces.RemotingErrorRecord] }

                    foreach ($RemoteError in $RemoteErrors) {
                        # Format the remote error $Message
                        $Message = 'Plugin Execution Error for {0}: {1}' -f $RemoteError.OriginInfo.PSComputerName,$RemoteError.Exception

                        # Write warning $Message
                        Write-Warning -Message $Message

                        # Write log $Message
                        Write-Log -Message $Message
                    }

                    # Remove the $Job
                    Remove-Job -Job $Job
                }
            } else {
                # Initialize $ReleventParameters Hashtable
                $ReleventParameters = @{}

                # Parse the $ReleventParameters from $global:PowerResponse.Parameters
                $global:PowerResponse.Parameters.GetEnumerator() | Where-Object { $CommandParameters.Keys -Contains $PSItem.Key } | Foreach-Object { $ReleventParameters.($PSItem.Key) = $PSItem.Value }

                # Loop through tracked $Sessions
                foreach ($Session in $Sessions) {
                    # Set $ReleventParameters.Session to the current $Session
                    $ReleventParameters.Session = $Session

                    try {
                        # Execute the $global:PowerResponse.Location with the $ReleventParameters
                        & $global:PowerResponse.Location.FullName @ReleventParameters | Out-PRFile -ComputerName $Session.ComputerName

                        # Format host success $Message
                        $Message = 'Plugin Execution Succeeded for {0} at {1}' -f $Session.ComputerName, (Get-Date)

                        # Write execution success message
                        Write-Host -Object $Message
                    } catch {
                        # Format warning $Message
                        $Message = 'Plugin Execution Error for {0}: {1}' -f $Session.ComputerName,$PSItem

                        # Write warning $Message to screen along with some admin advice
                        Write-Warning -Message ("{0}`nAre you running as admin?" -f $Message)
                    }

                    # Write execution $Message to log
                    Write-Log -Message $Message
                }
            }

            # Compute $AnalysisPath
            $AnalysisPath = '{0}\Analysis\{1}' -f $global:PowerResponse.Config.Path.Plugins,($global:PowerResponse.Location.Name -Replace 'Collect-','Analyze-')

            # If auto execution of analysis plugins is set
            if ($global:PowerResponse.Config.AutoAnalyze -and $AnalysisPath -ne $global:PowerResponse.Location.FullName -and (Test-Path -Path $AnalysisPath)) {
                Write-Host -Object ('Analysis Plugin Execution Started at {0}' -f (Get-Date))

                # Gather to $AnalysisPath's $AnalysisParameters
                $AnalysisParameters = Get-Command -Name $AnalysisPath | Select-Object -ExpandProperty 'Parameters'

                # Initialize $AnalysisParametersParameters Hashtable
                $ReleventParameters = @{}

                # Parse the $AnalysisParameters from $global:PowerResponse.Parameters
                $global:PowerResponse.Parameters.GetEnumerator() | Where-Object { $AnalysisParameters.Keys -Contains $PSItem.Key } | Foreach-Object { $ReleventParameters.($PSItem.Key) = $PSItem.Value }

                try {
                    # Execute the plugin at $AnalysisPath
                    & $AnalysisPath @ReleventParameters | Out-PRFile -ComputerName $Session.ComputerName

                    # Format $Message
                    $Message = 'Automatically executed analysis plugin {0} for collection plugin {1}' -f $AnalysisPath,$global:PowerResponse.Location.FullName

                    # Write execution $Message to verbose stream
                    Write-Verbose -Message $Message

                } catch {
                    # Format warning $Message
                    $Message = 'Analysis plugin execution error for {0}: {1}' -f $Session.ComputerName,$PSItem

                    # Write warning $Message to screen
                    Write-Warning -Message $Message
                }

                # Write execution $Message to log
                Write-Log -Message $Message
            }

            # Protect any files that were copied to this particular $global:PowerResponse.OutputPath
            Protect-PRFile

            # Clean up the created $Sessions
            Remove-PSSession -Session $Sessions

            # Write plugin execution completion message and verify with input prior to clearing
             Write-Host -Object ('Plugin execution complete at {0}' -f (Get-Date))
        } elseif (!$OnlineComputers) {
            # Format all computers offline $Message
            $Message = 'All tracked computers are offline, skipping plugin execution'

            # Write warning $Message
            Write-Warning -Message $Message
        } else {
            # Write the warning for no plugin selected
            Write-Warning -Message 'No plugin selected for execution. Press Enter to Continue.'
        }

        if ($global:PowerResponse.Config.AutoClear) {
            # Prompt for message acknowledgment
            Write-Host -Object "Review status messages above or consult the Power-Response log.`r`nPress Enter to Continue Forensicating" -ForegroundColor 'Cyan' -Backgroundcolor 'Black'

            # Somewhat janky way of being able to have a message acknowledged and still have it show in color
            $null = Read-Host

            # Clear screen once completion acknowledged
            Invoke-ClearCommand
        }
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
        # Initialize $CommandParameters HashTable
        $CommandParameters = @{}

        # If we have selected a file $global:PowerResponse.Location
        if (!$global:PowerResponse.Location.PSIsContainer) {
            # Gather to $global:PowerResponse.Location's $CommandParameters
            $CommandParameters = Get-Command -Name $global:PowerResponse.Location | Select-Object -ExpandProperty 'Parameters'

            # If $CommandParameters does not contain a 'ComputerName' entry
            if ($CommandParameters.Keys -NotContains 'ComputerName') {
                # Add a fake 'ComputerName' parameter to $CommandParameters
                $CommandParameters.Add('ComputerName',(New-Object -TypeName 'System.Management.Automation.ParameterMetadata' -ArgumentList 'ComputerName',([String[]])))
            }

            # If $CommandParameters does not contain a 'ComputerName' entry
            if ($CommandParameters.Keys -NotContains 'OutputType') {
                # Add a fake 'ComputerName' parameter to $CommandParameters
                $CommandParameters.Add('OutputType',(New-Object -TypeName 'System.Management.Automation.ParameterMetadata' -ArgumentList 'OutputType',([String[]])))
            }

            # Filter $Arguments to remove invalid $CommandParameters.Keys
            $Arguments = $Arguments | Where-Object { $CommandParameters.Keys -Contains $PSItem }

            # If $Arguments array is empty
            if ($Arguments.Count -eq 0) {
                # Create stub cmdlet function to parse $System parameters
                function stub { [CmdletBinding()] param() process{} }

                # List of $System scoped parameters
                $System = Get-Command -Name 'stub' | Select-Object -ExpandProperty 'Parameters' | Select-Object -ExpandProperty 'Keys'

                # Set $Arguments to all non-$System keys of $global:PowerResponse.Parmeters
                $Arguments = $CommandParameters.GetEnumerator() | Where-Object { $System -NotContains $PSItem.Key -or $global:PowerResponse.Parameters.($PSItem.Key) } | Select-Object -ExpandProperty 'Key'
            }
        } elseif ($Arguments.Count -eq 0) {
            # Set $Arguments to all Keys of $global:PowerResponse.Parameters
            $Arguments = $global:PowerResponse.Parameters.Keys
        }

        # If we weren't provided specific $Arguments and $Arguments doesn't contain ComputerName
        if (!$PSBoundParameters.Arguments -and $Arguments -NotContains 'ComputerName') {
            # Add 'ComputerName' to the front of the list
            $Arguments = @('ComputerName') + $Arguments
        }

        # If we weren't provided specific $Arguments and $Arguments doesn't contain OutputType
        if (!$PSBoundParameters.Arguments -and $Arguments -NotContains 'OutputType') {
            # Add 'OutputType' to the end of the list
            $Arguments = $Arguments + @('OutputType')
        }

        # Initialize empty $Param(eter) return HashTable
        $Param = @{}

        # For plugins with no parameters, write-host to run plugin
        if ($CommandParameters.Count -gt 0) {
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
        if (!$Keyword -or ($global:PowerResponse.Location.PSIsContainer -and $Keyword -Match '^[0-9]+$')) {
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
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [PSObject]$InputObject,

        [Parameter(Mandatory=$true)]
        [String]$ComputerName,

        [ValidateSet('CSV','XML')]
        [String[]]$OutputType = $global:PowerResponse.Parameters.OutputType,

        [String]$Directory,

        [String]$Append
    )

    begin {
        # Get UTC $Date
        $Date = (Get-Date).ToUniversalTime()

        # Create the destination file $Name: {UTC TIMESTAMP}_{PLUGIN}_{APPEND}
        $Name = ('{0:yyyy-MM-dd_HH-mm-ss-fff}_{1}_{2}' -f $Date, $global:PowerResponse.Location.BaseName.ToLower(),$Append) -Replace '_$'

        # Set up $FullName based on $Directory and $Name
        $OutputPath = Get-PROutputPath -ComputerName $ComputerName -Directory $Directory

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
        if (!(Test-Path -Path $OutputPath)) {
            $null = New-Item -Path $OutputPath -Type 'Directory'
        }

        try {
            # Initialize $Paths to empty array
            $Path = @()

            # Export the $Objects into specified format
            switch($OutputType) {
                'CSV' { $Objects | Export-Csv -Path ('{0}\{1}.{2}' -f $OutputPath,$Name,$PSItem.ToLower()); $Path += ('{0}\{1}.{2}' -f $OutputPath,$Name,$PSItem.ToLower()) }
                'XML' { $Objects | Export-CliXml -Path ('{0}\{1}.{2}' -f $OutputPath,$Name,$PSItem.ToLower()); $Path += ('{0}\{1}.{2}' -f $OutputPath,$Name,$PSItem.ToLower()) }
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

        # Protect the newly created output files
        Protect-PRFile -Path $Path
    }
}

function Protect-PRFile {
    param (
        [Parameter(Position=0)]
        [String[]]$Path = (Get-ChildItem -File -Recurse -Attributes '!ReadOnly' -Path $global:PowerResponse.Config.Path.Output -ErrorAction 'SilentlyContinue' | Select-Object -ExpandProperty 'FullName'),

        [ValidateSet('SHA1','SHA256','SHA384','SHA512','MACTripleDES','MD5','RIPEMD160')]
        [String]$HashAlgorithm = $global:PowerResponse.Config.HashAlgorithm
    )

    process {
        foreach ($File in $Path) {
            try {
                # Make $Path items ReadOnly
                Set-ItemProperty -Path $File -Name 'IsReadOnly' -Value $true -ErrorAction 'Stop'

                # Write the new output file log with Hash for each entity in $Path
                Get-FileHash -Algorithm $HashAlgorithm -Path $File -ErrorAction 'Stop' | Foreach-Object {
                    $Message = 'Protected file: ''{0}'' with {1} hash: ''{2}''' -f ($PSItem.Path -Replace $global:PowerResponse.Regex.Output), $PSItem.Algorithm, $PSItem.Hash

                    # Write protection and integrity log
                    Write-Log -Message $Message
                }
            } catch {
                # Format the warning $Message
                $Message = 'Encountered error protecting file ''{0}'': {1}' -f $File,$PSItem

                # Print the warning $Message
                Write-Warning -Message $Message

                # Write the log $Message
                Write-Log -Message $Message
            }
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

# Initialize $global:PowerResponse hashtable
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
$global:PowerResponse.Parameters = @{
    ComputerName = $ComputerName
    Credential = $Credential
    OutputType = $global:PowerResponse.Config.OutputType
}

# If we have have a executing-admin user name mismatch, gather the credential object and store it in the $global:PowerResponse.Parameters hashtable
if ($ENV:UserName -ne $global:PowerResponse.Config.AdminUserName -and $Credential.UserName -ne $global:PowerResponse.Config.AdminUserName) {
    $global:PowerResponse.Parameters.Credential = Get-Credential -UserName $global:PowerResponse.Config.AdminUserName -Message 'Enter administrative credentials'
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
            $Choice = Get-ChildItem -Path $global:PowerResponse.Location.FullName | Where-Object { ($PSItem.PSIsContainer -and ($PSItem.Name -Match '^[A-Za-z0-9]')) -or (!$PSItem.PSIsContainer -and ($PSItem.Name -Match '\.ps1$')) } | Sort-Object -Property 'PSIsContainer','Name'

            #Compute $Back - ensure we are not at the $global:PowerResponse.Config.Path.Plugins
            $Back = $Plugins.FullName -NotMatch [Regex]::Escape($global:PowerResponse.Location.FullName)

            # Get the next directory selection from the user, showing the back option if anywhere but the $global:PowerResponse.Config.Path.Plugins
            $Selection = Get-Menu -Title $Title -Choice $Choice -Back:$Back

            # Get the selected $global:PowerResponse.Location item
            try {
                $global:PowerResponse.Location = Get-Item (('{0}\{1}' -f $global:PowerResponse.Location.FullName,$Selection) -Replace '\\$')
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
        $global:PowerResponse.Location = Get-Item -Path ($global:PowerResponse.Location.FullName -Replace '\\[^\\]*$')
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
