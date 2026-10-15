# WizTree is installed separately from the Microsoft community repository.
# This package does not contain or redistribute WizTree binaries.
function Get-WizTreeCandidatePaths {
 $folders=New-Object 'Collections.Generic.List[string]'
 foreach ($name in @('ProgramFiles','ProgramFilesX86')) {$root=[Environment]::GetFolderPath($name);if ($root) {$folders.Add((Join-Path $root 'WizTree'))}}
 foreach ($hive in @([Microsoft.Win32.RegistryHive]::CurrentUser,[Microsoft.Win32.RegistryHive]::LocalMachine)) {
  foreach ($view in @([Microsoft.Win32.RegistryView]::Registry64,[Microsoft.Win32.RegistryView]::Registry32)) {
   $base=$null;$key=$null
   try {$base=[Microsoft.Win32.RegistryKey]::OpenBaseKey($hive,$view);$key=$base.OpenSubKey('Software\Microsoft\Windows\CurrentVersion\Uninstall\WizTree_is1');if ($key) {$folder=[string]$key.GetValue('InstallLocation','');if ($folder) {$folders.Add($folder)}}} catch {} finally {if ($key) {$key.Dispose()};if ($base) {$base.Dispose()}}
  }
 }
 foreach ($folder in @($folders | Select-Object -Unique)) {foreach ($file in @('WizTree64.exe','WizTree.exe')) {Join-Path $folder $file}}
}
function Read-WizTreeExecutableMetadata([string]$Path) {
 $item=Get-Item -LiteralPath $Path -ErrorAction Stop
 return [pscustomobject]@{Signature=(Get-AuthenticodeSignature -LiteralPath $Path);Product=$item.VersionInfo.ProductName;Version=$item.VersionInfo.FileVersion}
}
function Assert-WizTreeExecutable([string]$Path) {
 $full=[IO.Path]::GetFullPath($Path)
 if ($full -notmatch '^[A-Za-z]:\\' -or [IO.Path]::GetFileName($full) -cnotin @('WizTree64.exe','WizTree.exe') -or -not [IO.File]::Exists($full)) {throw 'Không tìm thấy tệp WizTree đã cài hợp lệ.'}
 $cursor=$full
 while ($cursor) {if (([IO.File]::GetAttributes($cursor) -band [IO.FileAttributes]::ReparsePoint) -ne 0) {throw 'Đường dẫn WizTree là liên kết; chưa chạy.'};$next=[IO.Path]::GetDirectoryName($cursor);if ($next -eq $cursor) {break};$cursor=$next}
 $meta=Read-WizTreeExecutableMetadata $full;$sig=$meta.Signature
 if ([string]$sig.Status -ne 'Valid' -or $null -eq $sig.SignerCertificate -or $sig.SignerCertificate.Subject -notmatch '(?:^|,\s*)(?:O|CN)=Antibody Software(?: Limited| Ltd\.?)?(?:,|$)' -or $meta.Product -notmatch '^WizTree(?:\s|$)') {throw 'Không xác minh được chữ ký Antibody Software của WizTree; chưa mở tệp này.'}
 return [pscustomobject]@{Path=$full;Version=[string]$meta.Version}
}
function Get-WizTreeInstallation {
 if ($script:ToolSimulation) {
  $installed=Test-Path -LiteralPath (Join-Path $ToolRoot 'simulation-wiztree.json')
  return [pscustomobject]@{Installed=$installed;Path=$(if ($installed) {'C:\Simulation\WizTree64.exe'} else {''});Version=$(if ($installed) {'MÔ PHỎNG'} else {''})}
 }
 $errors=@()
 foreach ($path in @(Get-WizTreeCandidatePaths | Select-Object -Unique)) {
  if (-not [IO.File]::Exists($path)) {continue}
  try {$verified=Assert-WizTreeExecutable $path;return [pscustomobject]@{Installed=$true;Path=$verified.Path;Version=$verified.Version}} catch {$errors+=$_.Exception.Message}
 }
 if ($errors.Count) {throw ($errors | Select-Object -First 1)}
 return [pscustomobject]@{Installed=$false;Path='';Version=''}
}
function Get-WizTreeInstallArguments {
 return @('install','--id','AntibodySoftware.WizTree','--exact','--source','winget','--silent','--accept-source-agreements','--accept-package-agreements','--disable-interactivity','--no-upgrade')
}
function Get-WizTreeWinGet {
 $paths=@()
 try {foreach ($app in @(Get-AppxPackage -Name Microsoft.DesktopAppInstaller -ErrorAction Stop)) {if ($app.InstallLocation) {$paths+=Join-Path $app.InstallLocation 'winget.exe'}}} catch {}
 try {$paths+=Get-WinGetPath} catch {}
 foreach ($path in @($paths | Select-Object -Unique)) {
  if (-not [IO.File]::Exists($path)) {continue}
  $sig=Get-AuthenticodeSignature -LiteralPath $path
  if ([string]$sig.Status -eq 'Valid' -and $sig.SignerCertificate -and $sig.SignerCertificate.Subject -match '(?:^|,\s*)O=Microsoft Corporation(?:,|$)') {return $path}
 }
 throw 'WinGet chưa sẵn sàng hoặc chưa xác minh được chữ ký Microsoft. Dùng Trang tải chính thức để cài WizTree, rồi bấm Dung lượng ổ đĩa lần nữa.'
}
function Install-WizTree([bool]$Confirmed) {
 if (-not $Confirmed) {throw 'Chưa chọn Dung lượng ổ đĩa; chưa cài gì.'}
 $existing=Get-WizTreeInstallation;if ($existing.Installed) {return $existing}
 if ($script:ToolSimulation) {
  Write-ToolJson ([pscustomobject]@{Installed=$true;Mode='Simulation'}) (Join-Path $ToolRoot 'simulation-wiztree.json')
  return (Get-WizTreeInstallation)
 }
 $exe=Get-WizTreeWinGet
 $r=Invoke-ToolNative $exe @(Get-WizTreeInstallArguments)
 if ($r.ExitCode -notin @(0,3010)) {throw ('Chưa cài được WizTree. Mã WinGet: '+$r.ExitCode+"`n"+$r.Output+"`n"+$r.Error)}
 $verified=Get-WizTreeInstallation
 if (-not $verified.Installed) {throw 'Trình cài đã kết thúc nhưng chưa tìm thấy WizTree có chữ ký hợp lệ. Chưa báo cài thành công hoặc tự mở tệp khác.'}
 return $verified
}
function Get-WizTreeLaunchArguments([string]$Drive) {
 if ($Drive -notmatch '^[A-Za-z]:$') {throw 'Chỉ mở ổ đĩa thật bằng ký tự ổ, ví dụ C:. Không mở CSV hoặc đường dẫn tệp.'}
 return @($Drive.ToUpperInvariant(),'/admin=1')
}
function Assert-WizTreeDrive([string]$Drive) {
 $null=Get-WizTreeLaunchArguments $Drive
 $info=New-Object IO.DriveInfo ($Drive+'\')
 if (-not $info.IsReady -or $info.DriveType -notin @('Fixed','Removable')) {throw ('Ổ '+$Drive+' chưa sẵn sàng hoặc không phải ổ cứng/USB. Chưa mở WizTree.')}
}
function Start-WizTreeApplication([string]$Path,[string]$Drive='C:') {
 $arguments=@(Get-WizTreeLaunchArguments $Drive)
 if ($script:ToolSimulation -or [bool](Get-Variable IsSimulation -Scope Script -ValueOnly -ErrorAction SilentlyContinue) -or [bool](Get-Variable WriteBlocked -Scope Script -ValueOnly -ErrorAction SilentlyContinue)) {return $false}
 Assert-WizTreeDrive $Drive
 $verified=Assert-WizTreeExecutable $Path
 $start=New-Object Diagnostics.ProcessStartInfo;$start.FileName=$verified.Path;$start.WorkingDirectory=[IO.Path]::GetDirectoryName($verified.Path);$start.UseShellExecute=$true
 $start.Arguments=($arguments | ForEach-Object {Quote-ToolArgument $_}) -join ' '
 $process=[Diagnostics.Process]::Start($start);if ($null -eq $process) {throw 'Chưa khởi động được WizTree.'};$process.Dispose()
 return $true
}
