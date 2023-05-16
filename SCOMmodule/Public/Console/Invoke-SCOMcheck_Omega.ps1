function Invoke-SCOMCheck_Omega{
  <#	
  .SYNOPSIS
    Get all new Omega alerts and print them in a more human readable format.

	.PARAMETER Repeat
		OPTIONAL; Will enter an endless loop and repeat the check in an interval of provided seconds, or every 300 seconds if no value is provided.

	.PARAMETER RepeatDelay
		OPTIONAL; Serves as override for check frequency. It's set up in a way where for instance '-repeat 60' is possible for ease of use.
  
  .EXAMPLE
    Invoke-SCOMCheck_Omega
    No options here. Will gather all new Omega alerts and print them in a more human readable format.

  .INPUTS
    None.
    
  .OUTPUTS
    None.
  #>
	[CmdletBinding(DefaultParameterSetName="noRepeat")]
	param(
		[Parameter(ParameterSetName="repeat")]
		[switch]
		$repeat,

		[Parameter(ParameterSetName="repeat", Position = 0)]
		[int32]
		$repeatDelay = 300
  ) #param

  begin{
    Connect-SCOM
  } #begin

  Process{
    Do {
      ## checkTime is used in Show-ScomAlerts, disregard the 'unused variable' warnings
      # the point is to get time when the check was done, not when it was printed, since you can print it at a later point in time
      $global:checkTime = "Time: $(Get-Date -Format 'hh:mm:ss UTCz')"

      ## get alert list and sort by alert name (type)
      # global instead of script scope for user interactibility
      # forced array
      $global:scomAlerts = @( Get-SCOMAlertInfo_Omega | Sort-Object -Property Type, Server, Age )

      # list ID is assigned here instead of object creation due to late sort
      # reason for this is that different alerts get their Server property from different alert properties, disallowing sort before the data extraction
      $counter = 0
      foreach ($alert in $scomAlerts) {
        Add-Member -InputObject $alert -MemberType NoteProperty -Name ID -Value $counter
        $counter++
      } #foreach(scomAlerts)
      
      Show-SCOMalerts
      
      if ($repeat) { 
        Write-Verbose -Message "Laying down for $repeatDelay seconds"
        Start-Sleep -Seconds $repeatDelay
        
      } #if(repeat)
    } Until (-not $repeat) #do-until

  } #process
} #function(Invoke-SCOMCheck_Omega)