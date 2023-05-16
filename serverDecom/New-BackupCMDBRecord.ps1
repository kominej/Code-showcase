<#
.SYNOPSIS
	Creates new record in BackupCMDB for provided hostname(s).

.PARAMETER ComputerName
	If the server is not <domain>, use its FQDN

.PARAMETER Country
	Keep in mind that some countries come in a bundle, namely <multiple regions> and <multiple regions>.
	If the country is not on the list use Unlisted and notify Storage&Backup and webJea admin so that they can be added.
	
#>

# webjeausername is a builtin variable passing invoker's username
param(	
	$webjeausername,

	[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
	[int]
	$Ticket,
	
	[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
	[string[]]
	$ComputerName,

	[Parameter(Mandatory, ValueFromPipelineByPropertyName, HelpMessage = "Country or Region the server belongs to.")]
	[string]
	[ValidateSet('Unlisted','<region>','<region>','<region>','<region>','<region>','<region>','<region>')]
	$Country = '<defaultRegion>'
) #param

begin{

### Function def BEGIN
## MySQL communication
	function Connect-BackupCMDB{
		<#
		.SYNOPSIS
			Open connection to Backup CMDB.

		.PARAMETER Server
			[string] Hostname of the database server

		.PARAMETER Database
			[string] Name of the database

		.EXAMPLE
			Connect-BackupCMDB
			Defaults to preset server and database for BackupCMDB.

		.EXAMPLE
			Connect-BackupCMDB -Server servername -Database databaseName

		.INPUTS
			None
			
		.OUTPUTS
			None
		#>
		param(
			[string]
			$Server = '<server>',
			
			[string]
			$Database = '<server>'
		) #param

		process{
			# if already connected -> skip
			if($script:mySQLcon.State -ne 'Open'){
				Write-Verbose -Message 'Establishing connection'

				# BackupCMDB creds
				$creds = [pscredential]::new('<login>', '<password>')
				
				# load up MySQL preReqs
				Write-Verbose -Message '- Loading assemblies'
				$null = [System.Reflection.Assembly]::LoadWithPartialName('MySQL.Data')
	
				# set up connection
				Write-Verbose -Message '- Setting up connection parameters'
				$script:mySQLcon = New-Object MySql.Data.MySqlClient.MySqlConnection
				$script:mySQLcon.ConnectionString = "Server=$Server;Database=$Database;User Id=<login>;Password=<password>"
	
				# do you even MySQL?
				try {
					Write-Verbose -Message "- Connecting to $Server"
					$script:mySQLcon.Open()
				} catch {
					throw $_
				} #try-catch
	
			} #if			
		} #process
	} #function Connect-BackupCMDB
	
	function Disconnect-BackupCMDB{
		<#
		.SYNOPSIS
			Close connection to Backup CMDB.

		.EXAMPLE
			Disconnect-BackupCMDB

		.INPUTS
			None
			
		.OUTPUTS
			None
		#>

		process{
			try {
				Write-Verbose -Message 'Closing connecting to BackupCMDB'
				$script:mySQLcon.Close()
			} catch {
				throw $_
			} #try-catch

		} #process

	} #function Disconnect-BackupCMDB

	function Invoke-MySQLquery{
		<#
		.SYNOPSIS
			Query the connected database for data.

		.PARAMETER Query
			MANDATORY; [string] Full query to the database

		.EXAMPLE
			Invoke-MySQLquery -Query "SELECT * FROM [table] WHERE stringVariable LIKE 'stringValue%'"
			Queries the connected database for rows where stringVariable starts with 'stringValue'.
			Returns all data available for the matching rows.
			
		.EXAMPLE
			Invoke-MySQLquery -Query "SELECT intVariable, otherVariable  FROM [table] WHERE intVariable IN (0..20)"
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
			Write-Verbose -Message 'Creating MySQL query'
			# Verify database connection
			if($null -eq $script:mySQLcon){
				try{
					Connect-BackupCMDB
				} catch {
					throw $_
				}
			}
			Write-Verbose -Message '- loading connection'
			$mySQLcommand = New-Object MySql.Data.MySqlClient.MySqlCommand($Query, $script:MySQLcon)
			$mySQLcommand.CommandTimeout = 20

			Write-Verbose -Message '- creating containers'
			$dataSet = New-Object System.Data.DataSet
			$mySQLadapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($mySQLcommand)
		} #begin

		process{
			Write-Verbose -Message 'Calling query'
			# query and return
			try{
				[void]$mySQLadapter.Fill($dataSet)
				$dataSet.Tables[0]
			} catch {
				throw $_
			}
		} #process
	} #function Invoke-MySQLquery

## New ticket and comment entry, lookup country ID (required by New/Edit process)
	function New-BackupComment{
		param(			
			[Parameter(Mandatory)]
			[int]
			$ServerID,

			[Parameter(Mandatory)]
			[int]
			$TicketID,

			[Parameter(Mandatory)]
			[string]
			$InvokerName
		) #param
		process{
			# query setup
			$query = "INSERT INTO <table>
			SET
				server_id = $ServerID,
				timestamp = NOW(),
				user = '$script:userID',
				comment = 'Decommissioned by $script:userID, CT-$TicketID';
			SELECT LAST_INSERT_ID() as ID;"

			# query execution
			Write-Verbose -Message 'Creating new backup comment.'
			try{
				$backupCommentID = Invoke-MySQLquery -Query $query | Select-Object -ExpandProperty ID
			} catch {
				throw $_
			} #try-catch

			return $backupCommentID
		} #process
	} #function New-BackupComment

	function New-BackupTicket{
		param(
			[Parameter(Mandatory)]
			[int]
			$ServerID,

			[Parameter(Mandatory)]
			[int]
			$TicketID,

			[Parameter(Mandatory)]
			[string]
			$InvokerName
		) #param
		process{
			# query setup
			$query = "INSERT INTO <table>
			SET
				server_id = $ServerID,
				timestamp = NOW(),
				user = '$script:userID',
				ticket = 'CT-$TicketID';
			SELECT LAST_INSERT_ID() as ID;"

			# query execution
			Write-Verbose -Message 'Creating new backup ticket.'
			try{
				$backupTicketID = Invoke-MySQLquery -Query $query | Select-Object -ExpandProperty ID
			} catch {
				throw $_
			} #try-catch

			return $backupTicketID
		} #process
	} #function New-BackupTicket

	function Get-Country{
		param(
			[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
			[string]
			$Country
		) #param

		process{
			Write-Verbose -Message 'Getting country ID from database.'
			if($country -eq 'Unlisted'){
				$script:countryID = 63
			} else {
				# query setup
				if($Country -like '* DC'){
					$query = "SELECT ID FROM <table> WHERE name LIKE '$Country%'"
				}else{
					$query = "SELECT ID FROM <table> WHERE name = '$Country'"
				}
				

				# query execution
				try{
					$script:countryID = Invoke-MySQLquery -Query $query | Select-Object -ExpandProperty ID
				} catch {
					throw $_
				}

				# validate
				if($null -eq $countryID){
					throw "Error: Country not found."
				}

			} #if:else
		} #process
	} #function Get-Country
	
### Function def END

	Write-Verbose -Message "Setting up prerequirements"

	## Primer: ErrorActionPreference
	$ErrorActionPreference = "Stop"

	## Primer: ErrorAction
	if($PSBoundParameters.keys.Contains("ErrorAction")) { 
		$EA = $PSBoundParameters["ErrorAction"]
	} else {
		$EA = "Stop"
	} #if-else

	# Connect to the database
	try{
		Connect-BackupCMDB
	} catch {
		Write-Error -EA $EA -ErrorRecord $_
	} #try-catch

	Write-Verbose -Message 'Looking up variables required for new record.'
	$variableOption = Invoke-MySQLquery -Query "SELECT ID FROM <table> WHERE name = 'N'" | Select-Object -ExpandProperty ID
	$backupOption = Invoke-MySQLquery -Query "SELECT ID FROM <table> WHERE name = 'none'" | Select-Object -ExpandProperty ID
	Get-Country -Country $Country

	# invoker username, domain name removed
	$script:userID = $webjeausername.split("\")[1]
} #begin

process {
	foreach($hostname in $ComputerName){
		# hostname validity check
		if($hostname.Length -ne 13){
			$dotCount = ($hostname.ToCharArray() | Where-Object {$_ -eq '.'} | Measure-Object).Count
			if($dotCount -lt 2){
				Write-Warning -WA 'continue' -Message "Hostname $hostname doesn't follow <group> standard. Did you forget a domain name?"
				continue
			}			
		}

		## server record creation
		# query setup
		$query = "INSERT INTO <table> SET
				backup_countries_id = $script:countryID,
				timestamp           = NOW(),
				edited_by           = '$script:userID',
				server_name         = '$hostname',
				file_role_id        = $variableOption,
				print_role_id       = $variableOption,
				DP_agent_id         = $variableOption,
				BE_agent_id         = $variableOption,
				backup_options_id   = $backupOption,
				in_scope_id         = $variableOption,
				quiesced_backup     = $true,
				Veeam_agent_id      = 2;
			SELECT LAST_INSERT_ID() as ID;"
		
		# query execution
		try{
			$serverRecord = Invoke-MySQLquery -Query $query
		} catch {
			throw $_
		}

		<# create backup ticket and comment for edit
		$backupCommentID = New-BackupComment -ServerID $($serverRecord.ID) -TicketID $Ticket -InvokerName $userID
		$backupTicketID = New-BackupTicket -ServerID $($serverRecord.ID) -TicketID $Ticket -InvokerName $userID
		#>
		## Add ticket and comment IDs to record
		# query setup
		$query = "UPDATE <table> 
		SET
			tickets = 'CT-$Ticket',
			comments = 'Decommissioned by $script:userID, CT-$Ticket',
			last_ticket_id = $backupTicketID,
			last_comment_id = $backupCommentID
		WHERE id = $($serverRecord.ID)"

		# query execution
		try{
			Invoke-MySQLquery -Query $query
		} catch {
			throw $_
		}

	} #foreach ComputerName
} #process

end{
	Disconnect-BackupCMDB
} #end