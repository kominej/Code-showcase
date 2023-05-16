function Invoke-HealthServiceRestart{
	<#
	.SYNOPSIS
		Reinitiate Health check service.
	
	.PARAMETER ComputerName
		Mandatory; [string] Hostname of remote server.
	
	.EXAMPLE
		Invoke-HealthServiceRestart -ComputerName ComputerName

	.EXAMPLE
		Invoke-HealthServiceRestart ComputerName

	.INPUTS
		None.
		
	.OUTPUTS
		None.
	#>

	param(
		[Parameter(Mandatory,Position = 0)]
		[string[]]
		$ComputerName
		
	) #param
	
	process{
		foreach ($computer in $ComputerName) {
			Write-Verbose -Message "Checking '$computer'"
			
			try{ 
				$healthService = Get-WmiObject -ComputerName $ComputerName -Class Win32_Service -Property Name,DisplayName,StartMode,State,ProcessId -Filter "Name = 'HealthService'"
				
				Write-Information -InfA 'Continue' -MessageData 'Stopping HealthService'
				$healthService.StopService()

				Write-Information -InfA 'Continue' -MessageData 'Deleting "Health Service State" folder'
				Invoke-Command -ComputerName $ComputerName -ScriptBlock {
				 Remove-Item 'C:\Program Files\Microsoft Monitoring Agent\Agent\Health Service State' -Recurse -Force
				}

				Write-Information -InfA 'Continue' -MessageData 'Starting HealthService'
				$healthService.StartService()

			} catch {
				Write-Error -ErrorRecord $_
				
			} #try-catch			
		} #foreach ComputerName
	} #process
} #function Invoke-HealthServiceRestart