# Determine whether app/ has only Docker-created dependency mountpoints.
# Never treat an existing Laravel source, hidden files or symlinks as disposable.
function Get-FoundryUnexpectedAppEntries {
    param([Parameter(Mandatory = $true)][string]$AppPath)

    if (-not (Test-Path -LiteralPath $AppPath)) { return }

    Get-ChildItem -LiteralPath $AppPath -Force | Where-Object {
        $mountpoint = $_.Name -in @('vendor', 'node_modules')
        $directory = $_.PSIsContainer
        $link = [bool]($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
        -not ($mountpoint -and $directory -and -not $link)
    }
}
