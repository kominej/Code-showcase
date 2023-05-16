function Get-SCOMAlertInfo_basic{
  <#	
  .SYNOPSIS
    Gather new SCOM alerts for <team> and return relevant information.
    
  .EXAMPLE
    Get-AlertInfo_basic
    No options here. Will gather all new <team> alerts and return them in a more readable fashion.

  .INPUTS
    None.
    
  .OUTPUTS
    [PSCustomObject] list of open SCOM alerts.
  #>

  [CmdletBinding()]
  param() #param

  begin{
    Write-Verbose -Message 'Getting date (UTC)'
    $now = (Get-Date).ToUniversalTime()
  } #begin

  process{
    Write-Verbose -Message 'Fetching raw SCOM alerts'
    try {
      $alertList = Get-SCOMAlerts -basic

    } catch {
      Write-Error -EA 'Stop' -ErrorRecord $_

    } #try-catch

    
    if ($null -eq $alertList) {
      Write-Verbose -Message 'No alerts were fetched - returning null'

    } else {
      # objects get returned on their own, not as array -> counter for future reference
      $counter = 0

      # Can you smell what the SCOM is cooking?
      Write-Verbose -Message 'Going through list'
      foreach ($alertObject in $alertList) {
        ## Basic info
        $time = NEW-TIMESPAN -Start $alertObject.TimeRaised -End $now
        $SCOMalert = @{
          SCOMID = $alertObject.ID.GUID
          Age = [Math]::Floor($time.TotalMinutes) # minutes since alerts was raised
          Type = ''
          Server = ''
          Domain = ''
        }
        
        ## Alert-specific info
        # fill info based on alert type
        switch ($alertObject.Name) {
          'CITRIX - CPU utilization is high' {
            $SCOMalert.Type = 'CPU Utilisation'
            $SCOMalert.Server = $alertObject.NetbiosComputerName
            $SCOMalert.Domain = $alertObject.NetbiosDomainName
          }

          'DFS-R: DFS Replication Service Is Stopped' {
            $SCOMalert.Type = 'DFSR: Service stopped'
            $SCOMalert.Server = $alertObject.NetbiosComputerName
            $SCOMalert.Domain = $alertObject.NetbiosDomainName
          }

          'DFS-R: Not Enough Space to Stage Files for Replication' {
            $SCOMalert.Type = 'DFSR: Not enough space'
            $SCOMalert.Server = $alertObject.NetbiosComputerName
            $SCOMalert.Domain = $alertObject.NetbiosDomainName
          }

          'DFS-R: Out of Disk Space' {
            $SCOMalert.Type = 'DFSR: Out of disk space'
            $SCOMalert.Server = $alertObject.NetbiosComputerName
            $SCOMalert.Domain = $alertObject.NetbiosDomainName

            $SCOMalert.Add('Info', "$($SCOMalert.Server) '$($alertObject.Parameters[5,1,3] -join "' '")'")
          }

          'DFS-R: Staging Folder Cleanup Failed' {
            $SCOMalert.Type = 'DFSR: Staging folder cleanup'
            $SCOMalert.Server = $alertObject.NetbiosComputerName
            $SCOMalert.Domain = $alertObject.NetbiosDomainName
            
            $SCOMalert.Add('Info', "$($SCOMalert.Server) '$($alertObject.Parameters[9,8] -join "' '")'")
          }

          'Not enough staging space to replicate files for replicated folder' {
            $SCOMalert.Type = 'DFSR: Not enough staging space'
            $SCOMalert.Server = $alertObject.NetbiosComputerName
            $SCOMalert.Domain = $alertObject.NetbiosDomainName
          }

          'Service terminated unexpectedly' {
            $SCOMalert.Type = 'Service terminated'

            if($alertObject.NetbiosDomainName -like '*.net'){
              $SCOMalert.Server = $alertObject.NetbiosComputerName
              $SCOMalert.Domain = $alertObject.NetbiosDomainName  
            } else {
              $SCOMalert.Server, $SCOMalert.Domain = $alertObject.PrincipalName.split(".")
              $SCOMalert.Domain = $SCOMalert.Domain -join "."
            }
            
            #no way around it here, service is not included on its own anywhere in Parameters
            $errData = ([xml]$alertObject.Context).DataItem
            if($errData.Params.Param.count -eq 1) {
              $SCOMalert.Add('Info', $errData.Params.Param)
            } else {
              $SCOMalert.Add('Info', $errData.Params.Param[0])
            }
          } #Service terminated unexpectedly

          'System Center Management Health Service Unloaded System Rule(s)' {
            $SCOMalert.Type = 'Health service'
            # NetbiosComputerName doesn't hold server name, gotta go the extra Green mile
            # splits first occurence into .Server and the rest into .Domain
            $SCOMalert.Server, $SCOMalert.Domain = $alertObject.Parameters[1].split(".")
            $SCOMalert.Domain = $SCOMalert.Domain -join "."
          }

          default { $SCOMalert.Type = 'Unknown' }

        } #switch(type)

        $counter++
        Write-Output -InputObject ([pscustomobject]$SCOMalert)

      } #foreach(alertList)
      Write-Verbose -Message "Total processed: $counter alerts"

    } #if(AlertList)
  } #process
} #function Get-SCOMAlertInfo_basic