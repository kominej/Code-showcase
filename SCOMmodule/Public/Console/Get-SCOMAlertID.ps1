function Get-SCOMAlertID{
  <#	
  .SYNOPSIS
    Shows SCOM alerts.
  
  .DESCRIPTION
    ###TODO: fill

  .PARAMETER 
    ###TODO: fill

  .EXAMPLE
    Get-SCOMAlertID
    ###TODO: fill

  .EXAMPLE
    Get-SCOMAlertID
    ###TODO: fill

  .INPUTS
    None.
    
  .OUTPUTS
    [PSCustomObject] list of retrieved alerts 
  #>
  
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, ValueFromPipeLine, ValueFromPipeLineByPropertyName)]
    [string[]]
    $ComputerName,

    [DateTime]
    $OpenedSince,

    [DateTime]
    $ResolvedSince,

    [string]
    $ServiceType

  ) #param

  process{
    Write-Verbose -Message 'Changing up filter'
    $filter = $null
    if ($ResolvedSince) { $filter = "TimeRaised > $OpenedSince AND " }
    if ($OpenedSince) { $filter = "TimeResolved > $ResolvedSince AND " }
    if ($ServiceType) { $filter += "Name = '$ServiceType' AND " }

    Write-Verbose -Message 'Collecting alerts'
    foreach ($computer in $ComputerName) {
      Write-Information -InfA 'Continue' -MessageData ">> $computer"

      $filter += "NetbiosComputerName = '$computer'" 
      $alerts = Get-SCOMAlert -Criteria $filter
      
      $alerts | Group-Object Name | ForEach-Object {
        Write-Information -InfA 'Continue' -MessageData "> $($_.name)"
        if ($_.name -eq 'Service terminated unexpectedly') {
          $_.Group | Format-Table ID, @{n='Service';e={ ([xml]$_.Context).DataItem.Params.Param[0] }}, TimeRaised, TimeResolved, ResolvedState
        } else {
          $_.Group | Format-Table ID, TimeRaised, TimeResolved, ResolvedState
        } #if:else(service alerts)

      } #Foreach-Object
    } #foreach ComputerName
  } #process
} #function(Get-SCOMAlertID)