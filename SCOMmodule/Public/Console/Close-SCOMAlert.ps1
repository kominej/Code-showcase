function Close-SCOMAlert{
  <#	
  .SYNOPSIS
		Close provided SCOM alerts.

	.PARAMETER AlertID
		OPTIONAL; [int32[]] (List of) alert(s) to close.
	
	.EXAMPLE
		Close-SCOMAlerts -AlertID 0
		Will close SCOM alert under ID 0.

	.EXAMPLE
		Close-SCOMAlerts -AlertID 1, 12, 20
		Will close SCOM alert under ID 1, 12 and 20.

  .INPUTS
    None.
    
  .OUTPUTS
    None.
  #>

  [CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[int32[]]
		$AlertID

	) #param

	procesS{
		$closeIDs = $scomAlerts[$AlertID].SCOMID
		
    if (-not $closeIDs) {
      Write-Verbose -Message 'No alerts to be closed.'

    } else {
			Write-Verbose -Message "Closing total of $($closeIDs.count) alert(s)."

			# set SCOM alert to 'Closed'
			Get-SCOMAlert -Criteria "Id IN ('$($closeIDs -join "','")')" | Resolve-SCOMAlert

		} #if:else(!closeIDs)
	} #process
} #function(Close-SCOMserviceAlert)


