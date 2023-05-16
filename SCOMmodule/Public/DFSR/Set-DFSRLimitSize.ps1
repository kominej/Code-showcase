function Set-DFSRLimitSize{
	<#
	.SYNOPSIS
		Set DFS staging quota (limit) to specified value.
	
	.PARAMETER ComputerName
		Mandatory; [string] Hostname of member (computer) to be edited.

	.PARAMETER GroupName
		Mandatory; [string] Name of group to be edited.

	.PARAMETER FolderName
		Mandatory; [string] Name of folder to be edited.

	.PARAMETER NewQuota
		Mandatory; [uint32] Value to which the staging quota is to be set.

	.EXAMPLE
		Set-DFSRLimitSize -ComputerName server -GroupName group -FolderName folder -NewQuota 123456

	.EXAMPLE
		Set-DFSRLimitSize server group folder 123456

	.INPUTS
		None.
		
	.OUTPUTS
		None.
	#>
	param(
		[Parameter(Mandatory, Position = 0)]
		[string]
		$ComputerName,

		[Parameter(Mandatory, Position = 1)]
		[string]
		$GroupName,

		[Parameter(Mandatory, Position = 2)]
		[string]
		$FolderName,
		
		[Parameter(Mandatory, Position = 3)]
		[uint32]
		$NewQuota

	) #param

	begin{
		Write-Verbose -Message 'Checking for DFSR module'
		try {
			$null = Get-Command Set-DfsrMembership
			Write-Verbose -Message 'DFSR module found'
			
		} catch	{
			Write-Warning -Message ("Cannot locate DFSR commands. Make sure RSAT is properly installed.")
			return

		} #if DFSR installed
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
			
			#set found object's new Staging quota and print new state
			$newRecord = Set-DfsrMembership -GroupName $DFSMember.GroupName -ComputerName $DFSMember.ComputerName -FolderName $DFSMember.FolderName -StagingPathQuotaInMB $newQuota
			$newRecord | Format-List GroupName,ComputerName,FolderName,@{Name="Quota"; Expression={ $_.StagingPathQuotaInMB}}

		} #if-elseif-else Record count
	} #process
}