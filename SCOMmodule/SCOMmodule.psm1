# Get public and private function definition files.
$Public  = @( Get-ChildItem -Recurse -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue)
$Private = @( Get-ChildItem -Recurse -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue)
$Classes = @( Get-ChildItem -Recurse -Path $PSScriptRoot\Classes\*.ps1 -ErrorAction SilentlyContinue)

# Dot source the files
Foreach($import in @($Public + $Private + $Classes)) {
    Try {
        Write-Verbose -Message "  Importing $($import.BaseName)"
        . $import.fullname
    }
    Catch {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}
$Script:PrivateData = $MyInvocation.MyCommand.Module.PrivateData

Export-ModuleMember -Function $Public.Basename -Alias *

Connect-SCOM -Verbose