function Invoke-SCOMserviceStart{
  <#	
  .SYNOPSIS
		Try to re-start all terminated automatic services across all retrieved service related SCOM alerts.

	.PARAMETER Ignore
    Optional; [int32[]] ID(s) of alerts that are not to be used for gathering hostnames.    
    Please note that if these hostnames are in other service related alerts as well, they will also be ignored.

	.EXAMPLE
		Invoke-SCOMserviceStart
		Will try to start services across all hostnames in service related alerts.

	.EXAMPLE
		Invoke-SCOMserviceStart -Ignore 0, 1, 13
    Will try to start services across all hostnames in service related alerts except for hostnames in alerts 0, 1 and 13. 
    Please note that if these hostnames are in other service related alerts as well, they will also be ignored.

  .INPUTS
    None.
    
  .OUTPUTS
    Format-Table(s) of found errors.
  #>

  [CmdletBinding()]
  param(
    [int32[]]
    $Ignore,

    [switch]
    $skipMCS

  ) #param

  process{
    if (-not $scomAlerts) {
      Write-Verbose -Message 'No alerts to be invoked.'

    } else {
      if($PSBoundParameters.Keys.Contains('Ignore')){
        Write-Verbose -Message 'Getting hostnames of ignored alerts'
        $ignoredList = $scomAlerts[$Ignore].Server
      }
      
      $lastHostname = $null
      
      Write-Verbose -Message 'Going through list.'
      foreach($alert in $scomAlerts){
        Write-Verbose -Message "Checking alert $($alert.ID)."

        # handle only service alerts
        if ($alert.Type -eq 'DFSR: Service stopped' -or
            $alert.Type -eq 'Service terminated') {
            
          # skip if blacklisted
          if ($ignoredList -contains $alert.Server) {
            Write-Verbose -Message "Server $($alert.Server) is in ignore list, skipping."

          # skip if DC
          } elseif ($alert.Server.substring(3,2) -eq 'DC') {
            if($lastHostname -ne $alert.Server){
              Write-Information -InfA "Continue" -MessageData ("`r`n(ID:{0:d2}) {1}" -f $alert.ID, $alert.Server)
              Write-Warning -Message 'Server is domain controller - ask GOC Client team to check. Skipping.'
              $lastHostname = $alert.Server
            }   

          # skip MCS if switched
          } elseif ($alert.Server.substring(3,3) -eq 'MCS' -and $skipMCS) {
            if($lastHostname -ne $alert.Server){
              Write-Information -InfA "Continue" -MessageData ("`r`n(ID:{0:d2}) {1}" -f $alert.ID, $alert.Server)
              Write-Warning -Message 'Server is MCS. Skipping per switch selection.'
              $lastHostname = $alert.Server
            }   

          # skip if hostname already handled
          } elseif ($alert.Server -ne $lastHostname) {
            # add domain unless grouph or DMZ  
            if($alert.Domain -ne 'grouphc.net' -and $alert.Domain -ne 'WORKGROUP'){
              $hostname = $alert.Server, $alert.Domain -join "."
            } else {
              $hostname = $alert.Server
            }            
            
            Write-Information -InfA "Continue" -MessageData ("`r`n(ID:{0:d2}) {1}" -f $alert.ID, $hostname)
            # start services
            try {
              Invoke-AutoServiceStart $hostname
            } catch {
              if($alert.Domain -eq 'WORKGROUP'){
                Write-Warning -Message 'Server is probably in DMZ - ask AH team to check. Skipping.'
              } else {
                Write-Error -ErrorRecord $_
              } #if-else
            } #try:catch(Invoke-AutoServiceStart)

            # note current hostname as last handled
            $lastHostname = $alert.Server

          } #if:else(DC; ignored; hostname handled)
        } #if(alert type)
      } #foreach(scomAlerts)

      Write-Information -InfA 'Continue' -MessageData "`r`n-- End of the list --"
    } #if(!SCOMalerts)
  } #process
} #function(Invoke-SCOMServiceStart)