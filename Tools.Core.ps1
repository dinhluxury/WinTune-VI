# Explicit handlers only. JSON carries data, never commands or script text.
Set-StrictMode -Version Latest
function Initialize-Tools([string]$Root,[bool]$Simulation,[string]$User) {
 $script:ToolRoot=[IO.Path]::GetFullPath($Root);$script:ToolSimulation=$Simulation;$script:ToolUser=$User
 $null=New-Item -ItemType Directory -Path $ToolRoot -Force
 $script:ToolMockPlan='381b4222-f694-41f0-9685-ff5bb260df2e';$script:ToolMockWrites=0
 $script:ToolStatusPath='';$script:ToolMockExit=0;$script:ToolMockFiles=@();$script:ToolMockCimFail=$false
 if ($Simulation) {
  $state=Join-Path $ToolRoot 'simulation-plan.txt';if (Test-Path -LiteralPath $state) {$script:ToolMockPlan=(Get-Content -LiteralPath $state -Raw).Trim()}
  $script:ToolMockFiles=@([pscustomobject]@{Path=(Join-Path (Get-ToolTempRoot) 'WinTune-demo-old.tmp');Bytes=12288L;Modified=[DateTime]::UtcNow.AddDays(-10).ToString('o')})
 }
}
function Get-ToolDefinitions {
 $source='https://learn.microsoft.com/en-us/windows/package-manager/winget/'
 @(
  @('wingetcheck','Kiểm tra WinGet','Phần mềm','Đọc phiên bản WinGet; nếu thiếu, hướng dẫn App Installer từ Microsoft Store. Không tự cài dependency.',$false,$false,'Không cần',$source),
  @('wingetsearch','Tìm phần mềm','Phần mềm','Tìm trong nguồn winget. Không cài. Nguồn có thể yêu cầu đồng ý điều khoản.',$false,$false,'Không cần',$source),
  @('wingetlist','Phần mềm đã cài','Phần mềm','Danh sách WinGet nhận diện được, có thể gồm cài bằng cách khác. Không phải toàn bộ Appx.',$false,$false,'Không cần',$source),
  @('wingetupdates','Kiểm tra cập nhật','Phần mềm','Chỉ liệt kê bản cập nhật, không dùng upgrade --all.',$false,$false,'Không cần',$source),
  @('wingetshow','Thông tin package ID','Phần mềm','Kiểm tra chính xác ID và xem nguồn/phiên bản/điều khoản trước cài.',$false,$false,'Không cần',$source),
  @('wingetinstall','Cài phần mềm đã chọn','Phần mềm','Cài đúng ID qua WinGet. Installer có thể hỏi UAC, đóng app hoặc yêu cầu restart: tự lưu dữ liệu trước. Không hoàn tác dữ liệu/phiên bản.',$false,$true,'Không có; dùng cách gỡ chính thức',$source),
  @('wingetupgrade','Cập nhật phần mềm đã chọn','Phần mềm','Cập nhật đúng ID. Có thể đổi tính tương thích; lưu công việc trước. Không hứa hạ phiên bản hoặc khôi phục dữ liệu.',$false,$true,'Không có',$source),
  @('tempscan','Quét file tạm người dùng','Dọn dẹp','Chỉ quét file TEMP user cũ hơn 7 ngày. Bỏ liên kết/reparse point; không quét file cá nhân, cache game/Adobe hoặc thư mục hệ thống.',$false,$false,'Không cần','https://support.microsoft.com/windows/free-up-drive-space-in-windows-85529ccb-c365-490d-b548-831022bc9b32'),
  @('tempdelete','Xóa file tạm đã chọn','Dọn dẹp','Xóa đúng file đã quét/được chọn, kiểm tra lại đường dẫn/tuổi/kích thước/ngày sửa. Bỏ file đang dùng/thay đổi. Không hoàn tác dữ liệu.',$false,$true,'Không có — xóa vĩnh viễn','https://learn.microsoft.com/en-us/dotnet/api/system.io.file.delete'),
  @('recycle','Dọn Thùng rác','Dọn dẹp','Xóa vĩnh viễn nội dung Thùng rác của tài khoản này trên các ổ. Cần xác nhận riêng; có thể chứa file cá nhân.',$false,$true,'Không có','https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/clear-recyclebin'),
  @('sfc','SFC — kiểm tra và sửa file hệ thống','Sửa lỗi','sfc /scannow. Có thể mất nhiều phút, sửa file hệ thống; đọc kết quả thật, không tự chạy thêm DISM.',$true,$true,'Không hoàn tác tự động','https://support.microsoft.com/en-us/windows/experience/backup-recovery/using-system-file-checker-in-windows'),
  @('dismcheck','Kiểm tra nhanh thành phần Windows','Sửa lỗi','Đọc cờ hỏng đã được Windows ghi nhận; không quét đầy đủ, không sửa.',$true,$false,'Không cần','https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/repair-a-windows-image'),
  @('dismscan','Quét kỹ thành phần Windows','Sửa lỗi','Quét component store; có thể lâu, không tự RestoreHealth.',$true,$false,'Không cần','https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/repair-a-windows-image'),
  @('dismrestore','Khôi phục thành phần Windows (DISM)','Sửa lỗi','Sửa component store, có thể tải từ Windows Update. Không tự restart; không cam kết sửa mọi lỗi.',$true,$true,'Không hoàn tác tự động','https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/repair-a-windows-image'),
  @('diskcheck','Kiểm tra ổ hệ thống — chỉ đọc','Sửa lỗi','chkdsk ổ Windows, không /f /r /x /scan hoặc lên lịch boot. Kiểm tra đọc khi ổ đang dùng có thể có cảnh báo/false positive; không sửa hay kết luận ổ cứng khỏe.',$true,$false,'Không cần','https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/chkdsk'),
  @('powerlist','Đọc các chế độ nguồn điện','Tối ưu','Liệt kê power plan GUID thực có. Không thêm Ultimate Performance hoặc đổi thiết lập từng plan.',$false,$false,'Không cần','https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options'),
  @('powerset','Đổi chế độ nguồn điện','Tối ưu','Chọn một GUID hiện có; lưu plan cũ, kiểm tra sau đổi. Plan hiệu năng có thể tăng điện/nhiệt/quạt, không hứa FPS.',$false,$true,'GUID cũ nếu không xung đột','https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options'),
  @('powerundo','Quay lại chế độ nguồn điện trước','Tối ưu','Trả chế độ nguồn điện về lựa chọn trước khi WinTune đổi. Chỉ thực hiện nếu chưa bị thay đổi bên ngoài. Không phải khôi phục Windows.',$false,$true,'Phục hồi có điều kiện','https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options'),
  @('restorepoint','Tạo điểm khôi phục Windows','Sao lưu','Chỉ tạo khi System Protection/Windows cho phép. Giới hạn tần suất có thể từ chối. Không tự bật Protection/đổi registry; không sao lưu file cá nhân.',$true,$true,'Mở System Restore riêng','https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/checkpoint-computer')
 ) | ForEach-Object {[pscustomobject]@{Id=$_[0];Title=$_[1];Group=$_[2];Description=$_[3];Admin=$_[4];Mutates=$_[5];Undo=$_[6];Source=$_[7];MinBuild=22000;Restart=$false}}
}
function Get-Tool([string]$Id) {$found=@(Get-ToolDefinitions | Where-Object Id -CEQ $Id);if ($found.Count -ne 1) {throw 'Handler không được đăng ký.'};return $found[0]}
function Protect-ToolData($Data,[string]$Path) {
 Add-Type -AssemblyName System.Security
 $bytes=[Text.Encoding]::UTF8.GetBytes(($Data | ConvertTo-Json -Depth 16))
 $sealed=[Security.Cryptography.ProtectedData]::Protect($bytes,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
 Write-ToolJson ([pscustomobject]@{User=$ToolUser;Version=1;Protected=[Convert]::ToBase64String($sealed)}) $Path
}
function Read-ProtectedToolData([string]$Path) {
 Add-Type -AssemblyName System.Security
 $s=Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
 if ($s.Version -ne 1 -or $s.User -ne $ToolUser) {throw 'Dữ liệu khác tài khoản.'}
 $bytes=[Security.Cryptography.ProtectedData]::Unprotect([Convert]::FromBase64String($s.Protected),$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
 return ([Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json)
}
function Write-ToolJson($Data,[string]$Path) {
 $full=[IO.Path]::GetFullPath($Path)
 if (-not $full.StartsWith($ToolRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {throw 'Không ghi ngoài thư mục dữ liệu công cụ.'}
 $tmp=$full+'.tmp';$stream=New-Object IO.StreamWriter($tmp,$false,(New-Object Text.UTF8Encoding($true)))
 try {$stream.Write(($Data | ConvertTo-Json -Depth 18));$stream.Flush();$stream.BaseStream.Flush($true)} finally {$stream.Dispose()}
 if (Test-Path -LiteralPath $full) {$backup=$full+'.bak';[IO.File]::Replace($tmp,$full,$backup);Remove-Item -LiteralPath $backup -ErrorAction Stop} else {[IO.File]::Move($tmp,$full)}
}
function Quote-ToolArgument([string]$Value) {
 # CommandLineToArgvW quoting; never invoke a shell with user input.
 return '"'+([regex]::Replace([regex]::Replace($Value,'(\\*)"','$1$1\"'),'(\\+)$','$1$1'))+'"'
}
function Invoke-ToolNative([string]$Exe,[string[]]$Arguments) {
 if ($ToolSimulation) {throw 'Native process forbidden in simulation.'}
 $info=New-Object Diagnostics.ProcessStartInfo;$info.FileName=$Exe;$info.Arguments=($Arguments | ForEach-Object {Quote-ToolArgument $_}) -join ' '
 $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true;$info.RedirectStandardInput=$true
 if ([IO.Path]::GetFileName($Exe) -eq 'winget.exe') {$info.StandardOutputEncoding=[Text.Encoding]::UTF8;$info.StandardErrorEncoding=[Text.Encoding]::UTF8}
 $p=New-Object Diagnostics.Process;$p.StartInfo=$info
 try {
  $null=$p.Start();$p.StandardInput.Close();$outBuffer=New-Object IO.MemoryStream;$errBuffer=New-Object IO.MemoryStream
  $out=$p.StandardOutput.BaseStream.CopyToAsync($outBuffer);$err=$p.StandardError.BaseStream.CopyToAsync($errBuffer)
  # This wait happens in the isolated worker, never on the WPF dispatcher.
  while (-not $p.WaitForExit(500)) {if ($script:ToolStatusPath) {Write-ToolJson ([pscustomobject]@{Status='Running';Message='Lệnh vẫn đang chạy; chưa có kết quả.';Time=(Get-Date).ToString('o')}) $script:ToolStatusPath}}
  $out.Wait();$err.Wait();$utf8=[IO.Path]::GetFileName($Exe) -eq 'winget.exe'
  return [pscustomobject]@{ExitCode=$p.ExitCode;Output=(Convert-ToolOutput $outBuffer.ToArray() $utf8);Error=(Convert-ToolOutput $errBuffer.ToArray() $utf8);Arguments=$Arguments;Executable=[IO.Path]::GetFileName($Exe)}
 } finally {$p.Dispose()}
}
function Convert-ToolOutput([byte[]]$Bytes,[bool]$PreferUtf8) {
 if (-not $Bytes.Length) {return ''}
 $unicode=$Bytes.Length -ge 2 -and $Bytes[0] -eq 255 -and $Bytes[1] -eq 254
 $zeros=0;$sample=[Math]::Min($Bytes.Length,1024)
 for ($i=1;$i -lt $sample;$i+=2) {if ($Bytes[$i] -eq 0) {$zeros++}}
 if ($unicode -or $zeros -gt $sample/8) {return [Text.Encoding]::Unicode.GetString($Bytes).TrimStart([char]0xFEFF)}
 if ($PreferUtf8 -or ($Bytes.Length -ge 3 -and $Bytes[0] -eq 239 -and $Bytes[1] -eq 187 -and $Bytes[2] -eq 191)) {return [Text.Encoding]::UTF8.GetString($Bytes).TrimStart([char]0xFEFF)}
 return [Text.Encoding]::GetEncoding([Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage).GetString($Bytes)
}
function Get-WinGetPath {
 $cmd=Get-Command winget.exe -CommandType Application -ErrorAction SilentlyContinue
 if ($null -eq $cmd) {throw 'WinGet chưa có. Mở Microsoft Store và cập nhật App Installer; WinTune không tự cài.'}
 return $cmd.Source
}
function New-WinGetArguments([string]$Id,$Parameters) {
 $command=switch ($Id) {'wingetcheck' {'--version'} 'wingetsearch' {'search'} 'wingetlist' {'list'} 'wingetupdates' {'list'} 'wingetshow' {'show'} 'wingetinstall' {'install'} 'wingetupgrade' {'upgrade'} default {throw 'Lệnh WinGet không được hỗ trợ.'}}
 $args=@($command)
 if ($Id -eq 'wingetcheck') {return $args}
 $args+=@('--source','winget','--disable-interactivity')
 if ($Id -eq 'wingetsearch') {if ($Parameters.Query -notmatch '^[\p{L}\p{N} ._+-]{1,100}$') {throw 'Từ tìm kiếm không hợp lệ.'};$args+=@('--query',[string]$Parameters.Query,'--count','50')}
 if ($Id -eq 'wingetupdates') {$args+='--upgrade-available'}
 if ($Id -eq 'wingetlist' -and $Parameters.PackageId) {if ($Parameters.PackageId -notmatch '^[A-Za-z0-9][A-Za-z0-9._+-]{2,127}$') {throw 'Package ID không hợp lệ.'};$args+=@('--id',[string]$Parameters.PackageId,'--exact')}
 if ($Id -in @('wingetshow','wingetinstall','wingetupgrade')) {
  if ($Parameters.PackageId -notmatch '^[A-Za-z0-9][A-Za-z0-9._+-]{2,127}$') {throw 'Package ID không hợp lệ.'}
  $args+=@('--id',[string]$Parameters.PackageId,'--exact')
  # The newest UniKey manifest only offers ARM64. Pin the reviewed official
  # x64 release; versions/architecture are never taken from execution input.
  if ($Parameters.PackageId -ceq 'UniKey.UniKey') {
   $args+=@('--version','4.6.230919','--architecture','x64')
  }
 }
 if ($Parameters.SourceAgreed) {$args+='--accept-source-agreements'}
 if ($Id -in @('wingetinstall','wingetupgrade')) {
  if ($Parameters.PackageAgreed) {$args+='--accept-package-agreements'}
  $args+=if ($Parameters.SilentAgreed) {'--silent'} else {'--interactive'}
  # No --all / --force / --ignore-security-hash / --override / --allow-reboot.
 }
 return $args
}
function Get-ToolTempRoot {
 return [IO.Path]::GetFullPath((Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Temp'))
}
function Test-SafeTempPath([string]$Path,[string]$Root) {
 try {
  $base=[IO.Path]::GetFullPath($Root).TrimEnd('\');$full=[IO.Path]::GetFullPath($Path)
  if (-not $full.StartsWith($base+'\',[StringComparison]::OrdinalIgnoreCase) -or $full.Substring($base.Length).Contains(':')) {return $false}
  $cursor=$full
  while ($cursor.Length -ge $base.Length) {
   if (Test-Path -LiteralPath $cursor) {if (([IO.File]::GetAttributes($cursor) -band [IO.FileAttributes]::ReparsePoint) -ne 0) {return $false}}
   if ($cursor -eq $base) {break};$cursor=[IO.Path]::GetDirectoryName($cursor)
  }
  return $true
 } catch {return $false}
}
function Get-TempCandidates {
 if ($ToolSimulation) {return @($ToolMockFiles)}
 $root=Get-ToolTempRoot
 if (-not (Test-Path -LiteralPath $root)) {return @()}
 if (([IO.File]::GetAttributes($root) -band [IO.FileAttributes]::ReparsePoint) -ne 0) {throw 'TEMP là liên kết; không quét.'}
 $stack=New-Object 'Collections.Generic.Stack[string]';$stack.Push($root);$count=0;$errors=0;$result=@()
 while ($stack.Count) {
  $dir=$stack.Pop()
  try {$entries=@(Get-ChildItem -LiteralPath $dir -Force -ErrorAction Stop)} catch {$errors++;continue}
  foreach ($f in $entries) {
   if (($f.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {continue}
   if ($f.PSIsContainer) {$stack.Push($f.FullName);continue}
   if ($f.LastWriteTimeUtc -ge [DateTime]::UtcNow.AddDays(-7)) {continue}
   $result+=[pscustomobject]@{Path=$f.FullName;Bytes=$f.Length;Modified=$f.LastWriteTimeUtc.ToString('o')};$count++
   if ($count -ge 10000) {return [pscustomobject]@{Files=$result;Errors=$errors;Limited=$true}}
  }
 }
 return [pscustomobject]@{Files=$result;Errors=$errors;Limited=$false}
}
function Remove-SelectedTemp([object[]]$Files) {
 if ($Files.Count -lt 1 -or $Files.Count -gt 10000) {throw 'Chưa chọn file hoặc vượt giới hạn.'}
 $root=Get-ToolTempRoot;$results=@();$removed=0L;$seen=@{}
 foreach ($row in $Files) {
  if (-not (Test-SafeTempPath $row.Path $root) -or $seen.ContainsKey($row.Path)) {throw 'Đường dẫn xóa ngoài TEMP, liên kết hoặc trùng lặp.'};$seen[$row.Path]=$true
 }
 foreach ($row in $Files) {
  try {
   if ($ToolSimulation) {$script:ToolMockWrites++;$removed+=[long]$row.Bytes;$results+=[pscustomobject]@{Path=$row.Path;State='Mô phỏng xóa';Bytes=$row.Bytes};continue}
   if (-not (Test-SafeTempPath $row.Path $root)) {throw 'Đường dẫn đổi thành liên kết.'}
   $file=Get-Item -LiteralPath $row.Path -Force -ErrorAction Stop
   if ($file.PSIsContainer -or $file.Length -ne [long]$row.Bytes -or $file.LastWriteTimeUtc.ToString('o') -ne $row.Modified -or $file.LastWriteTimeUtc -ge [DateTime]::UtcNow.AddDays(-7)) {throw 'File thay đổi hoặc còn mới; bỏ qua.'}
   Remove-TempHandle $file.FullName ([long]$row.Bytes) ([DateTime]::Parse($row.Modified).ToUniversalTime().Ticks) $root
   if (Test-Path -LiteralPath $row.Path) {throw 'File vẫn còn sau yêu cầu xóa.'}
   $removed+=[long]$row.Bytes;$results+=[pscustomobject]@{Path=$row.Path;State='Đã xóa';Bytes=$row.Bytes}
  } catch {$results+=[pscustomobject]@{Path=$row.Path;State='Bỏ qua/lỗi';Bytes=0;Error=$_.Exception.Message}}
 }
 return [pscustomobject]@{RemovedBytes=$removed;Rows=$results;Undo='Không thể hoàn tác dữ liệu đã xóa.'}
}
function Remove-TempHandle([string]$Path,[long]$Bytes,[long]$Ticks,[string]$Root) {
 if ($ToolSimulation) {throw 'Native deletion forbidden in simulation.'}
 if (-not ('WinTuneTempDelete' -as [type])) {Add-Type @'
using System; using System.Text; using System.Runtime.InteropServices; using Microsoft.Win32.SafeHandles;
public static class WinTuneTempDelete {
 [StructLayout(LayoutKind.Sequential)] struct FT { public uint Low,High; }
 [StructLayout(LayoutKind.Sequential)] struct INFO { public uint Attributes;public FT Created,Accessed,Written; public uint Volume,SizeHigh,SizeLow,Links,IndexHigh,IndexLow; }
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern SafeFileHandle CreateFile(string p,uint a,uint s,IntPtr sa,uint d,uint f,IntPtr t);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetFileInformationByHandle(SafeFileHandle h,out INFO i);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern uint GetFinalPathNameByHandle(SafeFileHandle h,StringBuilder p,uint n,uint f);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool SetFileInformationByHandle(SafeFileHandle h,int c,ref byte b,uint n);
 static void Error(){throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());}
 public static void Remove(string path,long bytes,long ticks,string root) {
  using(var h=CreateFile(path,0x80010000,0,IntPtr.Zero,3,0x00200000,IntPtr.Zero)) {
   if(h.IsInvalid)Error(); INFO i;if(!GetFileInformationByHandle(h,out i))Error();
   long size=((long)i.SizeHigh<<32)|i.SizeLow;long written=DateTime.FromFileTimeUtc(((long)i.Written.High<<32)|i.Written.Low).Ticks;
   if((i.Attributes & (0x400|0x10))!=0 || size!=bytes || written!=ticks)throw new InvalidOperationException("File thay đổi/liên kết; bỏ qua.");
   var actual=new StringBuilder(32768);uint length=GetFinalPathNameByHandle(h,actual,32768,0);if(length==0||length>=32768)Error();
   string resolved=actual.ToString();if(resolved.StartsWith(@"\\?\"))resolved=resolved.Substring(4);
   string full=System.IO.Path.GetFullPath(path),basePath=System.IO.Path.GetFullPath(root).TrimEnd('\\')+"\\";
   if(!resolved.Equals(full,StringComparison.OrdinalIgnoreCase)||!resolved.StartsWith(basePath,StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("File chuyển ngoài TEMP; bỏ qua.");
   byte delete=1;if(!SetFileInformationByHandle(h,4,ref delete,1))Error();
  }
 }
}
'@}
 [WinTuneTempDelete]::Remove($Path,$Bytes,$Ticks,$Root)
}
function Get-PowerState {
 if ($ToolSimulation) {return $ToolMockPlan}
 $r=Invoke-ToolNative (Join-Path $env:WINDIR 'System32/powercfg.exe') @('/getactivescheme')
 if ($r.ExitCode -ne 0 -or $r.Output -notmatch '[a-fA-F0-9]{8}(-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}') {throw 'Không đọc được power plan hiện tại.'}
 return $Matches[0].ToLowerInvariant()
}
function Get-PowerList {
 if ($ToolSimulation) {return [pscustomobject]@{Plans=@([pscustomobject]@{Guid='381b4222-f694-41f0-9685-ff5bb260df2e';Title='Balanced — mô phỏng'},[pscustomobject]@{Guid='8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c';Title='High performance — mô phỏng'});Active=$ToolMockPlan}}
 $r=Invoke-ToolNative (Join-Path $env:WINDIR 'System32/powercfg.exe') @('/list');if ($r.ExitCode -ne 0) {throw $r.Error}
 $plans=@();foreach ($line in ($r.Output -split "`r?`n")) {if ($line -match '([a-fA-F0-9]{8}(?:-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12})\s+\((.+)\)') {$plans+=[pscustomobject]@{Guid=$Matches[1].ToLowerInvariant();Title=$Matches[2]}}}
 return [pscustomobject]@{Plans=$plans;Active=(Get-PowerState)}
}
function Set-PowerState([string]$Guid) {
 if ($ToolSimulation) {$script:ToolMockPlan=$Guid;$script:ToolMockWrites++;$Guid | Set-Content -LiteralPath (Join-Path $ToolRoot 'simulation-plan.txt') -Encoding UTF8;return}
 $r=Invoke-ToolNative (Join-Path $env:WINDIR 'System32/powercfg.exe') @('/setactive',$Guid);if ($r.ExitCode -ne 0) {throw ($r.Output+$r.Error)}
}
function Invoke-PowerChange($P,[bool]$Undo) {
 $history=@(Get-ChildItem -LiteralPath $ToolRoot -Filter 'power-*.dat' | ForEach-Object {Read-ProtectedToolData $_.FullName} | Where-Object {$_.Mode -eq $(if ($ToolSimulation) {'Simulation'} else {'Native'})} | Sort-Object Created -Descending)
 $last=@($history | Where-Object Status -ne 'Undone' | Select-Object -First 1)
 $now=Get-PowerState;$available=Get-PowerList
 if ($Undo) {
  if (-not $last.Count) {throw 'Không có power plan cần hoàn tác.'}
  $j=$last[0];if ($now -ne $j.After -and $now -ne $j.Before) {throw 'Power plan đã thay đổi bên ngoài; không ghi đè.'};$target=$j.Before;$path=Join-Path $ToolRoot ('power-'+$j.Id+'.dat')
 } else {
  if ($last.Count) {throw 'Hoàn tác đợt nguồn điện trước trước khi đổi tiếp.'}
  $target=[string]$P.Guid
  if ($P.Before -ne $now) {throw 'Power plan đổi sau xem trước; đọc lại.'}
  if ($target -eq $now) {return [pscustomobject]@{Status='NoOp';Message='Đã dùng plan này, không tạo đợt.'}}
  $j=[pscustomobject]@{Id=[guid]::NewGuid().ToString('N');Created=(Get-Date).ToString('o');User=$ToolUser;Scope='Machine';Mode=$(if ($ToolSimulation) {'Simulation'} else {'Native'});Before=$now;After=$target;Status='Pending'};$path=Join-Path $ToolRoot ('power-'+$j.Id+'.dat')
 }
 if ($target -notin $available.Plans.Guid) {throw 'Power plan cần dùng/khôi phục không còn tồn tại.'}
 Protect-ToolData $j $path
 try {if ((Get-PowerState) -ne $now) {throw 'Plan thay đổi ngay trước ghi.'};if ($now -ne $target) {Set-PowerState $target};if ((Get-PowerState) -ne $target) {throw 'Không xác minh được power plan.'};$j.Status=if ($Undo) {'Undone'} else {'Applied'};Protect-ToolData $j $path;return $j} catch {throw ('Có thể đã đổi plan. Giữ lịch sử và dùng Hoàn tác: '+$_.Exception.Message)}
}
function Read-ToolCim([string]$Class) {Get-CimInstance -ClassName $Class -OperationTimeoutSec 10 -ErrorAction Stop}
function Get-SystemOverview([switch]$DiagnosticsOnly) {
 if ($ToolSimulation) {if ($ToolMockCimFail) {throw 'Mô phỏng CIM không khả dụng.'};return [pscustomobject]@{Mode='MÔ PHỎNG';Message='Dữ liệu thử, không phải phần cứng thật.'}}
 $data=[ordered]@{Time=(Get-Date).ToString('o');Mode='Windows thật — chỉ đọc'}
 if (-not $DiagnosticsOnly) {foreach ($entry in @(@('CPU','Win32_Processor',@('Name','NumberOfCores','NumberOfLogicalProcessors')),@('GPU','Win32_VideoController',@('Name','DriverVersion')),@('RAM','Win32_ComputerSystem',@('TotalPhysicalMemory')),@('Bo mạch','Win32_BaseBoard',@('Manufacturer','Product')),@('Windows','Win32_OperatingSystem',@('Caption','Version','BuildNumber','TotalVisibleMemorySize','FreePhysicalMemory')),@('Ổ đĩa','Win32_LogicalDisk',@('DeviceID','DriveType','Size','FreeSpace','FileSystem')))) {
  try {$data[$entry[0]]=@(Read-ToolCim $entry[1] | Select-Object -Property $entry[2])} catch {$data[$entry[0]]='Không đọc được: '+$_.Exception.Message}
 }}
 try {$data['Lỗi thiết bị']=@(Read-ToolCim Win32_PnPEntity | Where-Object {$_.ConfigManagerErrorCode -ne 0} | Select-Object Name,ConfigManagerErrorCode)} catch {$data['Lỗi thiết bị']='Không đọc được: '+$_.Exception.Message}
 if (-not $DiagnosticsOnly) {try {$data['Ổ vật lý']=@(Get-PhysicalDisk -ErrorAction Stop | Select-Object FriendlyName,MediaType,Size,HealthStatus,OperationalStatus)} catch {$data['Ổ vật lý']='Không có dữ liệu: '+$_.Exception.Message}}
 try {$data['TPM']=Get-Tpm -ErrorAction Stop | Select-Object TpmPresent,TpmReady,TpmEnabled} catch {$data['TPM']='Không đọc được/quyền bị chặn: '+$_.Exception.Message}
 try {$data['Secure Boot']=Confirm-SecureBootUEFI -ErrorAction Stop} catch {$data['Secure Boot']='Không hỗ trợ/không đủ quyền: '+$_.Exception.Message}
 try {$data['Defender']=Get-MpComputerStatus -ErrorAction Stop | Select-Object AntivirusEnabled,RealTimeProtectionEnabled,AMServiceEnabled} catch {$data['Defender']='Không đọc được; không suy ra đã tắt: '+$_.Exception.Message}
 try {$data['Firewall']=@(Get-NetFirewallProfile -ErrorAction Stop | Select-Object Name,Enabled)} catch {$data['Firewall']='Không đọc được; không suy ra đã tắt: '+$_.Exception.Message}
 if (-not $DiagnosticsOnly) {$data['Giới hạn']='HealthStatus do Windows cung cấp, không phải chẩn đoán chuyên sâu; không tạo điểm sức khỏe.'}
 return [pscustomobject]$data
}
function Invoke-ToolHandler([string]$Id,$Parameters,[bool]$Confirmed) {
 $definition=Get-Tool $Id
 if (($definition.Mutates -or $definition.Admin) -and -not $Confirmed) {throw 'Chưa có xác nhận cụ thể; không thực hiện.'}
 if ($Id -like 'winget*') {
  $args=New-WinGetArguments $Id $Parameters
  if ($ToolSimulation) {return [pscustomobject]@{Mode='MÔ PHỎNG';Arguments=$args;ExitCode=$ToolMockExit;Output='Kết quả giả, không cài/cập nhật hoặc truy cập nguồn thật.'}}
  return (Invoke-ToolNative (Get-WinGetPath) $args)
 }
 switch ($Id) {
  'tempscan' {if ($ToolSimulation) {return [pscustomobject]@{Files=@($ToolMockFiles);Errors=0;Limited=$false}};return (Get-TempCandidates)}
  'tempdelete' {return (Remove-SelectedTemp @($Parameters.Files))}
  'recycle' {
   if ($ToolSimulation) {$script:ToolMockWrites++;return [pscustomobject]@{Mode='MÔ PHỎNG';Message='Không xóa Thùng rác thật.'}}
   $before=Get-RecycleBytes;Clear-RecycleBin -Force -ErrorAction Stop;$after=Get-RecycleBytes
   return [pscustomobject]@{BeforeBytes=$before;AfterBytes=$after;RemovedBytes=[Math]::Max(0,$before-$after);Undo='Không hoàn tác dữ liệu.'}
  }
  'powerlist' {return (Get-PowerList)}
  'powerset' {return (Invoke-PowerChange $Parameters $false)}
  'powerundo' {return (Invoke-PowerChange $Parameters $true)}
  'restorepoint' {
   if ($ToolSimulation) {$script:ToolMockWrites++;return [pscustomobject]@{Mode='MÔ PHỎNG';Message='Không tạo Restore Point thật.'}}
   $before=@(Get-ComputerRestorePoint -ErrorAction Stop | ForEach-Object SequenceNumber)
   $label='WinTune VI '+(Get-Date -Format 'yyyy-MM-dd HH:mm:ss');Checkpoint-Computer -Description $label -RestorePointType MODIFY_SETTINGS -ErrorAction Stop -WarningAction Stop
   $after=@(Get-ComputerRestorePoint -ErrorAction Stop | Where-Object {$_.SequenceNumber -notin $before -and $_.Description -eq $label})
   if (-not $after.Count) {throw 'Không tìm thấy điểm mới; không báo tạo thành công.'};return ($after | Select-Object SequenceNumber,Description,CreationTime)
  }
  default {
   $exe='dism.exe';$args=@('/Online','/Cleanup-Image','/NoRestart');switch ($Id) {'sfc' {$exe='sfc.exe';$args=@('/scannow')} 'dismcheck' {$args+='/CheckHealth'} 'dismscan' {$args+='/ScanHealth'} 'dismrestore' {$args+='/RestoreHealth'} 'diskcheck' {$exe='chkdsk.exe';$args=@([IO.Path]::GetPathRoot($env:WINDIR).TrimEnd('\'))} default {throw 'Handler chưa triển khai.'}}
   if ($ToolSimulation) {return [pscustomobject]@{Mode='MÔ PHỎNG';Executable=$exe;Arguments=$args;ExitCode=$ToolMockExit;Output='Không chạy lệnh sửa chữa thật.'}}
   return (Invoke-ToolNative (Join-Path $env:WINDIR ('System32/'+$exe)) $args)
  }
 }
}
function Get-RecycleBytes {
 if ($ToolSimulation) {return 0L}
 if (-not ('WinTuneRecycleInfo' -as [type])) {Add-Type @'
using System; using System.Runtime.InteropServices;
public static class WinTuneRecycleInfo {
 [StructLayout(LayoutKind.Sequential,Pack=1)] public struct INFO {public uint Size;public long Bytes;public long Items;}
 [DllImport("shell32.dll",CharSet=CharSet.Unicode)] static extern int SHQueryRecycleBin(string path, ref INFO info);
 public static long Bytes(){var info=new INFO();info.Size=(uint)Marshal.SizeOf(typeof(INFO));int code=SHQueryRecycleBin(null,ref info);if(code!=0)Marshal.ThrowExceptionForHR(code);return info.Bytes;}
}
'@}
 return [WinTuneRecycleInfo]::Bytes()
}
