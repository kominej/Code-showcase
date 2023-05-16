function Show-SCOMAlerts{
  <#	
  .SYNOPSIS
		Prints out gathered and processed SCOM alert info in user-readable form.
				
	.EXAMPLE
    Show-SCOMAlerts
    No options here. Will print all new Omega alerts in a more human readable format.

  .INPUTS
    None.
    
  .OUTPUTS
    Format-Table(s) of processed alerts.
  #>
  [CmdletBinding()]
  param() #param

  process{
    Write-Information -InfA 'Continue' -MessageData "$checkTime"
    if ($scomAlerts) {
      # just a formatting dumb
      Write-Information -InfA 'Continue' -MessageData ""
      
      # print out results, showing info where it's due
      $scomAlerts | Group-Object Type | ForEach-Object {
        Write-Information -InfA 'Continue' -MessageData "> $($_.name)"
        if ($null -ne $_.Group[0].Info) {
          $_.Group | Format-Table ID, Age, Server, Domain, Info
        } else {
          $_.Group | Format-Table ID, Age, Server, Domain
        } #if:else(infoList)
      } #printout

    } else {
      Write-Verbose -Message 'No alerts to be read.'

    } #if:else(alerts)
  } #process
} #function(Show-SCOMAlerts)