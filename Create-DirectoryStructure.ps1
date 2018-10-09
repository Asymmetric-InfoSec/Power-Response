param (
    [String]$Path = $PSScriptRoot + '\Plugins',
    [Int]$DirectoryDepth = 3,
    [Switch]$Force,
    [Switch]$All
)

begin {
    function Get-Name {
        param(
            [Switch]$Symbol,
            [Switch]$Number,
            [Switch]$File,
            [Switch]$PowerShell
        )

        begin {
            $Words = Get-Verb | Select-Object -ExpandProperty Verb
            $Symbols = '.~!@#$%^&()-_+=' -Split '' | Where-Object { $PSItem }
            $Numbers = '0123456789' -Split '' | Where-Object { $PSItem }
            $Extensions = '|.ps1|.doc|.ppt|.psd1|.json' -Split '\|'
        }

        process {
            $Name = ''
            if ($Symbol) {
                $Name += $Symbols[(Get-Random -Maximum $Symbols.count)]
            } 
            if ($Number) {
                $Name += $Numbers[(Get-Random -Maximum $Numbers.count)]
            }
            $Name += $Words[(Get-Random -Maximum $Words.count)]

            if ($PowerShell) {
                $Name += '.ps1'
            } elseif ($File) {
                $Name += $Extensions[(Get-Random -Maximum $Extensions.count)]
            }

            return $Name
        }
    }

    function Get-PowerShellFunction {
        begin {
            $Functions = @(@'
param(
    [String]$Message
)
process {
    $PSBoundParameters
}
'@, @'
param (
    [Parameter(ParameterSetName='PSet1', Mandatory=$true)]
    [String]$ComputerName = 'Thing',
    [Int]$Iterations
)
process {
    $PSBoundParameters
}
'@, @'
param (
    [String]$StringParameter,
    [Int]$IntParameter,
    [Switch]$SwitchParameter,
    [PSObject]$ObjectParameter,
    [PSCredential]$CredentialParameter
)
process {
    $PSBoundParameters
}
'@)
        }
        
        process {
            return $Functions[$script:PoSHFunctionCount % $Functions.Count]
        }

        end {
            $script:PoSHFunctionCount++
        }
    }

    function New-DirectoryItems {
        param (
            [String]$Path,
            [Int]$Depth,
            [Int]$FinalDepth
        )

        begin {
            # Possible to get duplicate directory or file names with the random calls, ignore errors
            $OriginalErrorActionPreference = $ErrorActionPreference
            $ErrorActionPreference = 'SilentlyContinue'

            $Items = @()
            [System.Collections.ArrayList]$ItemType = @('Directory','File')
            
            # Create at least two well-formed directories if we are not at $FinalDepth
            if ($Depth -lt $FinalDepth) {
                for($i=0; $i -lt 2; $i++) {
                    try {
                        $ItemPath = New-Item -ItemType Directory -Path ("{0}\{1}" -f $Path, (Get-Name))  | Select-Object -ExpandProperty FullName
                        $Items += [PSCustomObject]@{ Path=$ItemPath; File=$False; PowerShell=$False; Symbol=$False; Number=$False }
                    } catch {}
                }
            } elseif ($Depth -eq $FinalDepth) {
                $ItemType.Remove('Directory')
            }

            # Create at least one well-formed PowerShell file per directory
            $ItemPath= New-Item -ItemType File -Path ("{0}\{1}" -f $Path, (Get-Name -PowerShell))
            $Items += [PSCustomObject]@{ Path=$ItemPath; File=$True; PowerShell=$True; Symbol=$False; Number=$False }
            Set-Content -Path $ItemPath -Value (Get-PowerShellFunction)
        }

        process {
            # If we have reached depth, nope out
            if ($Depth -gt $FinalDepth) {
                return
            }

            $ItemCount = Get-Random -Minimum 4 -Maximum 8
            for ($i=0; $i -lt $ItemCount; $i++) {
                $Type = $ItemType[(Get-Random -Maximum $ItemType.count)]
                [Boolean]$Symbol = Get-Random -Maximum 2
                [Boolean]$Number = Get-Random -Maximum 2
                $File = $Type -eq 'File'
                $PowerShell = $File -and !(Get-Random -Maximum 4)
                try {
                    $ItemPath = New-Item -ItemType $Type -Path ("{0}\{1}" -f $Path, (Get-Name -Symbol:$Symbol -Number:$Number -File:$File -PowerShell:$PowerShell)) | Select-Object -ExpandProperty FullName
                    
                    if ($PowerShell -and !$Symbol) {
                        Set-Content -Path $ItemPath -Value (Get-PowerShellFunction)
                    }

                    $Items += [PSCustomObject]@{ Path=$ItemPath; File=$File; PowerShell=$PowerShell; Symbol=$Symbol; Number=$Number }
                } catch {}
            }

            return $Items
        }

        end {
            # Recursively call this function with all directory paths created
            $Items | Where-Object { !$PSItem.File } | Foreach-Object { New-DirectoryItems -Path $PSItem.Path -Depth ($Depth+1) -FinalDepth $FinalDepth }

            # Restore the original $ErrorActionPreference
            $ErrorActionPreference = $OriginalErrorActionPreference
        }
    }    
}

process {
    if (!(Test-Path $Path)) {
        Write-Warning ('Path : {0} does not exist' -f $Path)
        return
    }

    if (!$Force) {
        Write-Warning ("This will erase all files and folders in the '{0}' directory" -f $Path)
        if((Read-Host 'Continue? (y/N)') -ne 'y') {
            return
        }
    }

    Get-ChildItem -Path $Path | Remove-Item -Recurse -Force

    $script:PoSHFunctionCount = 0

    $Items = New-DirectoryItems -Path $Path -Depth 0 -FinalDepth $DirectoryDepth

    if ($All) {
        $Items
    } else {
        $Items | Where-Object { $PSItem.PowerShell } | Select-Object Path
    }
}