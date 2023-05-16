<#
.SYNOPSIS
	Checks the SolarWinds database for provided hostname and either returns NodeID or removes it based on the Remove switch.

#>

# webjeausername is a builtin variable for passing invoker's username
param(
	$webjeausername,
	
	[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
	[string[]]
	$ComputerName,

	[Parameter(HelpMessage = "Check this if you want to remove the node. Leave unmarked for lookup only.")]
	[switch]
	$Remove
) #param

begin{
### Function DEF Begin

	function New-LogEntry{
		param(
			[Parameter(Mandatory, ValueFromPipeline)]
			[string]
			$Entry
		) #param

		begin{
			$date = Get-Date -Format "yyyyMMdd"
			$filePath = "<path>\$date.log"
			
			$fileExists = Test-Path -Path $filePath
			if (-not $fileExists) {
				$null = New-Item -ItemType 'File' -Path "<path>\" -Name "$date.log"
			}
		} #begin

		process{
			Add-Content -Path $filePath -Value $entry
		} #process
	} #function New-LogEntry

### Function DEF End

	Write-Verbose -Message "Setting up prerequirements"

	## Primer: ErrorActionPreference
	$ErrorActionPreference = "Stop"

	## Primer: ErrorAction
	if ($PSBoundParameters.keys.Contains("ErrorAction")) { 
		$EA = $PSBoundParameters["ErrorAction"]
	} else {
		$EA = "Stop" 
	} #if-else

	## SolarWinds connection
	try{
		# credentials & IP
		$creds = [pscredential]::new('<login>', '<password>')
		$serverIP = '<IPaddress>'
		# TODO: Unhardcode
		
		# create connection token
		$script:swisCon = Connect-Swis -Hostname $serverIP -cred $creds
	} catch {
		throw $_
	} #try-catch
} #begin

process{
	foreach ($hostname in $ComputerName) {
		try{
			Write-Output "Looking up $hostname"
			# Get decom'd server URI - proper naming
			$SWISnode = Get-SwisData -SwisConnection $script:SwisCon -Query "SELECT Caption, NodeID, Uri FROM <table> WHERE Caption = '$hostname'"
			
			# Get decom'd server URI - has domain in name
			if ($null -eq $SWISnode) {
				$SWISnode = Get-SwisData -SwisConnection $script:SwisCon -Query "SELECT Caption, NodeID, Uri FROM <table> WHERE Caption Like '$hostname.%'"
			} #if
		} catch {
			Write-Error -EA $EA -ErrorRecord $_
		}

		if ($SWISnode) {
			#node(s) found
			if ($Remove) {
				Write-Verbose -Message "Adding log entry"
				$dateTime = Get-Date -format "yyyy/MM/dd hh:mm:ss"				
				$logEntry = "$dateTime - REMOVE - $webjeausername - $($SWISnode.Caption) (NodeID $($SWISnode.NodeID))"
				New-LogEntry -Entry $logEntry

				Write-Verbose -Message "Removing node $($SWISnode.NodeID)"
				try {
					Remove-SwisObject -SwisConnection $script:SwisCon -Uri $SWISnode.URI				
					
					# workaround for extra newlines before and after FL
					$outstring = $SWISnode | Format-List Caption, NodeID | Out-String
					Write-Output "- Removed following nodes:`n$($outstring.trim())`n"
				} catch {
					Write-Error -EA $EA -ErrorRecord $_
				} #try-catch

			} else {
				# workaround for extra newlines before and after FL
				$outstring = $SWISnode | Format-List Caption, NodeID, @{n='URL'; e={"<url>"}} | Out-String
				Write-Output "- Found following nodes:`n$($outstring.trim())`n"
			}#if-else Remove

		} else {
			Write-output "No nodes found.`n"
		} #if-else SWISnode

	} #foreach
} #process