function Close-SCOMAlertsBulk{
  <#	
  .SYNOPSIS
		Close all SCOM alerts related to provided switches.
		To skip specific alerts, use ' -ignore 0, 1, 2' using the list IDs

	.PARAMETER Cpu
		OPTIONAL; Will close CPU alerts. 

	.PARAMETER DFSRdisk
		OPTIONAL; Will close Disk space alerts.

	.PARAMETER DFSRstage
		OPTIONAL; Will close alerts related to folder staging.

	.PARAMETER Health
		OPTIONAL; Will close Health service alerts.

	.PARAMETER Services
		OPTIONAL; Will close alerts related to terminated services.

  .PARAMETER ignore
    Optional; [int32[]] ID(s) of alerts that are not to be closed.
	
	.EXAMPLE
		Close-SCOMAlertsBulk -Services -ignore 1, 8, 15
		Will close all SCOM alerts related to terminated services except for alerts under ID 1, 8 and 15 should any of them be a service related alert. 
		If they're not, it wouldn't close them anyway.

	.EXAMPLE
		Close-SCOMAlertsBulk -Services -DFSRstage -Cpu
		Will close all SCOM alerts related to terminated services, CPU usage and Health service.

	.EXAMPLE
		Close-SCOMAlertsBulk
		Will tell you to RTFM and select a switch.

  .INPUTS
    None.
    
  .OUTPUTS
    None.
  #>

  [CmdletBinding()]
	param(
		[switch]
		$Cpu,

		[switch]
		$DFSRdisk,

		[switch]
		$DFSRstage,

		[switch]
		$Health,

		[switch]
		$Services,

		[int32[]]
		$Ignore

	) #param

	process{
    if (-not $scomAlerts) {
      Write-Verbose -Message 'No alerts to be closed'

    } else {
			Write-Verbose -Message 'Getting SCOM IDs of ignored alerts'

			# get alert IDs of specifically ignored alerts
			if ($PSBoundParameters.Keys.Contains('Ignore')) {
				[array]$IDs = $scomAlerts[$ignore].SCOMID
			}
			Write-Verbose -Message "Skipping total of $($IDs.Count) alert(s)"
	
			Write-Verbose -Message 'Setting up filter'
			[System.Collections.ArrayList]$types = @()
			if ($CPU) {
				$null = $types.Add('CPU Utilisation')
			}
			if ($services) {
				$null = $types.Add('DFSR: Service stopped')
				$null = $types.Add('Service terminated')
			}
			if ($DFSRdisk) {
				$null = $types.Add('DFSR: Out of disk space')
			}
			if ($DFSRstage) {
				$null = $types.Add('DFSR: Not enough space')
				$null = $types.Add('DFSR: Staging folder cleanup')
				$null = $types.Add('DFSR: Not enough staging space')
			}
			if ($Health) {
				$null = $types.Add('Health service')
			}
	
			if (-not $types) {
				Write-Warning -Message 'You should probably select at the very least one type of alerts to close, you know.'

			} else {
				Write-Verbose -Message 'Filtering out alert types'
				# filter out specifically ignored IDs and resolve the remaining alerts of corresponding type
				$closeIDs = $scomAlerts | Where-Object { 
					$_.Type -in $types -and
					$_.SCOMID -notin $IDs 
				} | Select-Object -ExpandProperty SCOMID
				
				if(-not $closeIDs){
					Write-Verbose -Message 'No alerts to be closed'

				} else {
					Write-Verbose -Message "Closing total of $($closeIDs.Count) alert(s)"
					Get-SCOMAlert -Criteria "Id IN ('$($closeIDs -join "','")')" | Resolve-SCOMAlert

				} #if:else(!closeIDs)
			} #if:else(!types)			
		} #if:else(!scomAlerts)
	} #process
} #function Close-SCOMAlertsBulk