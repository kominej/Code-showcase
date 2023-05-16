<#
.SYNOPSIS
	Checks the provided server for basic decommission informations.
  
#>

param(
	[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
	[string[]]
	$ComputerName
) #param

begin{

### Function DEF Begin

function Get-CherwellData {
  param(
    [Parameter(Mandatory)]
    [string[]]
    $ComputerName

  ) #param

  begin {
    Write-Verbose "Loading CherWell module"
    Import-Module CherwellHelper -ErrorAction 'Stop' -Verbose:$false

    $returnFields = '<field>', '<field>' , '<field>', '<field>', '<field>', '<field>', '<field>', '<field>', '<field>'
  } #begin

  process {
    Write-Verbose "Looking up CMDB records (Queries: $($ComputerName.count))"
    foreach ($computer in $ComputerName) {
      try{
        ### Get Cherwell record
        ## GET
        if ($computer.indexof('.') -ne -1) {
          Write-Verbose -Message 'Domain search'
          $cmdbRecord = Get-ChWBusObjInstances -BusObjectName 'ConfigServer' -ReturnFields $returnFields -Filter "FriendlyName -startswith ""$computer"""
          
        } else {
          Write-Verbose -Message 'Domain-less search'
          $cmdbRecord = Get-ChWBusObjInstances -BusObjectName 'ConfigServer' -ReturnFields $returnFields -Filter "FriendlyName -eq ""$computer.<domain>.net"""
        }
        
        ## Validate
        if ($null -eq $cmdbRecord) {
          throw "${computer}: No record found."
        } #if

        if ($cmdbRecord -is [array]) {
          throw "${computer}: Multiple records found. Adjust filters and retry."
        } #if

        ## Parse
        $recordData = [PSCustomObject]@{
          RecID = $cmdbRecord.busObId
          Name = $cmdbRecord.busObPublicId
        }
        foreach ($field in $cmdbRecord.fields) {
          Add-Member -InputObject $recordData -MemberType NoteProperty -Name $field.name -Value $field.value
        }

        ## Return
        Write-Output $recordData

      } catch {
        Write-Error -ErrorRecord $_
        
      } #try-catch
    } #foreach    
  } #process
} #function Get-CherwellData

function Get-VMData {
  param(
    [Parameter(Mandatory)]
    [string]
    $ComputerName,

    [Parameter(Mandatory)]
    [string]
    $VCenter
  ) #param
  
  begin {
    Write-Verbose "Loading VMware module"
    Import-Module -Name VMware.VimAutomation.Core -ErrorAction 'Stop' -Verbose:$false

    # Connect to ESXi
    Write-Verbose -Message "- Connecting to $VCenter"
    try {
      Connect-VIServer -Server $VCenter -ErrorAction 'Stop' -Verbose:$false | Out-Null
    } catch {
      Write-Error -EA 'continue' -Message "Could not establish connection with vCenter $VCenter"
      continue
    }
  } #begin

  process {
    $VMdata = [PSCustomObject]@{
        Name        = $ComputerName
        PoweredOn   = $null
        IP          = $null  
      } #VMdata

      # get VM object
      try {
        Write-Verbose -Message '- Getting VM'
        $VMobject = Get-VM -Name $ComputerName -Verbose:$false | Select-Object Powerstate, Guest

      }	catch {
        Write-Error -EA 'continue' -ErrorRecord $_
        continue
      } #try-catch

      ### GET Data
      ## General data
      try{
        $VMdata.PoweredOn   = $VMobject.Powerstate -eq 'PoweredOn'
        # regex incoming; the following is the IP format ###.###.###.###; doesn't check for numbers beyond 255 though
        $VMdata.IP          = $VMobject.Guest.IPAddress -match '\d{1,3}(\.\d{1,3}){3}' -join ', '

        return $VMdata
      } catch {
        Write-Error -EA $EA -Message "Unable to parse VM data."

      } #try-catch data parse
  } #process

  end {
    Write-Verbose -Message "- Disconnecting from $vCenter"
    Disconnect-VIServer -Server $vCenter -Confirm:$false -Verbose:$false
  } #End
} #function Get-CherwellData

function Confirm-Datacenter {
  [CmdletBinding(DefaultParameterSetName='err')]
  param(
    [Parameter(Mandatory, ParameterSetName='vCenter')]
    [string]
    $vCenter,

    [Parameter(Mandatory, ParameterSetName='Location')]
    [string]
    $Location
  ) #param

  process {
    switch($PsCmdlet.ParameterSetName) {
      'vCenter' {
        if ($vCenter -in ('<server>','<server>','<server>','<server>')) {
					# DC
          Write-Verbose -Message "Server is DC."
					return $true

				}	elseif ($vCenter -in ('<server>','<server>','<server>')) {
					# Remote
          Write-Verbose -Message "Server is Remote."
					return $false

				} else {
					# Unknown -> Error
					throw
				} #if-elseif-else DC

      } #vCenter

      'Location' {
        # parse SID out of address
        $sid = [int]($resultData.Location.substring($resultData.Location.IndexOf('(SID')+4,4).replace(')',''))
        Write-Verbose -Message "SID: $sid"

        if ($sid -in (<ID>, <ID>, <ID>)) {
          #DC
          Write-Verbose -Message "Server is DC."
          return $true
    
        }	else {
          ## Remote
          Write-Verbose -Message "Server is Remote."
          return $false
        }
      } #SID

      default {
        throw "Unknown parameter set."
      } #err
    }
    

  }
}
function Confirm-SQLRegistry{
  <#
  .SYNOPSIS
    Lookup for registry value 'SQL' on provided hostname.

  .PARAMETER ComputerName
    MANDATORY; [string] Hostname of the decommissioned server

  .EXAMPLE
    Confirm-SQLRegistry -ComputerName servername

  .INPUTS
    None
    
  .OUTPUTS
    [bool] Registry value
  #>
  param(
    [Parameter(Mandatory)]
    [string]
    $ComputerName
  ) #param
  
  process{
    try{
      # Connect to remote registry
      Write-Verbose -Message 'Opening Remote registry connection'
      $registryConnection = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $ComputerName)
      
      # Open registry Key and retrieve Value for SQL
      Write-Verbose -Message 'Retrieving registry value'
      
      return $registryConnection.OpenSubKey("SOFTWARE\Microsoft\Microsoft Operations Manager").GetValue('SQL') -as [bool]
      # returns False if Err404
      
    } catch [System.Management.Automation.MethodInvocationException] {
      if ($_.Exception.InnerException.Mesage -eq 'The Network path was not found.') {
        Write-Error -Message 'Could not connect to server.' -err
      } else {
        Write-Error -ErrorRecord $_
      } #if-else

    } catch {
      Write-Error -ErrorRecord $_
    } #try-catch

  } #process
} #function Confirm-SQLRegistry

function Get-InstalledSoftware{
  <#
  .SYNOPSIS
    Retrieves all isntalled software on provided hostname.

  .PARAMETER ComputerName
    MANDATORY; [string] Hostname of the decommissioned server

  .EXAMPLE
    Get-InstalledSoftware -ComputerName servername

  .INPUTS
    None
    
  .OUTPUTS
    [string[]] Names of installed software 
  #>
  param(
    [Parameter(Mandatory)]
    [string]
    $ComputerName,
    
    [string]
    $SoftwareFilter = 'Citrix|SnapDrive'
  ) #param
  process{
    try{
      # get installed software
      $software = Get-CimInstance -ComputerName $ComputerName -Class Win32_Product -Verbose:$false
      
      # filter out the trash
      $software | Select-Object -ExpandProperty Name | Where-Object {
        $_ -Match $SoftwareFilter
      }
    } catch {
      Write-Error -ErrorRecord $_
    }
  }
} #function Get-InstalledSoftware

function Get-IPaddresses {
  param(
    [Parameter(Mandatory)]
    [string[]]
    $ComputerName

  ) #param

  process {
    foreach ($computer in $ComputerName) {
      try {
        ## 
        $cimSes = New-CimSession -ComputerName $ComputerName

        ## 
        $ips = Get-NetIPAddress -CimSession $cimSes
      } catch {
        throw "Unable to retrieve IP addresses"
      }

      # return findings
      $ips | Where-Object {
        $_.AddressFamily -eq 'IPv4' -and 
        $_.InterfaceAlias -ne 'Loopback Pseudo-Interface 1'
      }
    } #foreach    
  } #process
} #function Get-IPaddresses

### Function DEF end

	Write-Verbose -Message "Setting up prerequirements"

	## Primer: ErrorActionPreference
	$ErrorActionPreference = "Stop"

	## Primer: ErrorAction
	if($PSBoundParameters.keys.Contains("ErrorAction")) { 
		$EA = $PSBoundParameters["ErrorAction"]
	} else {
		$EA = "Stop" 
	} #if-else
	
} #begin

process{
  ## MCS check
  # MCS servers are handled by <team>; confirmed by <user> @16.11.2021
  if ($ComputerName -match '<regexQuery>') {
    Write-Warning -WA 'Continue' -Message "Decommission of <type> servers is handled directly by <team>. Skip creating any WI and forward the entire ticket to them."
    return
  }

#Write-Information -InformationAction 'Continue' -MessageData "DataContainer"

  <#$global:serverData = #>foreach ($computer in $ComputerName) {
    ## Server data, centralized for later print
    $resultData = [PSCustomObject]@{
      Hostname    = $computer
      Owner       = $null
      HWType      = $null # for WI QuickCall template selection
      Location    = $null # for WI QuickCall template selection
      DC          = $null # for WI QuickCall template selection
      Management  = $null # vCenter/iDRAC/iLo
      OS          = $null # for multi-server decom validity check
      ServerType  = $null # for multi-server decom validity check
      IP          = $null # print; users should copy to some of the WI
      AV          = $null
      Storage     = $null
      Citrix      = $null
      Database    = $null
      DR          = $null
    } #resultData

#Write-Information -InformationAction 'Continue' -MessageData "Cherwell"

		### Cherwell data
		## GET
		$chwData = Get-CherwellData -ComputerName $computer
		
		##Validate
		if ($null -eq $chwData) {
			Write-Error -EA 'Continue' -Message "${computer}: Unable to retrieve CMDB record. Skipping."
			Continue
		}
		
#Write-Information -InformationAction 'Continue' -MessageData "Convert"

		## 1:1 data copy
		try {
			$resultData.Owner = $chwData.ApplicationOwner
			$resultData.HWType = $chwData.TypeOfAsset
      $resultData.Location = $chwData.Location
			$resultData.Management = $chwData.ManagementIPiDRACiLOOrVCenter
			$resultData.ServerType = $chwData.ApplicationFunction
			$resultData.IP = $chwData.IPAddress, $chwData.AdditionalIPAddress #failover if later steps cannot retrieve IPs
			$resultData.OS = $chwData.OperatingSystem
			$resultData.AV = $chwData.McAfeeRepository ## Antivirus check
			$resultData.DR = $chwData.DRProtected ## Disaster recovery Check

		} catch {
			# shouldn't prop
			Write-Error -EA 'Continue' -Message "${computer}: Unable to process CMDB record. Skipping."
      $resultData
			continue
		}

#Write-Information -InformationAction 'Continue' -MessageData "HW check"

		## Virtual/Cloud/Physical check
		if($chwData.TypeOfAsset -eq 'Virtual') {
			if($chwData.Manufacturer -eq 'VMWare') {

#Write-Information -InformationAction 'Continue' -MessageData "VM"

				# Virtual - VMware	
        Write-Verbose -Message "Server is Virtual."
	
        ## DC/Remote check
				$resultData.DC = Confirm-Datacenter -vCenter $resultData.Management

				### VM data - VMware only
				## GET
				try {
          $vmData = Get-VMdata -ComputerName $computer -VCenter $resultData.Management
        } catch {
          Write-Warning -WA 'Continue' -Message "${computer}: Unknown vCenter. Manual DC/Remote check required."
        }

				## Validate
				if ($null -eq $vmData) {
					Write-Error -EA 'Continue' -Message "Unable to retrieve VM object for $computer."					
				}

				# VMware IP override
				$resultData.IP = $vmData.IP

			} elseif ($chwData.Manufacturer -eq 'Microsoft') {

#Write-Information -InformationAction 'Continue' -MessageData "Cloud"

				# Cloud - Azure
        Write-Verbose -Message "Server is Cloud."
        $resultData.HWType = 'Cloud'
				
        # cloud apparently doesn't have database, citrix or storage servers
        $resultData.Database = $false
        $resultData.Citrix = $false
        $resultData.Storage = $false
        
				Write-Verbose -Message "${computer}: Cloud server. Skipping VMware check."
        
			} #if-else vmWare
		} else {
        
#Write-Information -InformationAction 'Continue' -MessageData "Physical"

			## Physical
      Write-Verbose -Message "Server is Physical."

      try {
        $resultData.DC = Confirm-Datacenter -Location $chwData.Location
      } catch {
        Write-Warning -WA 'Continue' -Message "${computer}: Unable to get Location SID. Manual DC/Remote check required."
      }
			Write-Verbose -Message "${computer}: Physical server. Skipping VMware check."		

		} #if-else virtual
		

		### Checks
        
#Write-Information -InformationAction 'Continue' -MessageData "OS"

    ## OS check
    if ($resultData.OS -notlike 'Microsoft Windows Server*') {
      # not windows
      
      if ($resultData.OS -like '*linux*') {
        # Linux/Oracle database servers are not a concern of <team>; confirmed by <user> @18.2.2021
        $resultData.Database = $false
        # Linux and Citrix don't go together
        $resultData.Citrix = $false
      }

      Write-Verbose -WA 'continue' -Message "${computer}: Not a Windows server."
      $resultData
      continue
    }

		## Obligatory AV check; for verbose only
		Write-Verbose -Message 'Checking AV'
		if ($resultData.AV -eq $true) {
			Write-Verbose 'The answer is: YES'

		} else {
			Write-Verbose 'The answer is: NO'
      
		} #if-else AV

		## Obligatory DR check; for verbose only
		Write-Verbose -Message 'Checking DR'
		if ($resultData.DR -eq $true) {
			Write-Verbose 'The answer is: YES'

		} else {
			Write-Verbose 'The answer is: NO'

		} #if-else AV

        
#Write-Information -InformationAction 'Continue' -MessageData "Access"

		## Server access check
		if ($null -eq $vmData.PoweredOn -or $vmData.PoweredOn -eq $false) {
			$netTest = Test-NetConnection -ComputerName
			
			if ($netTest.PingSuccess -eq $false) {
				Write-Warning -WA 'Continue' -Message "${computer}: Server is not online. Skipping local data check."
        continue
			}
		} #if !poweredOn

        
#Write-Information -InformationAction 'Continue' -MessageData "Database"

		## Database check
		Write-Verbose -Message 'Checking Database'
		try {
			$dbSQLregistry = [bool](Confirm-SQLRegistry -ComputerName $computer)

			if ($dbSQLregistry) {
				Write-Verbose 'The answer is: YES'
				$resultData.Database = $true

			} else {
				Write-Verbose 'The answer is: NO'
				$resultData.Database = $false

			}
		} catch {
			Write-Warning -WA 'Continue' -Message "${computer}: Unable to determine Database check. Manual check required."
		}
		# TODO

    #Write-Information -InformationAction 'Continue' -MessageData "Citrix\Storage PreReQ"

		## Citrix/Storage Prereq - software installed	
		try {
      $installedSoftware = Get-InstalledSoftware -ComputerName $computer
    } catch {

    }    
        
#Write-Information -InformationAction 'Continue' -MessageData "Citrix"

		## Citrix check
		Write-Verbose -Message 'Checking Citrix'
		$citrSoft = $installedSoftware | Where-Object { $_ -like 'Citrix*' }

		If ($citrSoft -AND $resultData.ServerType -eq 'Citrix') {
			Write-Verbose 'The answer is: YES'
			$resultData.Citrix = $true

		} else {
			Write-Verbose 'The answer is: NO'
			$resultData.Citrix = $false

		} #if-else


		try {
		  ## Storage prereq - IP (from server)
			$localIPs = Get-IPaddresses -ComputerName $computer

      # actual IP override
			$resultData.IP = $localIPs.IPAddress

		} catch {
			if ($null -eq $resultData.IP) {
				Write-Warning -WA 'Continue' -Message "${computer}: Unable to retrieve IPs from the server. Manual Storage check required."

			} else {
				Write-Warning -WA 'Continue' -Message "${computer}: Unable to retrieve IPs from the server."

			}			
		}

#Write-Information -InformationAction 'Continue' -MessageData "Storage"

		## Storage check
		Write-Verbose -Message 'Checking Storage'
		# RegEx incoming, mind your head and ask google if you're at a loss
		If ('SnapDrive' -in $installedSoftware -OR $resultData.IP -match '<regexQuery>') {
			Write-Verbose 'The answer is: YES'
			$resultData.Storage = $true

		} else {
			Write-Verbose 'The answer is: NO'
			$resultData.Storage = $false
      
		} #if-else
        
#Write-Information -InformationAction 'Continue' -MessageData "Print"

    $resultData
  } #foreach computer
	
} #process