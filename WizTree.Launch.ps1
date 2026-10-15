# Prepare the installed app and hand the real drive directly to WizTree's GUI.
function Get-WizTreeReadyDrives {
 $targets=@()
 foreach ($drive in [IO.DriveInfo]::GetDrives()) {try {if ($drive.IsReady -and $drive.DriveType -in @('Fixed','Removable')) {$targets+=$drive.Name.TrimEnd('\')}} catch {}}
 return @($targets | Sort-Object -Unique)
}
function Select-WizTreeInitialDrive([string[]]$Drives,[string]$SystemDrive=$env:SystemDrive) {
 $ready=@($Drives | Where-Object {$_ -match '^[A-Za-z]:$'} | ForEach-Object {$_.ToUpperInvariant()} | Sort-Object -Unique)
 if ('C:' -in $ready) {return 'C:'}
 if ($SystemDrive -and $SystemDrive.ToUpperInvariant() -in $ready) {return $SystemDrive.ToUpperInvariant()}
 if ($ready.Count) {return $ready[0]}
 throw 'Không tìm thấy ổ cứng hoặc USB đang sẵn sàng để mở trong WizTree.'
}
function Invoke-WizTreeOpen([bool]$Confirmed) {
 if (-not $Confirmed) {throw 'Chưa chọn Dung lượng ổ đĩa; chưa cài hoặc mở WizTree.'}
 $cancel=Join-Path ([IO.Path]::GetDirectoryName($script:ToolStatusPath)) 'cancel.open'
 if (Test-Path -LiteralPath $cancel) {throw 'Đã hủy trước khi cài hoặc mở WizTree.'}
 Write-ToolJson ([pscustomobject]@{Message='Đang kiểm tra / cài WizTree nếu cần…'}) $script:ToolStatusPath
 $installation=Install-WizTree $true
 if (Test-Path -LiteralPath $cancel) {throw 'Đã hủy mở WizTree sau bước cài đặt.'}
 $drive=if ($script:ToolSimulation) {'C:'} else {Select-WizTreeInitialDrive @(Get-WizTreeReadyDrives)}
 Write-ToolJson ([pscustomobject]@{Message=('Đang mở WizTree để tự quét trực tiếp ổ '+$drive+'…')}) $script:ToolStatusPath
 $launched=Start-WizTreeApplication $installation.Path $drive
 return [pscustomobject]@{Installed=$true;Path=$installation.Path;Version=$installation.Version;Drive=$drive;Launched=[bool]$launched;ScanMode='DirectDrive'}
}
