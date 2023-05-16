<#
.SYNOPSIS
	Checks the DNS and SMTP for provided hostname(s) and/or IP address(es).

#>

param(
	[string[]]
	$ComputerName,

	[string[]]
	$IPaddress
) #param

begin{
### Function DEF BEGIN

## SMTP database comm
	function Connect-SMTP{
		<#
		.SYNOPSIS
			Open connection to SMTP database.

		.PARAMETER Server
			[string] Hostname of the database server

		.PARAMETER Database
			[string] Name of the database

		.EXAMPLE
			Connect-SMTP
			Defaults to preset server and database for SMTP.

		.EXAMPLE
			Connect-SMTP -Server servername -Database databaseName

		.INPUTS
			None
			
		.OUTPUTS
			None
		#>
		param(
		[string]
		$SQLServer = '<server>',

		[string]
		$SQLDBName = '<database>'
	) #param

	process{
		# if already connected -> skip
		if ($script:SQLconn.State -ne "Open") {
			# set up connection
			$script:SQLconn = new-object System.Data.SqlClient.SQLConnection
			$script:SQLconn.ConnectionString = "Server=$SQLServer;Database=$SQLDBName;Integrated Security=SSPI"

			# connect
			try { $script:SQLconn.Open() }
			catch { #TODO: handle untyped errors
				if ($_.Exception.InnerException.InnerException -eq "The network path was not found") {
					Write-Error -Message ("Connection to server {0} couldn't be established." -f $SQLServer )
				}	else {
					throw $_
				}
			} #catch

		} #if
	} #process
	} #function

	function Disconnect-SMTP{
		<#
		.SYNOPSIS
			Close connection to SMTP database.

		.EXAMPLE
			Disconnect-SMTP

		.INPUTS
			None
			
		.OUTPUTS
			None
		#>

		process{
			try {
				Write-Verbose -Message "Closing connecting to SMTP"
				$script:SQLconn.Close()
			} catch {
				throw $_
			} #try-catch
		} #process

	} #function Disconnect-SMTP

	function Invoke-SQLquery{
		<#
		.SYNOPSIS
			Query the connected database for data.

		.PARAMETER Query
			MANDATORY; [string] Full query to the database

		.EXAMPLE
			Invoke-SQLquery -Query "SELECT * FROM [table] WHERE stringVariable LIKE 'stringValue%'"
			Queries the connected database for rows where stringVariable starts with 'stringValue'.
			Returns all data available for the matching rows.
			
		.EXAMPLE
			Invoke-SQLquery -Query "SELECT intVariable, otherVariable  FROM [table] WHERE intVariable IN (0..20)"
			Queries the connected database for rows where intVariable is within 0 and 20 includin the two.
			Returns only intVariable and otherVariable of the matching rows.

		.INPUTS
			None
			
		.OUTPUTS
			[DataRow] with found data
		#>
		param(
			[Parameter(Mandatory)]
			[string]
			$Query
		) #param

		begin{
			# Verify database connection
			if ($null -eq $script:SQLconn) {
				try{
					Connect-SMTP
				} catch {
					throw $_
				}
			}

			$SQLcommand = New-Object System.Data.SqlClient.SqlCommand($Query, $script:SQLconn)
			$SQLcommand.CommandTimeout = 20

			$dataSet = New-Object System.Data.DataSet
			$SQLadapter = New-Object System.Data.SqlClient.SqlDataAdapter($SQLcommand)
		} #begin

		process{
			# query and return
			try{			
				[void]$SQLadapter.Fill($dataSet)
				$dataSet.Tables[0]
			} catch {
				throw $_
			}
		} #process
	} #function Invoke-SQLquery

### Function DEF END
	Write-Verbose -Message "Setting up prerequirements"

	## Primer: ErrorActionPreference
	$ErrorActionPreference = "Stop"

	# Connect to the database
	try{
		Connect-SMTP
	} catch {
		Write-Error -EA 'Continue' -ErrorRecord $_
	}
} #begin

process
{
  if ($ComputerName.count -eq 0 -and $IPaddress.count -eq 0) {
    Write-Output "Seriously?"
  }

  ## Hostname check
  foreach ($hostname in $ComputerName) {
    Write-Output "- Looking up DNS: $hostname"
    try {
      ## Find Dns records
      $DNSdata = Resolve-DnsName -Name $hostname

    } catch [System.ComponentModel.Win32Exception] {
      if ($_.Exception.Message -like '* : DNS name does not exist') {
        $DNSdata = $null
      } else {
        throw $_
      } #if-else

    } catch {
      throw $_
    } #try-catch

    if ($null -ne $DNSdata) {
      # DNS record(s) found
      $outstring = $DNSdata | Format-List Name, Type, NameHost, IPAddress | Out-String
      # workaround for extra newlines before and after FL
			Write-Output  "$($outstring.trim()) `n"
		} else {
			Write-Output "Not record found.`n"
    } # if-else dnsdata
		
    Write-Output "- Looking up SMTP: $hostname"
		if ($script:SQLconn.State -eq "Open") {
			# set up query
			$query = "Select IP, DeviceName FROM [table].[database].[container] WHERE DeviceName = '$hostname'"
			
			# ask kindly
			try{
				$SMTPdata = Invoke-SQLquery -Query $query
			} catch {
				Write-Error -EA 'continue' -ErrorRecord $_
				continue
			}

			# add result
			if ($null -ne $SMTPdata) {
				$outstring = $SMTPdata | Format-List DeviceName, IP | Out-String
				# workaround for extra newlines before and after FL
				Write-Output  "$($outstring.trim()) `n"
			} else {
				Write-Output "Not record found.`n"
			} #if-else SMTPdata
		} #if SMTP connected

  } #foreach
  
  ## IP check
  foreach ($ip in $IPaddress) {
    Write-Output "- Looking up DNS: $ip"
		try {
			# Find Dns records
			$DNSdata = Resolve-DnsName -Name $ip

		} catch [System.ComponentModel.Win32Exception] {
			if ($_.Exception.Message -like '* : DNS name does not exist') {
				$DNSdata = $null
			} else {
				throw $_
			} # else

		} catch {
			throw $_
		} #try-catch

		if ($null -ne $DNSdata) {
			# DNS record(s) found
			$outstring = $DNSdata | Format-List Name, Type, NameHost, IPAddress | Out-String
      # workaround for extra newlines before and after FL
			Write-Output "$($outstring.trim()) `n"
		} else {
			Write-Output "Not record found.`n"
		} # if-else dnsdata

		Write-Output "- Looking up SMTP: $ip"
		if ($script:SQLconn.State -eq "Open") {
			# set up query
			$query = "Select IP, DeviceName FROM [table].[database].[container] WHERE IP = '$ip'"
			
			# ask kindly
			try{
				$SMTPdata = Invoke-SQLquery -Query $query
			} catch {
				Write-Error -EA 'continue' -ErrorRecord $_
				continue
			}

			# add result
			if ($null -ne $SMTPdata.IP) {
				$outstring = $SMTPdata | Format-List DeviceName, IP | Out-String
				# workaround for extra newlines before and after FL
				Write-Output  "$($outstring.trim()) `n"
			} else {
				Write-Output "Not record found.`n"
			} #if-else SMTPdata
		} #if SMTP connected
	} #foreach
} #process

end{
	Disconnect-SMTP
} #end