function Get-SCOMAlerts{
  <#	
  .SYNOPSIS
    Gather SCOM alerts.
  
  .DESCRIPTION
    !! Note that there is a 'Get-SCOMAlert' command within the OperationsManager module. This function is pretty much just a wrapper for my own laziness and documentation purposes. !!

    Gathers all SCOM alerts relevant to provided filter. By default this command will require manually provided filter. Predefined filters are listed in examples. 
    To search for other results, use filter accordingly. Link to the syntax logic can be found under http://msdn.microsoft.com/en-us/library/bb437603.aspx

    List of notable filters is as follows, !! all are CASE sensitive !!
      TYPE        NAME                NOTE
      ----        --------            ----
      [guid]      Id                  # SCOM ID of alert; this variable can be searched for using "Id IN ('id1', 'id2')"
      [string]    Name                # full name of the alert type
      [int32]     ResolutionState     # see list below
      [string]    PrincipalName       # Computer hostname with domain name; in case of DMZ this will show either hostname.grouphc.net or just hostname
      [string]    NetbiosComputerName # Computer hostname without domain name
      [string]    NetbiosDomainName   # Computer domain; in case of DMZ this will likely show WORKGROUP or whatever other domain the server may locally have
      [string]    CustomField7        # list of assigned groups, in '<group1;group2;group3>' format
      [datetime]  TimeRaised          # logged when server raises the alert to SCOM service
      [datetime]  TimeAdded           # logged when the SCOM service took notice of the alert

    Note that actual value of ID is nested in $_.ID.GUID rather than the ID itself, but can still be searched for by simple 'Id = <guid>'.

    Alert states:
      ID Name
      -- ----
        0 New
        1 In progress <team>
        2 In progress <team>
        3 SDE Ticket
        4 Cherwell Ticket
        6 Escalated to <team>
       11 Generic
      247 Awaiting Evidence
      248 Assigned to Engineering
      249 Acknowledged
      250 Scheduled
      254 Resolved
      255 Closed

  .PARAMETER Filter
    Optional; [string] Filtering query. For further info read Description.
  
  .PARAMETER basic
    Optional; [switch] Search will use predefined <team> scope related filter instead.
  
  .PARAMETER Heartbeat
    Optional; [switch] Search will use predefined Heartbeat related filter instead.
  
  .EXAMPLE
    Get-SCOMAlerts -Filter "ResolutionState = 0 AND PrincipalName -like 'ComputerName'"
    Retrieves all new alerts for hostname ComputerName.
    Note1: PrincipalName is in FQDN format
    Note2: Not all alert types have to have the PrincipalName assigned, you may need to use other alert variables instead

  .EXAMPLE
    Get-SCOMAlerts -basic
    Retrieves all new <team> alerts

  .EXAMPLE
    Get-SCOMAlerts -Heartbeat
    Retrieves all open Heartbeat alerts

  .INPUTS
    None.
    
  .OUTPUTS
    [MonitoringAlert] list of retrieved alerts 
  #>

  [CmdletBinding(DefaultParameterSetName='Filter')]
  param(
    [Parameter(ParameterSetName='Filter', ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Filter,

    [Parameter(Mandatory, ParameterSetName='basic')]
    [switch]
    $basic,

    [Parameter(Mandatory, ParameterSetName='Heartbeat')]
    [switch]
    $Heartbeat

  ) #param

  process{
    switch($PSCmdlet.ParameterSetName){
      'basic'{
        Write-Verbose -Message 'Getting new SCOM alerts for <team>'
        $Filter = "ResolutionState = 0 AND CustomField7 LIKE '%<teamTag>%'"
      }

      'HeartBeat'{
        Write-Verbose -Message 'Getting open Heartbeat SCOM alerts'
        $Filter = "Name = 'Health Service Heartbeat Failure' AND ResolutionState <> 255"
      }
      
      default{ Write-Verbose -Message 'Getting new SCOM alerts for provided filter' }
    } #switch(ParameterSetName)
    
    Get-SCOMAlert -Criteria $Filter
  }  #process
} #function(Get-SCOMAlerts)