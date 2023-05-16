function Set-DFSRLimitIncrement{
	<#
	.SYNOPSIS
		Increase DFS staging quota (limit) by specified value.
	
	.PARAMETER ComputerName
		Mandatory; [string] Hostname of member (computer) to be edited.

	.PARAMETER GroupName
		Mandatory; [string] Name of group to be edited.

	.PARAMETER FolderName
		Mandatory; [string] Name of folder to be edited.

	.PARAMETER Increment
		Mandatory; [uint32] Value by which to increase the staging quota.

	.EXAMPLE
		Set-DFSRLimitIncrement -ComputerName server -GroupName group -FolderName folder -Increment 10000

	.EXAMPLE
		Set-DFSRLimitIncrement server group folder 10000

	.INPUTS
		None.
		
	.OUTPUTS
		None.
	#>
	[CmdletBinding(DefaultParameterSetName = 'Manual')]

	param(
		[Parameter(Mandatory, Position = 0, ParameterSetName = 'Manual')]
		[string]
		$ComputerName,

		[Parameter(Mandatory, Position = 1, ParameterSetName = 'Manual')]
		[string]
		$GroupName,

		[Parameter(Mandatory, Position = 2, ParameterSetName = 'Manual')]
		[string]
		$FolderName,

		[Parameter(ValueFromPipelineByPropertyName, ParameterSetName = 'SCOMalert')]
		[int32[]]
		$SCOMalert,

		[Parameter(Position = 3, ParameterSetName = 'Manual')]
		[Parameter(ValueFromPipelineByPropertyName, ParameterSetName = 'SCOMalert')]
		[int32]
		$Increment = 10000

	) #param

	begin{
		Write-Verbose -Message 'Checking for DFSR module'
		try {
			$null = Get-Command Set-DfsrMembership
			Write-Verbose -Message 'DFSR module found'
			
		} catch	{
			Write-Warning -Message ("Cannot locate DFSR commands. Make sure RSAT is properly installed.")
			return

		} #try-catch
	} #begin

	process{
		#retrieve DFS object
		$DFSMember = Get-DfsrMembership -GroupName $GroupName -ComputerName $ComputerName | Where-Object FolderName -eq $FolderName | Select-Object GroupName,ComputerName,FolderName,@{Name="Quota"; Expression={ $_.StagingPathQuotaInMB}}

		if ($null -eq $DFSMember) { #no results
			Write-Warning "No results found. Please adjust filter parameters."

		} elseif ($DFSMember -is [array]) { #multiple results
			Write-Warning "Multiple search results. Please adjust filter parameters."			

		}	else { #only one found		
			# print original state
			$DFSMember | Format-List
			
			$newQuota = $DFSMember.Quota + $Increment			
			Write-Information -InformationAction Continue -MessageData "Increasing Staging quota to $newQuota"
			
			#set found object's new Staging quota and print new state
			$newRecord = Set-DfsrMembership -GroupName $DFSMember.GroupName -ComputerName $DFSMember.ComputerName -FolderName $DFSMember.FolderName -StagingPathQuotaInMB $newQuota
			$newRecord | Format-List GroupName,ComputerName,FolderName,@{Name="Quota"; Expression={ $_.StagingPathQuotaInMB}}

		} #if-elseif-else DFSRmember validation
	} #process
} #function Set-DFSRLimitIncrement