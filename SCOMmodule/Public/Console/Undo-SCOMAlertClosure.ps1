function Undo-SCOMAlertClosure{
  <#	
  .SYNOPSIS
		Reopen a SCOM ticket.
		
	.DESCRIPTION
		Modifies ResolutionState of SCOM alerts to 0 and TicketID to null value.

	.PARAMETER AlertID
		Mandatory; [string[]] (List of) SCOM alert(s) to be reopened.

	.PARAMETER ScomID
		Mandatory; [string[]] (List of) SCOM alert ID(s) to be reopened.

	.EXAMPLE
    Undo-SCOMAlertClosure -AlertID 3
		Reopens SCOM ticket with list ID 3

	.EXAMPLE
    Undo-SCOMAlertClosure -AlertID 12,15
		Reopens SCOM ticket with list ID 12 and 15

	.EXAMPLE
    Undo-SCOMAlertClosure -ScomID '12345678-abcd-1234-abcd-1234567890ab', 'abcdefgh-1234-abcd-1234-abcdefghijkl'
		Reopens SCOM ticket with SCOM ID 12345678-abcd-1234-abcd-1234567890ab and abcdefgh-1234-abcd-1234-abcdefghijkl

  .INPUTS
    None.
    
  .OUTPUTS
    None.
  #>

  [CmdletBinding(DefaultParameterSetName = 'ScomID' )] 
	param(
		[Parameter(Mandatory, DefaultParameterSetName = 'ScomID')]
		[string[]]
		$ScomID,

		[Parameter(Mandatory, DefaultParameterSetName = 'AlertID')]
		[string[]]
		$AlertID
	) #param

	process{
		if ($PSCmdlet.ParameterSetName -eq 'ScomID') {
			$openIDs = $ScomID
		} #if(ScomID)

		if ($PSCmdlet.ParameterSetName -eq 'AlertID') {
			$openIDs = $scomAlerts[$AlertID].SCOMID
		} #if(AlertID)

		Write-Verbose -Message "Reopening total of $($openIDs.count) ticket(s)."

		# set SCOM alert to 'Cherwell ticket' and assign ticket ID
		Get-SCOMAlert -Criteria "Id IN ('$($openIDs -join "','")')" | Set-SCOMAlert -ResolutionState 0 -TicketId $null

	} #process
} #function(Undo-SCOMAlertClosure)