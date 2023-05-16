function Get-ServerInfo{
	param(
	 [Parameter(Mandatory,Position=0,ValueFromPipeline)]
	 [string[]]
	 $ComputerName,

	 [string]
	 $SQLServer="<server>",

	 [string]
	 $SQLDBName="<database>",

	 [Int32]
	 $QueryTimeout = 60,

	 [string[]]
	 $Select = @("Name","Powerstate","GuestToolStatus","vCenter","VMHost","vNICcount","GuestIPAddress0","GuestIPAddress2","NetworkName0","OS","AppFunction","ServerRole","AppName","Owner","Priority","Region","BillingID","DisasterRecovery")

	) #param

	begin{
		$conn = new-object System.Data.SqlClient.SQLConnection
		$conn.ConnectionString="Server=$SQLServer;Database=$SQLDBName;Integrated Security=SSPI"
		$conn.Open()

		if ($select -contains "*") {
			[string]$select = "*"

		} else { #compare input with valids
			$ValidSet = @('AppFunction', 'AppName', 'BillingID', 'ChangeVersion', 'CpuSharesLevel', 'DatastoreCluster', 'Date1', 'Date2',
				'DateTime', 'Datum', 'DisasterRecovery', 'Disk0CapacityKB', 'Disk0Filename', 'Disk0Format', 'Disk1CapacityKB', 'Disk1Filename',
				'Disk1Format', 'Disk2CapacityKB', 'Disk2Filename', 'Disk2Format', 'Disk3CapacityKB', 'Disk3Filename', 'Disk3Format',
				'DiskUuidEnabled', 'FAGosAgent', 'Filename', 'Folder', 'GuestIPAddress0', 'GuestIPAddress1', 'GuestIPAddress2', 'GuestIPAddress3',
				'GuestToolStatus', 'HWVersion', 'InstanceUUID', 'LegalEntity', 'MemSharesLevel', 'MemoryMB', 'Name', 'NetworkConnected0',
				'NetworkConnected1', 'NetworkConnected2', 'NetworkConnected3', 'NetworkName0', 'NetworkName1', 'NetworkName2', 'NetworkName3',
				'NumCPU', 'NumCoresPerSocket', 'NumCpuShares', 'NumMemShares', 'NumSocket', 'OS', 'Owner', 'Powerstate', 'Priority', 'Region',
				'ResourcePool', 'RowNumber', 'ServerBuildDate', 'ServerRole', 'Ticket', 'ToolsVersion', 'UUID', 'VMHost', 'iSCSI', 'vCenter',
				'vNICcount', 'vNICmac0', 'vNICmac1', 'vNICmac2', 'vNICmac3', 'vNICtype0', 'vNICtype1', 'vNICtype2', 'vNICtype3')

			# logic: filter out valids, check if any are remaining
			$invalids = $select | Where-Object {$_ -notin $ValidSet}
			if ( $null -ne $invalids ) { 
				Write-Error -EA $EA -Message ("Invalid return data selected. Total: $($invalids.count)`n$($invalids -join ", ")") 

			} else {
				# convert to SQL query format
				[string]$select = $Select -join ', '

			} #if-else !invalids
		} #if-else Filter selection
	} #begin

	process {
		foreach ($hostname in $ComputerName) {
			# create query
			$query = "SELECT $select FROM [table].[database].[container] WHERE Name LIKE '"+$hostname+"%'"
			$cmd = new-object system.Data.SqlClient.SqlCommand($Query,$conn)
			$cmd.CommandTimeout = $QueryTimeout

			# assign containers
			$ds = New-Object system.Data.DataSet
			$da = New-Object system.Data.SqlClient.SqlDataAdapter($cmd)

			# parse response
			[void]$da.fill($ds)

			# print results
			Write-Output $ds.Tables[0]

			# print vCenter URL
			if($ds.Tables[0].vCenter) {
				Write-Output "https://$($ds.Tables[0].vCenter)/ui/"
			}
		} #foreach ComputerName
 	} #process
	
	end { $conn.Close() } #end 
}