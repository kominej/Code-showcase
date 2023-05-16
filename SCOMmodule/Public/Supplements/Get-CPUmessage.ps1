function Get-CPUmessage{
	<#
	.SYNOPSIS
		Print CPU usage message for ticket note.
	
	.PARAMETER ComputerName
		Mandatory; [string] Hostname of affected server.
	
	.PARAMETER ServiceName
		Optional; [string] Service name which takes the most CPU usage.
	
	.PARAMETER UserName
		Optional; [string] Username which is running the service.
	
	.EXAMPLE
		Get-CPUmessage -ComputerName server -ServiceName service -UserName user

	.EXAMPLE
		Get-CPUmessage server service user

	.INPUTS
		None.
		
	.OUTPUTS
		[string] Message for use in ticket note.
	#>

	param(
	 [Parameter(Mandatory, Position=0)]
	 [string]
	 $ComputerName,
	 [Parameter(Mandatory, Position=1)]
	 [string]
	 $ServiceName,
	 [Parameter(Mandatory, Position=2)]
	 [string]
	 $UserName
	) #param

	Write-output ("Hi,
		`r{0} is causing high CPU utilization affecting overall {1} server performance. 
		`rPlease, investigate root cause of application related service causing high CPU utilization. If possible ask user to restart the application causing high CPU utilization.
		`rUser: {2}
		`rThank you." -f $ServiceName, $ComputerName, $userName )
} #function Get-CPUmessage