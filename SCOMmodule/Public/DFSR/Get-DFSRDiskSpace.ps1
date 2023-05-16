function Get-DFSRDiskSpace{
  param(
    [Parameter(Mandatory, Position='0')]
    [string]
    $ComputerName,
    
    [Parameter(Mandatory, Position='1')]
    [string]
    $StagingGroup,
    
    [Parameter(Mandatory, Position='2')]
    [string]
    $StagingFolderPath,
    
    [Parameter(Position='3')]
    $StagingFolder
    
  ) #param
    
  begin {
    #$domain = ( $ComputerName.split(".") | Select-Object -Last 2 ) -join "."
    $ComputerName = ($ComputerName.split(".") | Select-Object -First 1)		
    
    # Primer: StagingFolder
    if (-not $StagingFolder) {
      $StagingFolder = $StagingFolderPath.Split("\") | Select-Object -First 3 | Select-Object -Last 1
      if (!noConfirm) {
        Read-Host ( "Selected folder: {0} - Correct? (Y/N)" -f $StagingFolder)
      }
    } #if !StagingFolder

    # Primer: InformationAction
    if($PSBoundParameters.keys.Contains("InformationAction")) { 
      $IA = $PSBoundParameters["InformationAction"]
    } else { 
      $IA = "Continue" 
    } #if-else

  } #begin

  process {
    Write-Information -InformationAction $IA -MessageData ("ComputerName: {0}" -f $ComputerName)

    # Disk free space
    Write-Information -InformationAction $IA -MessageData ("Getting disk space.")
    $disk = Get-WmiObject win32_logicalDisk -ComputerName $ComputerName | Where-Object { $_.DriveType -eq 3 -AND $_.DeviceID -eq $StagingFolderPath.Substring(0,2) }
    Write-Information -InformationAction $IA -MessageData ("Free: {0} MB" -f [Math]::Ceiling($disk.FreeSpace/1MB))

    # Folder size
    Write-Information -InformationAction $IA -MessageData ("Getting folder size.")
    $folderSize = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
      $sum = 0
      robocopy $args[0] NULL /e /np /l /r:2 /w:5 /njh /njs /nc /ndl /bytes /njh /njs | ForEach-Object {
        $sum += [double]($_.substring(0,$_.indexof(":")-1)).trim()
      } 
      $sum
      } -ArgumentList $StagingFolderPath
    Write-Information -InformationAction $IA -MessageData ("Size: {0} MB" -f [Math]::Ceiling($folderSize/1MB))

    # DFSR quota
    Write-Information -InformationAction $IA -MessageData ("Getting DFSR quota.")
    $quota = Get-DfsrMembership -GroupName $StagingGroup -ComputerName $ComputerName | Where-Object FolderName -eq $StagingFolder | Select-Object -ExpandProperty StagingPathQuotaInMB
    Write-Information -InformationAction $IA -MessageData ("Quota: {0} MB" -f $quota)

    # actual check
    Write-Information -InformationAction $IA -MessageData ("Crunching numbers.")
    
    if ( $disk.FreeSpace -lt 10GB ) {
      Write-Warning	-Message ( "Remainin space on disk {0} id below 10GB. Note it in the ticket and ask for disk extention." -f $disk.DeviceID )
    }

    $limit = $quota * 1MB - $folderSize

    if ($limit -lt $disk.FreeSpace) {
      Write-Output "Alert can be closed."

    }	else {
      Write-Output ("Ask for disk extension ({0} MB)" -f [Math]::Ceiling(($limit - $disk.FreeSpace)/1MB))

    } #if-else FreeSpace available
  } #process 
} #function Get-DFSRDiskSpace