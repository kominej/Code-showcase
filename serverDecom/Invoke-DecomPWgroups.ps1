<#
.SYNOPSIS
  Removes PatchWave and Priority groups from servers AD account.
	
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

    ### AD group records
    Write-Verbose -Message "Getting AD groups"
    $adRecordgroups = $adRecord.MemberOf | Get-ADgroup 
    Write-Verbose -Message "Total: $($adRecordgroups.count)"

    ## DMZ check
    Write-Verbose -Message "DMZ check"
    $dmzGroup = $adRecordgroups | Where-Object Name -like '*DMZ*'

    if ($dmzGroup) {
      Write-Output "Server '$computer' is in DMZ. Skipping. ($dmzGroup)`n- Forward the WI to <team> for removal."
      continue
    }
    Write-Verbose -Message "AOK"

    ## Priority group
    Write-Verbose -Message "Priority check"
    $priorityGroup = $adRecordgroups | Where-Object Name -like '* Server Priority *'

    # Validity check & remove
    if ($null -eq $priorityGroup) {
      Write-Warning -WA 'Continue' -Message "No Priority group found for '$computer'."

    } else {
      try {
        Remove-ADGroupMember -Identity $priorityGroup -Members $adRecord -Confirm:$false
        Write-Output "$($adrecord.name) removed from '$($priorityGroup.Name)'"

        $logEntry = "PW.Remove - $webjeausername - $ComputerName`nSID:$($adRecord.SID)"
        New-LogEntry -Entry $logEntry
      } catch {
        Write-Error -EA 'Stop' -ErrorRecord $_
      } #try-catch  
    } #if-else priority N/A
    Write-Verbose -Message "AOK"

    ## PatchWave group
    Write-Verbose -Message "PW group check"
    # regex incoming, matching <groups>
    $pwGroup = $adRecordgroups | Where-Object Name -match '<regexQuery>'

    # Validity check & remove
    if ($null -eq $pwGroup) {
      Write-Warning -WA 'Continue' -Message "No Patchwave group found for '$computer'."

    } else {    
      try {
        Remove-ADGroupMember -Identity $pwGroup -Members $adRecord -Confirm:$false
        Write-Output "$($adrecord.name) removed from '$($pwGroup.Name)'"

        $logEntry = "Prio.Remove - $webjeausername - $ComputerName`nSID:$($adRecord.SID)"
        New-LogEntry -Entry $logEntry
      } catch {
        Write-Error -EA 'Stop' -ErrorRecord $_
      } #try-catch  
    } #if-else pwGroup N/A
    Write-Verbose -Message "AOK"

  } #foreach ComputerName
} #process