function Get-ServiceType{
	<#
	.SYNOPSIS
		Get service info from remote server.
	
	.PARAMETER ComputerName
		Mandatory; [string] Hostname of server to be checked.
	
	.PARAMETER ServiceName
		Optional; [string] Name of service to be checked.
	
	.EXAMPLE
		Get-ServiceType -ComputerName ComputerName -ServiceName serviceName

	.INPUTS
		None.
		
	.OUTPUTS
		.
	#>

	param(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[string]
		$ComputerName,
    
    [Parameter(Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline)]
		[string[]]
    $ServiceName,
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [pscredential]
    $Credentials
	
  ) #param

	process{
    $searchParams = @{
      ComputerName =  $ComputerName
      Class = 'Win32_Service'
      Property = 'Name,DisplayName,StartMode,State,ProcessId'
      Filter  = "Name='$ServiceName' OR DisplayName='$ServiceName'"
      ErrorAction = 'Stop'
    } #searchParams

    if ($credentials) {
      $searchParams.Add("Credential", $Credentials)
    } #if credentials

    try {
      Get-WmiObject @searchParams | Select-Object Name, DisplayName, StartMode, State, ProcessId

    } catch [System.UnauthorizedAccessException]{
      Write-Warning -Message "Unable to connect: Unauthorized access"
      break
      
    } catch {
      switch($_.Exception.HResult){
        0x800706BA {
          Write-Warning -Message "Unable to connect: Server unavailable"
          break
        }
        default { Write-Error -ErrorRecord $_ }

      } #switch
    } #try:catch(get remote services)
	} #process
} #function(Get-ServiceType)