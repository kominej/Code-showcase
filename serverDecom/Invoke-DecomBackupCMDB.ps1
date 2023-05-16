<#
.SYNOPSIS
	Check BackupCMDB for provided hostname and update the record if elligible.</br>
	If there is no record for the server, you'll be notifed to create it.</br>
	If Storage&Backup are required to make manual changes, you'll be notifed to send it to them.

#>

# webjeausername is a builtin variable for passing invoker's username
param(
	$webjeausername,

	[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
	[int]
	$Ticket,
	
	[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
	[string[]]
	$ComputerName
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
			$Database = '<database>'
		) #param
		#TODO: UN-HARDCODE PARAMETERS?

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
				$script:mySQLcon.ConnectionString = "Server=$Server;Database=$Database;;User Id=<login>;Password=<password>"
	
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

## New ticket and comment entry (required by New/Edit process)
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
				user = '$InvokerName',
				comment = 'Decommissioned by $InvokerName, CT-$TicketID';
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
				user = '$InvokerName',
				ticket = $TicketID;
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

## BackupCMDB Record management
	function Test-BackupRecord{
		param(
			[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
			[string[]]
			$ComputerName
		)
		process{
			# Custom object for results
			$resultData = [PSCustomObject]@{
				recordID = 0
				NoRecord = $false
				Share = $false
				DFSR = $false
				Agents = $false
				KBfollow = 0
				AOK = $true
			}

			# get them answers a-rollin'
			Write-Verbose -Message "Getting server record for $ComputerName."
			$query = "Select ID, Server_name, Backup2Share, DFSR_target_id, backup_server_id, BE_agent_id, DP_agent_id FROM <table> WHERE server_name = '$ComputerName'"
			try{
				$backupData = Invoke-MySQLquery -Query $query
			} catch {
				throw $_
			} #try-catch

			# check if record exists
			if($null -eq $backupData){
				$resultData.AOK = $false
				$resultData.NoRecord = $true
				Write-Verbose -Message 'Record not found.'
				return $resultData
			} else {
				Write-Verbose -Message "Found recordID: $($backupData.ID)."
				$resultData.recordID = $backupData.ID
			}

			Write-Verbose -Message 'Validating for decom edit.'
			# check for conditions requiring that extra touch from Backup&Storage
			<# Conditions
				Backup2Share               #string, looking for non-empty
				DFSR_target_id             #int32 or DBNull, looking for int32
				DP_agent_id & BE_agent_id  #both int32, looking for non-matching values
			#>
			Write-Verbose -Message "Backup2Share: '$($backupData.Backup2Share.GetType().Name)'"
			if($backupData.Backup2Share.GetType().Name -ne 'DBNull'){
				$resultData.AOK = $false
				$resultData.Share = $true
				Write-Verbose -Message 'Backup2Share assigned'
			}

			Write-Verbose -Message "DFSRTarget: '$($backupData.DFSR_target_id.GetType().Name)'"
			if($backupData.DFSR_target_id.GetType().Name -ne 'DBNull'){
				$resultData.AOK = $false
				$resultData.DFSR = $true
				Write-Verbose -Message 'DFSR target assigned'
			}

			Write-Verbose -Message "BackupServer: '$($backupData.backup_server_id)'"
			Write-Verbose -Message "Agents: 'DP $($backupData.DP_agent_id) | BE $($backupData.BE_agent_id)'"
			if($backupData.Backup_server_id.GetType().Name -ne 'DBnull'){
				# Escalation point
				if($backupData.DP_agent_id -eq 1 -and $backupData.BE_agent_id -eq 1){
					$resultData.AOK = $false
					$resultData.Agents = $true
					Write-Verbose -Message 'Both AgentID are ''Y''.'
				}
				
				if($backupData.DP_agent_id -ne $backupData.BE_agent_id){						
					if($backupData.Backup_server_id -in (1, 2, 3, 4, 5)) {
						$resultData.KBfollow = 6
						Write-Verbose -Message 'AgentID mismatch. BackupServer in list.'

					} else {
						$resultData.KBfollow = 7
						Write-Verbose -Message 'AgentID mismatch. BackupServer not in list.'

					} #if-else in listed backup_server_id
				} #if AgentIDs equal
			} #if backup_server_id				 

			return $resultData
		} #process
	} #function Test-BackupRecord

	function Edit-BackupRecord{
		param(
			[Parameter(Mandatory)]
			[int]
			$RecordID,
			
			[Parameter(Mandatory)]
			[int]
			$TicketID
		) #param

		begin{
			if(-not $script:varsInitialized){
				Write-Verbose -Message 'Looking up variables required for record edit.'
				# helper var
				$script:varsInitialized = $true
				# Decom edit prerequirements
				$script:variableOption = Invoke-MySQLquery -Query "SELECT ID FROM <table> WHERE name = 'N'" | Select-Object -ExpandProperty ID
				$script:backupOption = Invoke-MySQLquery -Query "SELECT ID FROM <table> WHERE name = 'none'" | Select-Object -ExpandProperty ID
			}
		} #begin

		process{
			# invoker username, domain name removed
      $userID = $webjeausername.split("\")[1]

			# create backup ticket and comment for edit
			$backupCommentID = New-BackupComment -ServerID $RecordID -TicketID $TicketID -InvokerName $userID
			$backupTicketID = New-BackupTicket -ServerID $RecordID -TicketID $TicketID -InvokerName $userID

			# query setup
			$query = "UPDATE <table>
			SET
				timestamp = NOW(),
				edited_by = '$userID',
				file_role_id = $script:variableOption,
				print_role_id = $script:variableOption,
				backup_options_id = $script:backupOption,
				in_scope_id = $script:variableOption,
				backup_server_id = NULL,
				tickets = CONCAT(tickets, ' # ', 'CT-$TicketID'),
				comments = CONCAT(comments, ' # ', 'Decommissioned by $userID, CT-$TicketID'),
				last_ticket_id = $backupTicketID,
				last_comment_id = $backupCommentID
			WHERE id = $recordID"

			# query execution
			try{
				Invoke-MySQLquery -Query $query
			} catch {
				throw $_
			}
		} #process
	} #function Edit-BackupRecord
	
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
} #begin

process{
	foreach($hostname in $ComputerName){
		$resultData = Test-BackupRecord $hostname
		
		# record not found
		if($resultData.NoRecord){
			Write-Output "Server $hostname couldn't be found. Create a new record."
			continue
		}

		# record found & no lvl3 required
		if($resultData.AOK){			
			try{
				Edit-BackupRecord -RecordID $resultData.recordID -TicketID $Ticket
				Write-Output "Server $hostname succesfully decomm'd."			
			} catch {
				Write-Error -EA 'Continue' "Server $hostname couldn't be decomm'd: $_"			
			}

			# manual touch required
			if($resultData.KBfollow -ne 0){
				Write-Warning -Message "You'll have to also do one thing manually for $hostname. Open <url> and go through the step $($resultData.KBfollow)"
			}

		} else {
		
			Write-Output "Server $hostname will require the attention of Storage&Backup for the following reasons:"
			if($resultData.Share){
				Write-Output "- server has Backup2Share assigned"
			}
			if($resultData.DFSR){
				Write-Output "- server has DFSR target assigned"
			}
			if($resultData.Agents){
				Write-Output "- BE and DP agents are both 'Y'"
			}
			if($resultData.KBfollow -ne 0){
				Write-Output "- BE and DP agents have different values"
			}

		}

	} #foreach
} #process

end{
	Disconnect-BackupCMDB
} #end