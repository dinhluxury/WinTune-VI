function Start-ToolJob([string]$Id,$Parameters,[bool]$Confirmed,[bool]$Admin=$false) {
 if ($null -ne $script:ToolJob -and -not $script:ToolJob.Handled) {throw 'Một công cụ đang chạy; đợi kết quả trước khi thực hiện tiếp.'}
 $path=Join-Path $script:ToolRoot ('job-'+[guid]::NewGuid().ToString('N'))
 $null=New-Item -ItemType Directory -Path $path
 $request=[pscustomobject]@{Version=1;Id=$Id;User=$script:ToolUser;Mode=$(if ($script:ToolSimulation) {'Simulation'} else {'Native'});Confirmed=$Confirmed;Parameters=$Parameters;Created=(Get-Date).ToString('o')}
 $requestPath=Join-Path $path 'request.dat';Protect-ToolData $request $requestPath
 $hostExe=Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe'
 $arguments=(@('-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',"$PSScriptRoot/Tools.Worker.ps1",'-RequestPath',$requestPath) | ForEach-Object {Quote-ToolArgument $_}) -join ' '
 $start=@{FilePath=$hostExe;ArgumentList=$arguments;PassThru=$true;WindowStyle='Hidden'}
 if ($Admin -and -not $script:ToolSimulation -and -not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {$start.Verb='RunAs'}
 try {$process=Start-Process @start} catch {Write-ToolJson ([pscustomobject]@{Status='Cancelled';Message='Không chạy: UAC bị hủy hoặc không khởi động được. '+$_.Exception.Message}) (Join-Path $path 'result.json');throw 'Không bắt đầu công cụ; chưa thực hiện thao tác. Nếu UAC bị hủy, app vẫn chạy quyền thường.'}
 $script:ToolJob=[pscustomobject]@{Id=$Id;Path=$path;Process=$process;Started=Get-Date;Handled=$false}
 return $script:ToolJob
}
. (Join-Path $PSScriptRoot 'RepairSummary.Core.ps1')
. (Join-Path $PSScriptRoot 'Power.Explanations.ps1')
function Complete-ToolJob($Job) {
 if ($null -ne $Job -and -not $Job.Handled) {$Job.Handled=$true;$Job.Process.Dispose()}
}
function Get-ToolJobResult($Job) {
 if (-not $Job.Handled -and -not $Job.Process.HasExited) {return $null}
 $path=Join-Path $Job.Path 'result.json'
 if (-not (Test-Path -LiteralPath $path)) {return [pscustomobject]@{Status='Failed';Message='Worker đã dừng nhưng chưa lưu kết quả; không coi là thành công. Giữ thư mục nhật ký.'}}
 try {
  $result=Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($null -eq $result -or -not $result.PSObject.Properties['Status'] -or $result.Status -notin @('Completed','Failed','Partial','Cancelled') -or -not $result.PSObject.Properties['Message'] -or $result.Message -isnot [string] -or ($result.Status -eq 'Completed' -and -not $result.PSObject.Properties['Result'])) {throw 'Kết quả thiếu trạng thái hoặc nội dung bắt buộc.'}
  if (($result.Status -eq 'Completed' -and -not $result.PSObject.Properties['Id']) -or ($result.PSObject.Properties['Id'] -and $result.Id -cne $Job.Id)) {throw 'Kết quả không khớp tác vụ đang chờ.'}
  if ($result.PSObject.Properties['Result'] -and $null -ne $result.Result -and $result.Result.PSObject.Properties['ExitCode']) {
   $code=$result.Result.ExitCode
   if (($code -isnot [int] -and $code -isnot [long]) -or $code -lt [int]::MinValue -or $code -gt [int]::MaxValue) {throw 'Mã kết quả của chương trình không hợp lệ.'}
   if (-not $result.Result.PSObject.Properties['Output'] -or $result.Result.Output -isnot [string]) {throw 'Thiếu nội dung kết quả của chương trình.'}
  }
  if ($result.Status -eq 'Completed' -and $Job.Id -eq 'wingetinstall' -and $result.Result.PSObject.Properties['Rows']) {
   foreach ($row in $result.Result.Rows) {if (-not $row.PSObject.Properties['Id'] -or -not $row.PSObject.Properties['State'] -or $row.State -notin @('Completed','Failed','Skipped')) {throw 'Kết quả cài ứng dụng thiếu thông tin từng mục.'}}
  }
  return $result
 }
 catch {return [pscustomobject]@{Status='Failed';Message='Không đọc được nhật ký kết quả; không báo thành công. Giữ tệp: '+$_.Exception.Message}}
}
function Get-ToolStatusLabel([string]$Status) {
 switch ($Status) {'Completed' {'Đã kết thúc'} 'Failed' {'Lỗi / chưa hoàn tất'} 'Partial' {'Một phần — có lỗi'} 'Cancelled' {'Đã hủy'} 'Running' {'Đang chạy'} default {'Chưa rõ'}}
}
function Format-ToolResult($Result) {
 $text=$Result.Message+"`n"
 if ($Result.PSObject.Properties['Id']) {try {$title=(Get-Tool $Result.Id).Title} catch {$title='Kết quả không nhận diện được — kiểm tra nhật ký'};$text=$title+"`n"+$text}
 if ($Result.PSObject.Properties['Mode'] -and $Result.Mode -eq 'Simulation') {$text="MÔ PHỎNG — không thực hiện trên Windows thật.`n"+$text}
 if ($Result.PSObject.Properties['RestartRequired'] -and $Result.RestartRequired) {$text+="Windows báo cần khởi động lại. Bạn tự lưu công việc và quyết định lúc restart; WinTune không tự làm.`n"}
 if ($Result.PSObject.Properties['Result']) {
  $data=$Result.Result
  if ($Result.PSObject.Properties['Id'] -and $Result.Id -eq 'dashboard' -and $null -ne $data) {return ($text+(Format-SystemOverview $data))}
  if ($Result.PSObject.Properties['Id'] -and $Result.Id -eq 'powerlist' -and $null -ne $data) {return ($text+(Format-PowerList $data))}
  if ($Result.PSObject.Properties['Id'] -and $Result.Id -in @('powerset','powerundo') -and $null -ne $data) {return ($text+$(if ($data.Status -eq 'NoOp') {'Máy đã dùng chế độ này; không thay đổi.'} elseif ($data.Status -in @('Applied','Undone')) {'Đã đổi và kiểm tra lại chế độ. Có thể quay lại chế độ trước bằng mục Trả về chế độ trước.'} else {'Chưa xác định được kết quả; xem nhật ký.'}))}
  if ($null -ne $data -and $data.PSObject.Properties['Output']) {$text+=$data.Output+"`n";if ($data.PSObject.Properties['Error']) {$text+=$data.Error}}
  else {$text+=($data | ConvertTo-Json -Depth 14)}
 }
 return $text
}
function Format-SystemOverview($Data) {
 $labels=@{Name='Tên';NumberOfCores='Số nhân';NumberOfLogicalProcessors='Luồng CPU';DriverVersion='Driver';TotalPhysicalMemory='RAM vật lý';Manufacturer='Hãng';Product='Model';Caption='Tên Windows';Version='Phiên bản';BuildNumber='Build';TotalVisibleMemorySize='RAM Windows nhận';FreePhysicalMemory='RAM khả dụng';DeviceID='Ổ';DriveType='Loại ổ';Size='Dung lượng';FreeSpace='Còn trống';FileSystem='Hệ tệp';ConfigManagerErrorCode='Mã lỗi thiết bị';FriendlyName='Tên';MediaType='Loại';HealthStatus='Trạng thái Windows báo';OperationalStatus='Hoạt động';TpmPresent='Có TPM';TpmReady='TPM sẵn sàng';TpmEnabled='TPM bật';AntivirusEnabled='Chống virus bật';RealTimeProtectionEnabled='Bảo vệ thời gian thực';AMServiceEnabled='Dịch vụ bảo vệ';Enabled='Bật'}
 $lines=@()
 foreach ($section in $Data.PSObject.Properties) {
  $lines+=($section.Name.ToUpperInvariant())
  if ($null -eq $section.Value) {$lines+='Chưa có dữ liệu';continue}
  if ($section.Value -is [string] -or $section.Value -is [bool]) {$lines+=$(if ($section.Value -is [bool]) {if ($section.Value) {'Có / bật'} else {'Không / tắt'}} else {[string]$section.Value});$lines+='';continue}
  foreach ($row in @($section.Value)) {
   foreach ($field in $row.PSObject.Properties) {
    $label=if ($labels.ContainsKey($field.Name)) {$labels[$field.Name]} else {$field.Name};$value=$field.Value
    if ($null -eq $value) {$value='Không có dữ liệu'}
    elseif ($field.Name -in @('TotalPhysicalMemory','Size','FreeSpace')) {$value=[Math]::Round([double]$value/1GB,2).ToString()+' GiB'}
    elseif ($field.Name -in @('TotalVisibleMemorySize','FreePhysicalMemory')) {$value=[Math]::Round([double]$value/1MB,2).ToString()+' GiB'}
    elseif ($value -is [bool]) {$value=if ($value) {'Có / bật'} else {'Không / tắt'}}
    $lines+=($label+': '+$value)
   }
   $lines+=''
  }
 }
 return ($lines -join "`n")
}
function Get-VisibleTools {
 # Retain internal readers for validated installation/history, not extra menu items.
 Get-ToolDefinitions | Where-Object {$_.Id -notin @('tempscan','tempdelete','recycle','restorepoint','wingetcheck','wingetsearch','wingetlist','wingetupdates','wingetshow','wingetupgrade','powerlist','powerset','powerundo','sfc','dismcheck','dismscan','dismrestore','diskcheck')}
}
function New-ToolsWindow([string]$Group) {
 Initialize-Tools (Join-Path $script:DataRoot 'tools') ([bool]($script:IsSimulation -or $script:WriteBlocked)) $script:UserId
 $script:ToolJob=$null
 [xml]$xml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Width="1100" Height="790" MinWidth="820" MinHeight="580" WindowStartupLocation="CenterOwner" Background="{DynamicResource Theme.InputBrush}" Foreground="{DynamicResource Theme.TextBrush}" FontFamily="Segoe UI" FontSize="14">
 <Grid Margin="22"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
 <TextBlock x:Name="ToolsHeading" Text="Công cụ Windows" FontSize="24" Foreground="{DynamicResource Theme.AccentBrush}" FontWeight="Bold"/>
 <TextBlock x:Name="ToolsIntro" Grid.Row="1" Margin="0,10,0,12" Text="Nhấp tên để đọc. Không có công cụ nào tự chạy khi mở; xem trước và xác nhận trước thay đổi."/>
 <Grid x:Name="ToolsLayout" Grid.Row="2"><Grid.ColumnDefinitions><ColumnDefinition Width="270"/><ColumnDefinition Width="16"/><ColumnDefinition/></Grid.ColumnDefinitions>
 <Grid><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition/></Grid.RowDefinitions><ComboBox x:Name="ToolGroup" Margin="0,0,0,12"/><ListBox x:Name="ToolList" Grid.Row="1" Background="{DynamicResource Theme.WindowBrush}" BorderThickness="0" ScrollViewer.HorizontalScrollBarVisibility="Disabled"/></Grid>
 <Grid x:Name="ToolDetailGrid" Grid.Column="2"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
 <ScrollViewer x:Name="ToolSetup" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" MaxHeight="320"><StackPanel Margin="0,0,10,0"><TextBlock x:Name="ToolTitle" FontSize="22" FontWeight="Bold"/><TextBlock x:Name="ToolDescription" Margin="0,12,0,12"/><TextBlock x:Name="ToolSource" Foreground="{DynamicResource Theme.MutedBrush}" Margin="0,0,0,12"/>
 <StackPanel x:Name="SoftwareOptions"><TextBlock Text="Chọn ứng dụng bạn muốn cài. Không có ứng dụng nào được chọn hoặc cài sẵn."/><TextBlock Text="Tìm phần mềm" FontSize="12" Margin="0,12,0,0" Foreground="{DynamicResource Theme.MutedBrush}"/><Grid Margin="0,6,0,8"><Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="190"/></Grid.ColumnDefinitions><TextBox x:Name="SoftwareSearch" ToolTip="Tìm theo tên hoặc mã ứng dụng" Margin="0,0,12,0"/><ComboBox x:Name="SoftwareCategory" Grid.Column="1"/></Grid><TextBlock x:Name="SoftwareSelected" FontSize="12" Foreground="{DynamicResource Theme.MutedBrush}" Margin="0,4,0,12"/><ScrollViewer x:Name="SoftwareGallery" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" MaxHeight="280"><UniformGrid x:Name="SoftwareSuggestions" Columns="3" Margin="-5,6,-5,12"/></ScrollViewer><TextBox x:Name="ToolInput" Visibility="Collapsed" Foreground="{DynamicResource Theme.TextBrush}" Background="{DynamicResource Theme.ButtonBrush}"/><CheckBox x:Name="SourceConsent" Content="Tôi đồng ý điều khoản của kho ứng dụng WinGet" Foreground="{DynamicResource Theme.TextBrush}" Margin="0,0,0,8"/><CheckBox x:Name="PackageConsent" Content="Tôi đã xem và đồng ý điều khoản của ứng dụng đã chọn" Foreground="{DynamicResource Theme.TextBrush}"/><CheckBox x:Name="SilentConsent" Visibility="Collapsed"/><WrapPanel Margin="0,12,0,0"><Button x:Name="AppTerms" Content="Xem thông tin ứng dụng đã chọn"/><Button x:Name="SourceTerms" Content="Điều khoản kho ứng dụng"/></WrapPanel></StackPanel>
 <StackPanel x:Name="TempOptions"><TextBlock Text="Chọn file từ lần quét mới nhất; không chọn sẵn. Quét giới hạn 10.000 file, hiển thị 200 file mỗi trang."/><ListBox x:Name="TempFiles" Background="{DynamicResource Theme.WindowBrush}" BorderThickness="0" MaxHeight="160" ScrollViewer.HorizontalScrollBarVisibility="Disabled"/><WrapPanel><Button x:Name="TempPrev" Content="Trang trước"/><Button x:Name="TempNext" Content="Trang sau"/><TextBlock x:Name="TempPageLabel" VerticalAlignment="Center"/></WrapPanel></StackPanel>
 <Button x:Name="RunTool" Content="Xem trước và thực hiện" Margin="0,12,0,0"/>
 </StackPanel></ScrollViewer>
 <Expander Foreground="{DynamicResource Theme.TextBrush}" x:Name="ToolProgress" Grid.Row="1" Header="Kết quả thực hiện" IsExpanded="True" Margin="0,8,0,0"><Expander.HeaderTemplate><DataTemplate><TextBlock Text="{Binding}" Foreground="{DynamicResource Theme.TextBrush}"/></DataTemplate></Expander.HeaderTemplate><TextBox x:Name="ToolOutput" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Background="{DynamicResource Theme.InputBrush}" Foreground="{DynamicResource Theme.TextBrush}" Padding="12"/></Expander>
 </Grid></Grid>
 <StackPanel Grid.Row="3" Margin="0,12,0,0"><TextBlock x:Name="ToolStatus"/><WrapPanel Margin="0,8,0,0"><Button x:Name="ToolHistory" Content="Xem nhật ký công cụ"/><Button x:Name="ToolsClose" Content="Đóng"/></WrapPanel></StackPanel>
 </Grid>
</Window>
'@
 $reader=New-Object Xml.XmlNodeReader $xml;$w=[Windows.Markup.XamlReader]::Load($reader);$reader.Close();$w.Resources=$script:Window.Resources
 Register-ThemeWindow $w
 if ($script:Window.IsVisible) {$w.Owner=$script:Window};$work=[Windows.SystemParameters]::WorkArea;$w.Width=[Math]::Min($w.Width,$work.Width);$w.Height=[Math]::Min($w.Height,$work.Height)
 $script:ToolsWindow=$w;$script:ToolsState=[pscustomobject]@{Current=$null;TempSelection=@{};TempInventory=@();TempPage=0;PowerState='';Packages=@{}}
 $w.FindName('TempPrev').Add_Click({if ($script:ToolsState.TempPage -gt 0) {$script:ToolsState.TempPage--;Render-TempPage}})
 $w.FindName('TempNext').Add_Click({if (($script:ToolsState.TempPage+1)*200 -lt $script:ToolsState.TempInventory.Count) {$script:ToolsState.TempPage++;Render-TempPage}})
 $w.Title='WinTune VI — Công cụ Windows';if ($ToolSimulation) {$w.Title+=' [MÔ PHỎNG]';$w.FindName('ToolsIntro').Text='MÔ PHỎNG: mọi kết quả thử được ghi rõ, không sửa Windows/gỡ/cài/xóa file thật.'}
 $groups=@('Tất cả')+@(Get-VisibleTools | Select-Object -ExpandProperty Group -Unique);foreach ($g in $groups) {$null=$w.FindName('ToolGroup').Items.Add($g)}
 $w.FindName('ToolGroup').Add_SelectionChanged({Render-ToolsList})
 $w.FindName('ToolList').Add_SelectionChanged({param($sender,$args) if ($null -ne $sender.SelectedItem) {Show-ToolDetail $sender.SelectedItem.Tag}})
 $w.FindName('RunTool').Add_Click({Invoke-ToolsSelection})
 $catalogData=Get-Content "$PSScriptRoot/software-catalog.json" -Raw -Encoding UTF8 | ConvertFrom-Json
 Initialize-SoftwarePicker $w $catalogData
 $w.FindName('ToolInput').Add_TextChanged({$script:ToolsWindow.FindName('PackageConsent').IsChecked=$false;$script:ToolsWindow.FindName('SilentConsent').IsChecked=$false})
 $w.FindName('AppTerms').Add_Click({
  try {if (-not $script:ToolsState.Packages.Count) {throw 'Chọn ứng dụng trước để xem thông tin.'};$p=Get-ToolsParameters;$null=Start-ToolJob wingetshow $p $false;Show-SoftwareOutput;$script:ToolsWindow.FindName('RunTool').IsEnabled=$false;$script:ToolsWindow.FindName('ToolOutput').Text='Đang đọc thông tin từ kho ứng dụng…';$script:ToolsTimer.Start()} catch {Message $_.Exception.Message}
 })
 $w.FindName('SourceTerms').Add_Click({if ($ToolSimulation) {Message 'Mô phỏng: không mở trang Internet.'} else {Start-Process 'https://learn.microsoft.com/en-us/windows/package-manager/winget/source'}})
 $w.FindName('ToolHistory').Add_Click({
  $lines=@('NHẬT KÝ CÔNG CỤ — kết quả và mã lỗi, không phải khôi phục tất cả.','')
  foreach ($dir in @(Get-ChildItem -LiteralPath $script:ToolRoot -Directory -Filter 'job-*' | Sort-Object LastWriteTime -Descending)) {
   $resultPath=Join-Path $dir.FullName 'result.json'
   if (Test-Path -LiteralPath $resultPath) {try {$r=Get-Content $resultPath -Raw -Encoding UTF8 | ConvertFrom-Json;$lines+=($dir.Name+' — '+(Get-ToolStatusLabel $r.Status)+' — '+$r.Message)} catch {$lines+='Nhật ký lỗi: '+$dir.Name}} else {$lines+='Chưa có kết quả / có thể bị ngắt: '+$dir.Name}
  }
  $null=Show-TextDialog 'Nhật ký công cụ' ($lines -join "`n")
 })
 $w.FindName('ToolsClose').Add_Click({param($sender,$args) [Windows.Window]::GetWindow($sender).Close()})
 $w.Add_Closing({param($sender,$eventArgs) if ($null -ne $script:ToolJob -and -not $script:ToolJob.Handled) {$eventArgs.Cancel=$true;$sender.FindName('ToolStatus').Text='Công cụ đang chạy. Đợi kết quả trước khi đóng cửa sổ.'}})
 $timer=New-Object Windows.Threading.DispatcherTimer;$timer.Interval=[TimeSpan]::FromMilliseconds(500)
 $timer.Add_Tick({Poll-ToolsJob});$script:ToolsTimer=$timer
 $w.Add_Closed({$script:ToolsTimer.Stop();$script:ToolsWindow=$null})
 $w.FindName('ToolGroup').SelectedItem=if ($Group -in $groups) {$Group} else {'Tất cả'}
 if ($Group -eq 'Phần mềm') {
  $w.Title='WinTune VI — Cài ứng dụng';$w.FindName('ToolsHeading').Text='Cài ứng dụng'
  $w.FindName('ToolsIntro').Text='Đánh dấu ứng dụng muốn cài, đọc thông tin và điều khoản, rồi bấm cài. WinTune sẽ hỏi xác nhận trước khi bắt đầu.'
  $w.FindName('ToolTitle').Visibility='Collapsed';$w.FindName('ToolDescription').Margin='0,0,0,8';$w.FindName('ToolSource').Margin='0,0,0,8'
  $w.FindName('SoftwareOptions').Children[0].Visibility='Collapsed'
  if ($ToolSimulation) {$w.FindName('ToolsIntro').Text='MÔ PHỎNG — chọn và xem trước, không cài ứng dụng thật.'}
  $w.FindName('ToolsLayout').ColumnDefinitions[0].Width=0;$w.FindName('ToolsLayout').ColumnDefinitions[1].Width=0
  $w.FindName('ToolGroup').Visibility='Collapsed';$w.FindName('ToolList').Visibility='Collapsed'
  $w.FindName('ToolDetailGrid').RowDefinitions[0].Height='*';$w.FindName('ToolDetailGrid').RowDefinitions[1].Height=0
  $w.FindName('ToolSetup').MaxHeight=[double]::PositiveInfinity;$w.FindName('ToolOutput').Visibility='Collapsed';$w.FindName('ToolProgress').Visibility='Collapsed'
  $w.FindName('ToolStatus').Text='Chọn ứng dụng ở trên. Chưa cài gì.'
  Pin-SoftwareActions $w
 }
 return $w
}
function Render-ToolsList {
 $w=$script:ToolsWindow;$list=$w.FindName('ToolList');$list.Items.Clear();$group=$w.FindName('ToolGroup').SelectedItem
 foreach ($tool in @(Get-VisibleTools | Where-Object {$group -eq 'Tất cả' -or $_.Group -eq $group})) {$item=New-Object Windows.Controls.ListBoxItem;$item.Tag=$tool;$item.Content=$tool.Title;$null=$list.Items.Add($item)}
 if ($list.Items.Count) {$list.SelectedIndex=0}
}
function Show-ToolDetail($Tool) {
 $w=$script:ToolsWindow;$script:ToolsState.Current=$Tool
 $w.FindName('ToolTitle').Text=$Tool.Title
 $w.FindName('ToolDescription').Text=$Tool.Description+"`n`nHoàn tác: "+$Tool.Undo+"`nKhông tự khởi động lại."
 Set-SourceLink ($w.FindName('ToolSource')) $Tool.Source
 if ($Tool.Id -eq 'wingetinstall') {$w.FindName('ToolTitle').Text='Chọn ứng dụng để cài';$w.FindName('ToolDescription').Text='Cài từ kho WinGet của Microsoft. Ứng dụng có thể mở trình cài đặt riêng. Lưu công việc trước khi cài; không tự cài khi mở WinTune.'}
 $w.FindName('SoftwareOptions').Visibility=if ($Tool.Id -like 'winget*' -and $Tool.Id -ne 'wingetcheck') {'Visible'} else {'Collapsed'}
 $w.FindName('TempOptions').Visibility=if ($Tool.Id -eq 'tempdelete') {'Visible'} else {'Collapsed'}
 $w.FindName('RunTool').IsEnabled=$null -eq $script:ToolJob -or $script:ToolJob.Handled
 $w.FindName('RunTool').Content=if ($Tool.Id -eq 'wingetinstall') {'Xem trước và cài ứng dụng'} else {'Xem trước và thực hiện'}
 if ($Tool.Id -eq 'wingetinstall') {
  $w.FindName('ToolSetup').MaxHeight=[double]::PositiveInfinity
  $w.FindName('ToolDetailGrid').RowDefinitions[0].Height='*';$w.FindName('ToolDetailGrid').RowDefinitions[1].Height=0;$w.FindName('ToolOutput').Visibility='Collapsed';$w.FindName('ToolProgress').Visibility='Collapsed'
 } else {$w.FindName('ToolSetup').MaxHeight=320;$w.FindName('ToolDetailGrid').RowDefinitions[0].Height='Auto';$w.FindName('ToolDetailGrid').RowDefinitions[1].Height='*';$w.FindName('ToolOutput').Visibility='Visible';$w.FindName('ToolProgress').Visibility='Visible';$w.FindName('ToolProgress').Header='Kết quả thực hiện'}
 $w.FindName('ToolStatus').Text='Trạng thái chưa đọc. Bấm thực hiện để đọc/quét; không suy ra trạng thái từ nút.'
}
function Get-ToolsParameters {
 $w=$script:ToolsWindow;$s=$script:ToolsState;$t=$s.Current
 $inputText=$w.FindName('ToolInput').Text.Trim()
 $ids=@($inputText -split '[,\r\n]+' | ForEach-Object {$_.Trim()} | Where-Object {$_});$ids+=@($s.Packages.Keys);$ids=@($ids | Select-Object -Unique)
 $p=[pscustomobject]@{Query=$inputText;PackageId=$(if ($ids.Count) {$ids[0]} else {''});PackageIds=$ids;SourceAgreed=[bool]$w.FindName('SourceConsent').IsChecked;PackageAgreed=[bool]$w.FindName('PackageConsent').IsChecked;SilentAgreed=[bool]$w.FindName('SilentConsent').IsChecked;Files=@($s.TempInventory | Where-Object {$s.TempSelection.ContainsKey($_.Path)});Guid='';Before=$s.PowerState}
 if ($t.Id -in @('wingetinstall','wingetupgrade','wingetshow')) {if (-not $ids.Count -or $ids.Count -gt 20) {throw 'Chọn 1–20 package ID. Không tìm mơ hồ để cài.'};foreach ($id in $ids) {if ($id -notmatch '^[A-Za-z0-9][A-Za-z0-9._+-]{2,127}$') {throw 'Package ID không hợp lệ.'}}}
 if ($t.Id -eq 'tempdelete' -and -not $p.Files.Count) {throw 'Quét trước và chọn file cụ thể.'}
 return $p
}
function Invoke-ToolsSelection {
 try {
  $t=$script:ToolsState.Current;$p=Get-ToolsParameters
  $text=$t.Title+"`n`n"+$script:ToolsWindow.FindName('ToolDescription').Text
  if ($t.Id -eq 'wingetinstall') {
   if (-not $p.PackageIds.Count) {throw 'Chọn ít nhất một ứng dụng để cài.'}
   if (-not $p.SourceAgreed -or -not $p.PackageAgreed) {throw 'Xem thông tin và điều khoản, rồi đánh dấu đồng ý trước khi cài.'}
   $names=@($script:ToolsState.Software | Where-Object {$_.Id -in $p.PackageIds} | Select-Object -ExpandProperty Title)
   $text+="`n`nỨng dụng sẽ cài:`n• "+($names -join "`n• ")+"`n`nBạn đã đồng ý điều khoản. Trình cài đặt có thể hỏi thêm thông tin. Không tự cập nhật các ứng dụng khác hoặc khởi động lại Windows."
   if ('UniKey.UniKey' -cin $p.PackageIds) {$text+="`n`nUniKey: bản x64 4.6.230919 từ unikey.org, chạy dạng portable. Bản mới hơn trong kho chỉ hỗ trợ ARM64. Nếu kho không còn bản này, WinTune báo lỗi và không đổi sang bản khác."}
  } else {$text+="`n`nTham số sẽ thực hiện:`n"+($p | ConvertTo-Json -Depth 6)}
  if ($t.Id -eq 'recycle') {$bytes=Get-RecycleBytes;$text+="`nDung lượng Thùng rác ước tính: $bytes byte. Xóa vĩnh viễn; không hoàn tác."}
  if ($t.Id -eq 'tempdelete') {$text+="`nDung lượng file đã chọn ước tính: $((($p.Files | Measure-Object Bytes -Sum).Sum)) byte. Không khôi phục dữ liệu."}
  if ($t.Mutates -or $t.Admin) {if (-not (Show-TextDialog 'Xem trước công cụ' $text $true 'Tôi xác nhận thao tác này')) {return}}
  $null=Start-ToolJob $t.Id $p $true $t.Admin
  if ($t.Id -eq 'wingetinstall') {Show-SoftwareOutput}
  $script:ToolsWindow.FindName('RunTool').IsEnabled=$false;$script:ToolsWindow.FindName('ToolOutput').Text='Đang chạy riêng, giao diện vẫn dùng được. Không đóng/khởi động lại khi công cụ đang làm.';$script:ToolsTimer.Start()
 } catch {Message $_.Exception.Message}
}
function Show-SoftwareOutput {
 $script:ToolsWindow.FindName('ToolOutput').Visibility='Visible';$script:ToolsWindow.FindName('ToolOutput').MaxHeight=110;$script:ToolsWindow.FindName('ToolProgress').Visibility='Visible';$script:ToolsWindow.FindName('ToolProgress').Header='Tiến trình cài đặt';$script:ToolsWindow.FindName('ToolProgress').IsExpanded=$true;$script:ToolsWindow.FindName('ToolDetailGrid').RowDefinitions[1].Height='Auto'
}
function Poll-ToolsJob {
 if ($null -eq $script:ToolJob -or $script:ToolJob.Handled) {return}
 $w=$script:ToolsWindow;$seconds=[int]((Get-Date)-$script:ToolJob.Started).TotalSeconds
 $w.FindName('ToolStatus').Text="Đang chạy $($script:ToolJob.Id) • $seconds giây • Chưa có kết quả cuối."
 $r=Get-ToolJobResult $script:ToolJob;if ($null -eq $r) {return}
 Complete-ToolJob $script:ToolJob;$script:ToolsTimer.Stop();$w.FindName('RunTool').IsEnabled=$true;$w.FindName('ToolStatus').Text=(Get-ToolStatusLabel $r.Status)+' — '+$r.Message;$w.FindName('ToolOutput').Text=Format-ToolResult $r
 if ($r.Status -eq 'Completed' -and $r.PSObject.Properties['Result']) {
  if ($script:ToolJob.Id -eq 'tempscan') {
   $script:ToolsState.TempInventory=@($r.Result.Files);$script:ToolsState.TempSelection.Clear();$script:ToolsState.TempPage=0;Render-TempPage
   $w.FindName('ToolOutput').Text="Đã quét $($script:ToolsState.TempInventory.Count) file; ước tính $((($script:ToolsState.TempInventory | Measure-Object Bytes -Sum).Sum)) byte. Không tự chọn/xóa. Lỗi đọc: $($r.Result.Errors); giới hạn quét: $($r.Result.Limited)."
  }
 }
 if ($script:ToolJob.Id -in @('sfc','dismcheck','dismscan','dismrestore','diskcheck')) {$conclusion=Get-RepairConclusion $r;$w.FindName('ToolStatus').Text=$conclusion;$w.FindName('ToolOutput').Text="KẾT LUẬN`n$conclusion`n`nCHI TIẾT DO WINDOWS TRẢ VỀ`n"+(Format-ToolResult $r)}
 if ($script:ToolJob.Id -eq 'wingetinstall' -and $r.PSObject.Properties['Result'] -and $r.Result.PSObject.Properties['Rows']) {
  $names=Get-Content "$PSScriptRoot/software-catalog.json" -Raw -Encoding UTF8 | ConvertFrom-Json
  $lines=@();foreach ($row in $r.Result.Rows) {$p=@($names | Where-Object Id -eq $row.Id);$title=if ($p.Count) {$p[0].Title} else {$row.Id};$state=switch ($row.State) {'Completed' {'Đã cài và được WinGet nhận diện'} 'Skipped' {'Chưa cài vì mục trước có lỗi'} default {'Chưa cài được — xem nhật ký để biết chi tiết'}};$lines+=$title+': '+$state}
  $w.FindName('ToolOutput').Text=$lines -join "`n";$w.FindName('ToolStatus').Text='Đã kết thúc yêu cầu cài ứng dụng. Kết quả từng ứng dụng ở phía trên.'
  if ($r.PSObject.Properties['RestartRequired'] -and $r.RestartRequired) {$w.FindName('ToolStatus').Text+=' Windows yêu cầu khởi động lại để hoàn tất. Bạn tự lưu công việc rồi khởi động lại; WinTune không tự làm.'}
 }
}
function Render-TempPage {
 $s=$script:ToolsState;$w=$script:ToolsWindow;$list=$w.FindName('TempFiles');$list.Items.Clear()
 foreach ($f in @($s.TempInventory | Select-Object -Skip ($s.TempPage*200) -First 200)) {
  $box=New-Object Windows.Controls.CheckBox;$box.Tag=$f.Path;$box.Content=$f.Path+' ('+$f.Bytes+' byte)';Set-ThemeResource $box Foreground Text;$box.IsChecked=$s.TempSelection.ContainsKey($f.Path)
  $box.Add_Click({param($sender,$args) if ($sender.IsChecked) {$script:ToolsState.TempSelection[$sender.Tag]=$true} else {$script:ToolsState.TempSelection.Remove($sender.Tag)}});$null=$list.Items.Add($box)
 }
 $w.FindName('TempPageLabel').Text='Trang '+($s.TempPage+1)+' • Đã chọn '+$s.TempSelection.Count
 $w.FindName('TempPrev').IsEnabled=$s.TempPage -gt 0;$w.FindName('TempNext').IsEnabled=($s.TempPage+1)*200 -lt $s.TempInventory.Count
}
function Open-Tools([string]$Group) {
 if ($Group -eq 'Sửa lỗi') {Open-CareRepair;return}
 try {$w=New-ToolsWindow $Group;$null=$w.ShowDialog()} catch {Message $_.Exception.Message} finally {$script:ToolsWindow=$null}
}
