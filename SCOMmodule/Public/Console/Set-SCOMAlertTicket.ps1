function Set-SCOMAlertTicket{
  <#	
  .SYNOPSIS
		Add a Cherwell ticket to provided SCOM alerts.
		
	.DESCRIPTION
		Modifies ResolutionState of SCOM alerts to 4 and TicketID to the value provided.
		Further information about alert ResolutionStates can be found within the help of 'Get-SCOMAlerts' function.
		
	.PARAMETER AlertID
		Mandatory; [int32[]] (List of) SCOM alert(s) to be assigned a Cherwell ticket.

	.PARAMETER TicketID
		Mandatory; [int32] Cherwell ticket number.

	.EXAMPLE
    Set-SCOMAlertTicket -AlertID 0,1,5 -TicketID 123456
    Sets Cherwell ticket ID 123456 and ResolutionState 4 to alerts 0, 1 and 5

  .INPUTS
    None.
    
  .OUTPUTS
    None.
  #>
  [CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[int32[]]
		$AlertID,

		[Parameter(Mandatory)]
		[int32]
		$TicketID
	) #param
	process{
		$modIDs = $scomAlerts[$AlertID].SCOMID

		if(-not $modIDs){
      Write-Verbose -Message 'No alerts to be set.'
    } else {
			Write-Verbose -Message "Setting total of $($modIDs.count) ticket(s) to CT-$TicketID."
			# set SCOM alert to 'Cherwell ticket' and assign ticket ID
			Get-SCOMAlert -Criteria "Id IN ('$($modIDs -join "','")')" | Set-SCOMAlert -ResolutionState 4 -TicketId $TicketID
		} #if:else(modIDs)
	} #process
} #function(Set-SCOMAlertTicket)