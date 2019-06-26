param (
    [Parameter(Mandatory=$true,Position=0)]
    [System.Management.Automation.Runspaces.PSSession[]]$Session,

    [Parameter(Mandatory=$true,Position=1)]
    [String]$HuntName
)

process {
    Invoke-PRPlugin -Name 'Collect-Processes' -Session $Session -HuntName $HuntName
}
