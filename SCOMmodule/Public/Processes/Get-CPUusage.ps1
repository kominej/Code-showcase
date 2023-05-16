function Get-CPUusage{
	<#
	.SYNOPSIS
		Check server CPU usage and running processes.
	
	.PARAMETER ComputerName
		Mandatory; [string] Hostname of server to be checked.
	
	.PARAMETER noProcess
		Optional; [switch] Skip checking for high usage processes.
	
	.EXAMPLE
		Get-CPUusage -ComputerName server

	.EXAMPLE
		Get-CPUusage server

	.EXAMPLE
		Get-CPUusage server -noprocess

	.INPUTS
		Requires manual end of cycle by pressing 'escape' button.
		
	.OUTPUTS
		None.
	#>
	param(
		[Parameter(mandatory,position=0)]
		[string]
		$ComputerName,
		[switch]
		$noProcess = $false
	)
	begin{}
	process{
		#create session
		$session = New-PsSession $ComputerName 2>&1

		#session success
		if ($session.GetType().Name -eq "PSSession") {
			Write-Output "Checking CPU usage. To stop checking, press the Esc button."
			$line = "--- {0}" -f $ComputerName

			while ($true) {
				Write-Output $line
				Invoke-Command -session $session -ScriptBlock {
					#get CPU load
					$cpu = Get-WmiObject win32_processor | Select-Object -ExpandProperty LoadPercentage

					[uint16]$iter = 1
					foreach ($core in $cpu) {
						Write-Output ("CPU{0}: {1} %" -f $iter,$core); $iter++
					}

					if (!$noProcess -and $cpu -gt 50) {
						# get processes with cpu usage >30%, filter out idle and _total and return name and usage only
						$processes = (Get-Counter '\Process(*)\% Processor Time' -ErrorAction SilentlyContinue).CounterSamples | Where-Object { $_.CookedValue -gt 30  -and $_.InstanceName -notmatch "idle|_total" } | Select-Object @{l="ServiceName";e={ $_.InstanceName }},CookedValue
						
						# returns number of actual cores, $CPU.count() returns only number of used CPU slots
						$CPUcount = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors

						foreach ($item in $processes) {
							Add-Member -InputObject $item -MemberType NoteProperty -Name Usage -Value ("{0} %" -f [Math]::Round( $item.CookedValue / $CPUcount, 2 ))
						}
						
						$Processes | Sort-Object CookedValue -Descending | Format-Table Usage, ServiceName
					}
				} #invoke-command
				
				# end cycle when 'escape' is pressed
				if ($host.ui.RawUi.KeyAvailable -and $host.ui.RawUI.ReadKey("NoEcho,IncludeKeyUp").VirtualKeyCode -Eq "27" ) { break }
			} #while

			#close session
			Remove-PSSession $session

		} else { #session failed
			Write-Warning -Message ("Could not connect to server. Check manually.")
			$session

		} #if-else PSsession
	} #process
}