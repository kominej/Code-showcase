<#
.SYNOPSIS
  Sets Archived state, decommission ticket and date and otherwise required data to a CMDB record of a server.
  Currently not set up for cloud servers.

#>
# webjeausername is a builtin variable for passing invoker's username
param(
	$webjeausername,

  [Parameter(Mandatory)]
  [string[]]
  $ComputerName,

  [Parameter(Mandatory)]
  [int32]
  $Ticket,

  [string]
  [ValidateSet('Virtual', 'Physical')]
  $TypeOfAsset = 'Virtual',

  [switch]
  $RemoveOrion

) #param

begin {

  ### Function DEF Begin

	function New-LogEntry{
		param(
			[Parameter(Mandatory, ValueFromPipeline)]
			[string]
			$Entry
		) #param

		begin {
			$date = Get-Date -Format "yyyyMMdd"
			$filePath = "<path>\$date.log"
			
			$fileExists = Test-Path -Path $filePath
			if (-not $fileExists) {
				$null = New-Item -ItemType 'File' -Path "<path>\" -Name "$date.log"
			}
		} #begin

		process {
			$dateTime = Get-Date -format "yyyy/MM/dd hh:mm:ss"
			Add-Content -Path $filePath -Value "$dateTime - $entry"
		} #process
	} #function New-LogEntry

### Function DEF End

  ## Primer: ActionPreferences
	$ErrorActionPreference = "Stop"

  ## Primer: ErrorAction
	if ($PSBoundParameters.keys.Contains("ErrorAction")) {
		$EA = $PSBoundParameters["ErrorAction"]
	} else {
		$EA = "Stop"
	} #if-else

  ## Module import
  Import-Module CherwellHelper -ErrorAction 'Stop'

} #begin

process {
  Write-Verbose -Message 'Setting up return data'
  $returnFields = 'FriendlyName', 'CIStatus', 'DecommissionDate', 'DecommissionTicket', 'TypeOfAsset'

  ### GET records
  $cmdbRecords = foreach ($computer in $ComputerName) {
    Write-Verbose -Message "Processing $computer"
    try {
      if ($computer.indexof('.') -ne -1) {
        Write-Verbose -Message 'Domain search'
        $record = Get-ChWBusObjInstances -BusObjectName 'ConfigServer' -ReturnFields $returnFields -Filter "FriendlyName -eq ""$computer"""
        
      } else {
        Write-Verbose -Message 'Domainless search'
        $record = Get-ChWBusObjInstances -BusObjectName 'ConfigServer' -ReturnFields $returnFields -Filter "FriendlyName -eq ""$computer.domain.net"""
      }

      ### Validation checks
      ## no records
      if ($null -eq $record) {
        Write-Warning -WA 'Continue' -Message "No record found for '$computer'. Skipping."
        continue
      }
  
      ## multiple records
      if ($Record.count) {
        Write-Warning -WA 'Continue' -Message "Multiple records found for '$computer'. Skipping."
        continue
      }
      
      Write-Verbose -Message ' - Record retrieved'

      ## Virtual
      $recordAssetType = $record.fields | Where-Object Name -eq 'TypeOfAsset' | Select-Object -ExpandProperty Value
      if ($recordAssetType -ne $TypeOfAsset) {
        switch ($TypeOfAsset) {
          'Virtual'  { Write-Warning -WA 'Continue' -Message "Server '$computer' is not virtual (is $recordAssetType). Skipping." }
          'Physical' { Write-Warning -WA 'Continue' -Message "Server '$computer' is not physical (is $recordAssetType). Skipping." }
        }
        continue
      }
  
      ## Record status
      $recordStatus = $record.fields | Where-Object Name -eq 'CIStatus' | Select-Object -ExpandProperty Value
      if ($recordStatus -eq 'Archived') {
        Write-Warning -WA 'Continue' -Message "Server '$computer' is already archived. Skipping."
        continue
      }

      Write-Verbose -Message ' - Virtual/Physical AOK'

      ## Decom ticket & date
      $DecommissionDate = $record.fields | Where-Object Name -eq 'DecommissionDate' | Select-Object -ExpandProperty Value
      $DecommissionTicket = $record.fields | Where-Object Name -eq 'DecommissionTicket' | Select-Object -ExpandProperty Value

      $decomIssue = 0
      if ($DecommissionDate -ne '1/1/1900 12:00:00 AM' -and $DecommissionDate -ne '') {
        # has decom date
        $decomIssue =+ 1
      }

      if ($DecommissionTicket -ne '') {
        # has decom ticket
        $decomIssue =+ 2
      }

      # parse returned object
      $recordData = [PSCustomObject]@{
        Name = $record.fields | Where-Object Name -eq 'FriendlyName' | Select-Object -ExpandProperty value
        RecID = $record.busObRecId
      } #PSCustomObject

      if ($decomIssue -gt 0) {
        switch ($decomIssue) {
          1 {
            Write-Warning -WA 'Continue' -Message "Record for $($recordData.name) already has a decommission date (but no ticket) assigned. Skipping."
          }
          2 {
            Write-Warning -WA 'Continue' -Message "Record for $($recordData.name) already has a decommission ticket (but no date) assigned. Skipping."
          }
          3 {
            Write-Warning -WA 'Continue' -Message "Record for $($recordData.name) already has both decommission date and ticket assigned. Skipping."
          }
        } #switch 
        continue
      } #if decomIssue
      Write-Verbose -Message ' - Not yet decommed'

      Write-Verbose -Message $( $record.fields | Select-Object Name, Value | Out-String )

      # return record for further processing
      $recordData

    } catch {
      Write-Error -EA $EA -ErrorRecord $_
    } #try-catch
  }
  
  Write-Verbose -Message "All records retrieved (total: $($cmdbRecords.count))"

  ## CHECK no record found
  if ($null -eq $cmdbRecords) {
    Write-Output 'None of these princesses are in this castle Mario.'
    return
  }
  
  ### Update
  ## Prereqs - Change request body
  Write-Verbose -Message 'Setting up request body'
  switch ($TypeOfAsset) {
    'Virtual'  {
      $updateCO = [PSCustomObject]@{
        busObId = "<busID>" #Config - Server
        persists = "true"
        busObRecId = 0
       
        fields = @(
         @{
          dirty = "true"
          fieldID = "<fieldID>" #DecommissionDate
          Value = Get-Date -Format yyyy-MM-ddTHH:mm:ss
         },
         @{
          dirty = "true";
          fieldID = "<fieldID>" #DecommissionTicket
          Value = $Ticket
         },
         @{
          dirty = "true";
          fieldID = "<fieldID>" #CIStatus
          Value = "Archived"
         }
        )
       } #updateCO
    } #Virtual

    'Physical' {
      $updateCO = [PSCustomObject]@{
        busObId = "<busID>" #Config - Server
        persists = "true"
        busObRecId = 0
       
        fields = @(
          @{
            dirty = "true"
            fieldID = "<fieldID>" #DecommissionDate
            Value = Get-Date -Format yyyy-MM-ddTHH:mm:ss
          },
          @{
            dirty = "true"
            fieldID = "<fieldID>" #DecommissionTicket
            Value = $Ticket
          },
          @{
            dirty = "true"
            fieldID = "<fieldID>" #CIStatus
            Value = "Archived"
          },
          @{
            dirty = "true"
            fieldID = "<fieldID>" #AssetStatusV2
            Value = "Retired"
          }
        )
       } #updateCO
    } #Physical
  } #Switch

  ## Log
  $logEntry = "CMDB.edit - $webjeausername - $TypeOfAsset - $Ticket`n$($cmdbRecords.Name)"
  New-LogEntry -Entry $logEntry

  ## WRITE
  foreach ($record in $cmdbRecords) {
    Write-Output "Processing $($record.Name)"

    $updateCO.busObRecId = $record.RecID
    $updateBodyJSON = $updateCO | ConvertTo-Json

    try{
      $null = Invoke-ChWPost -PostAction 'UpdateBO' -RequestBody $updateBodyJSON

    } catch {
      Write-Error -EA 'Continue' -ErrorRecord $_
      continue
    } #try-catch
    
    Write-Output "CMDB record for $($record.Name) succesfully decomm'd."

  } #foreach

  if ($RemoveOrion) {
    Write-Output 'Accessing SolarWinds'
    & "$PSScriptRoot\Invoke-DecomSolarWinds.ps1" -webjeausername $webjeausername -ComputerName $cmdbRecords.Name -Remove
  }

} #process