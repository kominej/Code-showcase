<#
.SYNOPSIS
  Disables AD account of provided hostnames.

#>

# webjeausername is a builtin variable for passing invoker's username
param(
	$webjeausername,

  [Parameter(Mandatory)]
  [string[]]
  $ComputerName

) #param

begin {
  
### Function DEF begin

	function New-LogEntry{
		param(
			[Parameter(Mandatory, ValueFromPipeline)]
			[string]
			$Entry
		) #param

		begin{
			$date = Get-Date -Format "yyyyMMdd"
			$filePath = "<path>\$date.log"
			
			$fileExists = Test-Path -Path $filePath
			if (-not $fileExists) {
				$null = New-Item -ItemType 'File' -Path "<path>\" -Name "$date.log"
			}
		} #begin

		process{
			Add-Content -Path $filePath -Value $entry
		} #process
	} #function New-LogEntry

### Function DEF End

} #begin

process {
  foreach ($computer in $ComputerName) {
    Write-Verbose -Message "Processing $computer"
    ### GET
    $adRecord = Get-ADComputer $computer -Properties MemberOf

    ## Validation checks
    # no records
    if ($null -eq $adRecord) {
      Write-Warning -WA 'Continue' -Message "No record found for '$computer'. Skipping."
      continue
    }
    # multiple records
    if ($adRecord -is [array]) {
      Write-Warning -WA 'Continue' -Message "Multiple records found for '$computer'. Skipping."
      continue
    }

    try {
      Disable-ADAccount -Identity $adRecord -Confirm:$false
      Write-Output "AD account for '$($adRecord.name)' disabled."

      $logEntry = "Account.Disable - $webjeausername - $ComputerName`nSID:$($adRecord.SID)"
      New-LogEntry -Entry $logEntry
    } catch {
      Write-Error -EA 'Stop' -ErrorRecord $_
    } #try-catch
    
  } #foreach ComputerName
} #process