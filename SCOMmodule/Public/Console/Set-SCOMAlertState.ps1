function Set-SCOMAlertState {
  <#	
  .SYNOPSIS
		Adds a Cherwell ticket to provided SCOM alerts.
		
	.DESCRIPTION
		SCOMalertifies ResolutionState of SCOM alerts to 4 and TicketID to the value provided.
		Further information about alert ResolutionStates can be found within the help of 'Get-SCOMAlerts' function.

	.NOTES
		ID State name
		-- ----
			0 New
			1 In progress Global Services
			2 In progress Global Operations
			3 SDE Ticket
			4 Cherwell Ticket
			6 Escalated to Global Services
			11 Generic
		247 Awaiting Evidence
		248 Assigned to Engineering
		249 Acknowledged
		250 Scheduled
		254 Resolved
		255 Closed
		
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
	[CmdletBinding(DefaultParameterSetName = 'AlertID')]

	param(
		[Parameter(Mandatory, ParameterSetName = 'AlertID')]
		[int32[]]
		$AlertID,

		[Parameter(Mandatory, ParameterSetName = 'SCOMID')]
		[string[]]
		$SCOMID,

		[ValidateSet('New', 'Cherwell', 'Closed')]
		[string]
		$State,

		[int32]
		$TicketID

	) #param

  begin {
    if (-not $scomAlerts) {
      Write-Verbose -Message 'No alerts to be set.'
      return
    }

		if ($State -eq 'Cherwell' -and $null -eq $TicketID) {
			Write-Warning -Message 'You must set a cherwell ticket number too.'
		}

  } #begin

	process {
		if ($PSBoundParameters.Keys.Contains('AlertID')) {
			# filter out out-of-range entries
			$validTickets = $AlertID | Where-Object { $_ -lt $scomAlerts.count }
			$SCOMalertIDs = $scomAlerts[$validTickets].SCOMID

		} else {
			$SCOMalertIDs = $SCOMID

		} #if-else AlertID
		

		switch ($State){
			'New' {
				# set SCOM alert to 'Cherwell ticket' and assign ticket ID
				Get-SCOMAlert -Criteria "Id IN ('$($SCOMalertIDs -join "','")')" | Set-SCOMAlert -ResolutionState 0
			} #New

			'Cherwell' {
				# set SCOM alert to 'Cherwell ticket' and assign ticket ID
				Get-SCOMAlert -Criteria "Id IN ('$($SCOMalertIDs -join "','")')" | Set-SCOMAlert -ResolutionState 4 -TicketId $TicketID
			} #Cherwell

			'New' {
				# set SCOM alert to 'Cherwell ticket' and assign ticket ID
				Get-SCOMAlert -Criteria "Id IN ('$($SCOMalertIDs -join "','")')" | Set-SCOMAlert -ResolutionState 255
			} #New

			default {
				Write-Error "If this popped up, the endtimes are nigh!"
			}

		} #switch State
	} #process
} #function Set-SCOMAlertState 