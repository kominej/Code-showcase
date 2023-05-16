function Invoke-AutoServiceStart{
	<#
	.SYNOPSIS
		Try to start all not running services with startup type "automatic"
	
	.DESCRIPTION
		Full list of ignored services is as follows:
		Name                DisplayName
		----                -----------
		CDPSvc              Connected Devices Platform Service
		clr_optimization.*  
		gupdate             Google Update Service
		SysmonLog           Performance Logs and Alerts
		GISvc               
		TBS                 TPM Base Services
		edgeupdate

	.PARAMETER ComputerName
		Mandatory; [string] Hostname of remote server.
	
	.EXAMPLE
		Invoke-AutoServiceStart -ComputerName ComputerName

	.EXAMPLE
		Invoke-AutoServiceStart ComputerName

	.INPUTS
		None.
		
	.OUTPUTS
		None.
	#>

	param(
		[Parameter(Mandatory,Position = 0)]
		[string]
		$ComputerName,

		[int32]
		$SleepDelay = 5
	) #param

	begin{
		$ignoreList = "CDPSvc|clr_optimization.*|gupdate|SysmonLog|GISvc|TBS|edgeupdate"

		$startStates = @(
			'The service is starting.',
			'The request is not supported.',
			'The user did not have the necessary access.',
			'The service cannot be stopped because other services that are running are dependent on it.',
			'The requested control code is not valid, or it is unacceptable to the service.',
			'The requested control code cannot be sent to the service because the state of the service (Win32_BaseService.State property) is equal to 0, 1, or 2.',
			'The service has not been started.',
			'The service did not respond to the start request in a timely fashion.',
			'Unknown failure when starting the service.',
			'The directory path to the service executable file was not found.',
			'The service is already running.',
			'The database to add a new service is locked.',
			'A dependency this service relies on has been removed from the system.',
			'The service failed to find the service needed from a dependent service.',
			'The service has been disabled from the system.',
			'The service does not have the correct authentication to run on the system.',
			'This service is being removed from the system.',
			'The service has no execution thread.',
			'The service has circular dependencies when it starts.',
			'A service is running under the same name.',
			'The service name has invalid characters.',
			'Invalid parameters have been passed to the service.',
			'The account under which this service runs is either invalid or lacks the permissions to run the service.',
			'The service exists in the database of services available from the system.',
			'The service is currently paused in the system.'
		) #startStates list
	} #begin

	process{
		$first = $true
		$cycle = $true

		while ($cycle) {
			#(re)start not running services
			try{
				$services = Get-WmiObject -ComputerName $ComputerName -Class Win32_Service -Property Name,DisplayName,StartMode,State,ProcessId -Filter "StartMode='Auto' AND State!='Running'" -ErrorAction 'Stop'

			} catch [System.UnauthorizedAccessException]{
				Write-Warning -Message "Unable to connect: Unauthorized access"
				return

			} catch {
				switch ($_.Exception.HResult) {
					0x800706BA {
						Write-Warning -Message "Unable to connect: Server unavailable"
						return
					}
					default { Write-Error -ErrorRecord $_ }
				}
			} #try-catch-catch
			
			$services = $services | Where-Object Name -notmatch $ignoreList

			if ($null -eq $services) {
				Write-Output "All services running."
				$cycle = $false

			} else {
				if ($first) {
					$first = $false

				} else {
					# list services which are not running after first re-start
					Write-output ("Still not running services:`r`n{0}" -f ($services | Select-Object -ExpandProperty DisplayName | Out-string))
					
					# retry?
					Write-Output "Attempting to re-start the services again. Press 'Esc' to cancel."
					
					# throw away buffered keypresses
					while ([Console]::KeyAvailable) {
						$null = [Console]::ReadKey("NoEcho,IncludeKeyDown")
					}

					if ( [Console]::ReadKey("NoEcho,IncludeKeyDown").Key -eq 'Escape' ) {
						$cycle = $false

					} #if Esc pressed
				} #if-else First

				if ($cycle) {
					foreach ($service in $services) {
						# try to start service
						$result = $service.StartService()

						# write corresponding start result by indexing
						Write-Output ( "{0} - {1}" -f $service.DisplayName, $startStates[$result.ReturnValue])
					} #foreach
	
					Write-Information -InfA 'Continue' -MessageData "----------------"
					Start-Sleep -Seconds $SleepDelay
				} #if Cycle
			} #if-else Service
		} #while
	} #process
} #function Invoke-AutoServiceStart