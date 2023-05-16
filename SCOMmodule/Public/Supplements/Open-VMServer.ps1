function Open-VMServer{
	param(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, Position = 0)]
		[string]
		$ComputerName,

		[Parameter(ValueFromPipelineByPropertyName, Position = 1)]
		[string]
		$ESXi

	) #param

	begin{
		## Primer: InformationPreference
		if ($PSBoundParameters.keys.Contains("InformationAction")) {
			$InformationPreference = $PSBoundParameters["InformationAction"]
		} else {
			$InformationPreference = "Continue"
		} #if-else
		
		Write-Information -MessageData "Setting up prerequirements"

		## Primer: ErrorActionPreference
		$ErrorActionPreference = "Stop"

		## Primer: ErrorAction
		if ($PSBoundParameters.keys.Contains("ErrorAction")) { 
			$EA = $PSBoundParameters["ErrorAction"]
		} else {
			$EA = "Stop" 
		} #if-else

	} #begin

	process{
		## if ESXi not provided, check for known vCenters
		if (-not $ESXi) {
			## Setup SQL connection
			$SQLserver = "<server>"
			$SQLdatabase = "<database>"
			$SQLconnect = new-object System.Data.SqlClient.SQLConnection
			$SQLconnect.ConnectionString = "Server=$SQLserver;Database=$SQLdatabase;Integrated Security=SSPI"
			
			# connect to VM CMDB
			try {
				$SQLconnect.Open()
			} catch {
				Write-Error -EA $EA -Message ( "ERROR: Could not establish connection with VM CMDB: {0}" -f $_.Exception.Message )
				return
			} #try-catch

			## retrieve data
			# SQL query for vCenter CMDB
			$query = "SELECT [Name], [vCenter] FROM [table].[database].[container] WHERE [Name] = '$ComputerName'"

			# create SQL command object
			$cmd = new-object system.Data.SqlClient.SqlCommand($query,$SQLconnect)
			$cmd.CommandTimeout=$QueryTimeout

			# create data container and handler
			$ds = New-Object system.Data.DataSet
			$da = New-Object system.Data.SqlClient.SqlDataAdapter($cmd)

			# fill container
			[void]$da.Fill($ds)

			# get query content
			$results = $ds.Tables[0]

			if($null -eq $results.vCenter) { 
				Write-Error -EA $EA -Message ( "No record found for '{0}'. Make sure the hostname is correct or provide ESXi via parameter." -f $ComputerName )
			}
			# 'while' instead of 'if' if the user cancels
			while ($results.Rows.Count -gt 1) {
				$results = $results | Out-GridView -OutputMode Single -Title "Select correct record:"
			}

			$ESXi = $results.vCenter | Select-Object -First 1
		} #if:ESXi not provided

		## connect to ESXi		
		Write-Information -MessageData ("Connecting to {0}." -f $ESXi)
		Connect-VIServer $ESXi | Out-Null

		# get VM object
		try {
			$VMobject = Get-VM $ComputerName
		}	catch {
			Write-Error -ErrorRecord $_
		}

		# if powered, open VM console
		if ($VMobject.PowerState -eq "PoweredOn") {
			Open-VMConsoleWindow $VMobject
		} else {
			Write-Warning ("Server state is {0}" -f $VMobject.PowerState)
		} #if-else PoweredOn

	} #process
} #function(Open-VMServer)