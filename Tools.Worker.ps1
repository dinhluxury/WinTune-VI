#Requires -Version 5.1
#Requires -PSEdition Desktop
param([Parameter(Mandatory=$true)][string]$RequestPath)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Tools.Core.ps1"
$parent=[IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($RequestPath))
$user=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
Initialize-Tools ([IO.Directory]::GetParent($parent).FullName) $false $user
$script:ToolStatusPath=Join-Path $parent 'status.json'
try {
 $r=Read-ProtectedToolData $RequestPath
 if ($r.User -ne $user -or $r.Version -ne 1 -or $r.Mode -notin @('Native','Simulation')) {throw 'Yêu cầu khác tài khoản hoặc không hợp lệ.'}
 Initialize-Tools $ToolRoot ($r.Mode -eq 'Simulation') $user
 $script:ToolStatusPath=Join-Path $parent 'status.json'
 Write-ToolJson ([pscustomobject]@{Status='Running';Message='Đang thực hiện đúng thao tác đã chọn.'}) $ToolStatusPath
 if ($ToolSimulation -and $r.Parameters.PSObject.Properties['MockDelayMs']) {
  $delay=[int]$r.Parameters.MockDelayMs;if ($delay -lt 0 -or $delay -gt 15000) {throw 'Thời gian mô phỏng không hợp lệ.'};Start-Sleep -Milliseconds $delay
 }
 if ($r.Id -in @('wiztreecheck','wiztreeinstall','wiztreeopen')) {
  . "$PSScriptRoot/WizTree.Core.ps1";. "$PSScriptRoot/WizTree.Launch.ps1"
  if ($r.Id -eq 'wiztreeopen') {$result=Invoke-WizTreeOpen ([bool]$r.Confirmed)} elseif ($r.Id -eq 'wiztreeinstall') {$result=Install-WizTree ([bool]$r.Confirmed)} else {$result=Get-WizTreeInstallation}
 } elseif ($r.Id -eq 'copilotpreview') {
  . "$PSScriptRoot/Actions.Core.ps1"; . "$PSScriptRoot/Copilot.Core.ps1"
  Initialize-Actions $r.Parameters.ActionRoot $ToolSimulation $user
  $result=New-CopilotRemovalPreview
 } elseif ($r.Id -in @('actionsread','actionsplan')) {
  if ($r.Parameters.Kind -notin @('Appx','Startup')) {throw 'Loại danh sách không được hỗ trợ.'}
  . "$PSScriptRoot/Actions.Core.ps1";Initialize-Actions $r.Parameters.ActionRoot $ToolSimulation $user
  $null=@(Get-ActionJournals)
  if ($r.Id -eq 'actionsread') {$result=[pscustomobject]@{Inventory=@(if ($r.Parameters.Kind -eq 'Appx') {Get-AllAppInventory} else {Get-ActionInventory $r.Parameters.Kind})}}
  else {$result=[pscustomobject]@{Rows=@(New-ActionPlan $r.Parameters.Kind @($r.Parameters.Ids))}}
 } elseif ($r.Id -in @('actionsapply','startupundo')) {
  if (-not $r.Confirmed) {throw 'Chưa xác nhận thao tác app/khởi động.'}
  . "$PSScriptRoot/Actions.Core.ps1";Initialize-Actions $r.Parameters.ActionRoot $ToolSimulation $user
  if ($r.Id -eq 'actionsapply') {$result=Invoke-ActionPlan @($r.Parameters.Rows)} else {$result=Undo-StartupAction}
 } else {
  $definition=Get-Tool $r.Id
  $build=[int](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuild
  if ($build -lt $definition.MinBuild) {throw 'Công cụ này dành cho Windows 11.'}
  if ($definition.Admin -and -not $ToolSimulation -and -not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {throw 'Công cụ cần quyền quản trị; chưa chạy lệnh.'}
  if ($r.Id -in @('wingetinstall','wingetupgrade','wingetshow')) {
   if ($r.Id -ne 'wingetshow' -and -not $r.Confirmed) {throw 'Chưa xác nhận cài/cập nhật.'}
   $ids=@($r.Parameters.PackageIds | Select-Object -Unique)
   if (-not $ids.Count -or $ids.Count -gt 20) {throw 'Số package không hợp lệ.'}
   $rows=@();$failed=$false
   foreach ($id in $ids) {
    $p=$r.Parameters.PSObject.Copy();$p.PackageId=$id
    if ($failed) {$rows+=[pscustomobject]@{Id=$id;State='Skipped';Message='Chưa làm vì mục trước lỗi.'};continue}
    $check=Invoke-ToolHandler wingetshow $p $false
    if ($r.Id -eq 'wingetshow') {$rows+=[pscustomobject]@{Id=$id;State=$(if ($check.ExitCode -eq 0) {'Completed'} else {'Failed'});Result=$check};if ($check.ExitCode -ne 0) {$failed=$true};continue}
    if ($check.ExitCode -ne 0) {$rows+=[pscustomobject]@{Id=$id;State='Failed';Result=$check};$failed=$true;continue}
    $step=Invoke-ToolHandler $r.Id $p $true
    $verify=$null
    if ($step.ExitCode -in @(0,3010)) {$verify=Invoke-ToolHandler wingetlist $p $false}
    $ok=$step.ExitCode -in @(0,3010) -and $null -ne $verify -and $verify.ExitCode -eq 0
    $rows+=[pscustomobject]@{Id=$id;State=$(if ($ok) {'Completed'} else {'Failed'});Result=$step;Verification=$verify}
    if (-not $ok) {$failed=$true}
    if ($step.ExitCode -notin @(0,3010)) {$failed=$true}
   }
   $result=[pscustomobject]@{Rows=$rows;ExitCode=$(if ($failed) {1} else {0});Output=($rows | ConvertTo-Json -Depth 10);RestartRequested=@($rows | Where-Object {$_.PSObject.Properties['Result'] -and $_.Result.ExitCode -eq 3010}).Count -gt 0}
  } else {$result=Invoke-ToolHandler $r.Id $r.Parameters ([bool]$r.Confirmed)}
 }
 $summary='Đã kết thúc thao tác; xem kết quả/giới hạn.'
 if ($null -ne $result -and $result.PSObject.Properties['ExitCode']) {$summary='Lệnh đã thoát với mã '+$result.ExitCode+'. Đọc output để xác định có lỗi/có sửa hay không. Không kết luận Windows đã hết lỗi.'}
 $state=if ($null -ne $result -and $result.PSObject.Properties['ExitCode'] -and $result.ExitCode -notin @(0,3010)) {'Failed'} else {'Completed'}
 if ($r.Id -eq 'tempdelete' -and @($result.Rows | Where-Object State -EQ 'Bỏ qua/lỗi').Count) {$state='Partial';$summary='Chỉ xóa được một phần; xem file đã xóa và file bỏ qua/lỗi. Không hứa phục hồi dữ liệu.'}
 Write-ToolJson ([pscustomobject]@{Status=$state;Id=$r.Id;Mode=$r.Mode;Time=(Get-Date).ToString('o');Message=$summary;Result=$result;RestartRequired=(Test-ToolRestartRequired $result)}) (Join-Path $parent 'result.json')
} catch {Write-ToolJson ([pscustomobject]@{Status='Failed';Message=$_.Exception.Message;Time=(Get-Date).ToString('o')}) (Join-Path $parent 'result.json');exit 1}
