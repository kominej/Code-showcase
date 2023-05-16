function Show-SCOMHeartbeats{
  <#	
  .SYNOPSIS
		Print out gathered and processed SCOM Heartbeat alerts in user-readable form.
				
	.EXAMPLE
    Show-SCOMHeartbeats
    No options here. Will print all open heartbeat alerts in a more human readable format.

  .INPUTS
    None.
    
  .OUTPUTS
    PSCustomObject of processed alerts.
  #>

  [CmdletBinding()]
  param() #param

  begin{
    Connect-SCOM

    Write-Verbose -Message 'Getting date (UTC)'
    $now = (Get-Date).ToUniversalTime()

    # list of posible SCOM alert 'ResolutionState's
    $resStateEnum = $MyInvocation.MyCommand.Module.PrivateData.resStateEnum
  } #begin

  process{
    $alertList = Get-SCOMAlerts -Heartbeat

    Write-Verbose -Message 'Going through list'
    $alertList | ForEach-Object {
      $span = NEW-TIMESPAN -Start $_.TimeRaised -End $now

      $alert = [PSCustomObject]@{
        ComputerName = $_.MonitoringObjectDisplayName
        Age = [int32]$span.TotalMinutes
        Status = $resStateEnum[[int32]$_.ResolutionState]
        Ticket = $_.TicketID
      } #alert

      Write-Output -InputObject $alert

    } #alertlist
    Write-Verbose -Message "Total processed: $($alertList.count)"
    
  } #process
} #function(Show-SCOMHeartbeats)