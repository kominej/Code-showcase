Function Connect-SCOM{
	<#	
	.SYNOPSIS
		Opens connection with SCOM server

	.PARAMETER ScomServer
		Optional; [string] SCOM server hostname.

	.EXAMPLE
		Connect-SCOM
		Attempts to open communications with module's default SCOM server.

	.EXAMPLE
		Connect-SCOM -SCOMServer 'anotherSCOMserver'
		Attempts to open communications with 'anotherSCOMserver' server.

	.INPUTS
		None.
		
	.OUTPUTS
		None.
	#>

	[CmdletBinding()]
	param(
		[string]
		$SCOMserver = $MyInvocation.MyCommand.Module.PrivateData.SCOMserver
		
	) #param

	process{
		If (Get-SCOMManagementGroupConnection){
			Write-Verbose -Message 'Aready connected to SCOM server.'

		} else {
			try {
				Write-Verbose -Message 'Connecting to SCOM server'
				New-SCOMManagementGroupConnection -ComputerName $ScomServer

			} catch {
				Write-Error ( "Connection could not be established. Check if server '{0}' is reachable. " -f $SCOMserver )
				break;

			} #try-catch
		} #if-else SCOM connection
	} #process 
} #Function Connect-SCOM