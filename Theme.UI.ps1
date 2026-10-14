. (Join-Path $PSScriptRoot 'Theme.Core.ps1')
$script:ThemeState=$null
function Set-ThemeResource($Control,[string]$Property,[string]$Key) {
    $field=$Control.GetType().GetField(($Property+'Property'),[Reflection.BindingFlags]'Public,Static,FlattenHierarchy')
    if ($null -eq $field) {throw "Không có thuộc tính màu $Property trên $($Control.GetType().Name)."}
    $Control.SetResourceReference($field.GetValue($null),('Theme.'+$Key+'Brush'))
}
function Update-ThemeTitleBar($Target) {
    if ($null -eq $script:ThemeState -or $script:ThemeState.MockNative) {return}
    try {
        $handle=([Windows.Interop.WindowInteropHelper]::new($Target)).Handle
        if ($handle -eq [IntPtr]::Zero) {return}
        if (-not ('WinTune.Appearance.Native' -as [type])) {Add-Type -Path (Join-Path $PSScriptRoot 'Theme.Native.cs')}
        if ($handle -ne [IntPtr]::Zero) {$code=[WinTune.Appearance.Native]::SetDarkTitleBar($handle,($script:ThemeState.Effective -eq 'Dark'));if ($code -lt 0) {$script:ThemeState.TitleError="Windows không hỗ trợ màu thanh tiêu đề (mã $code)."}}
    } catch {$script:ThemeState.TitleError=$_.Exception.Message}
}
function Register-ThemeWindow($Target) {
    # Weak references avoid retaining closed dialogs; resources are shared live.
    if ($null -eq $script:ThemeState) {return}
    $script:ThemeState.Windows.Add([WeakReference]::new($Target))
    $Target.Add_SourceInitialized({param($sender,$args) Update-ThemeTitleBar $sender})
    Update-ThemeTitleBar $Target
}
function Apply-AppTheme([ValidateSet('Dark','Light')][string]$Effective) {
    $palette=Get-ThemePalette $Effective
    foreach ($key in $palette.Keys) {
        $brush=[Windows.Media.BrushConverter]::new().ConvertFromString($palette[$key]);$brush.Freeze()
        $script:Window.Resources[('Theme.'+$key+'Brush')]=$brush
    }
    $script:ThemeState.Effective=$Effective
    for ($i=$script:ThemeState.Windows.Count-1;$i -ge 0;$i--) {
        $reference=$script:ThemeState.Windows[$i]
        if ($reference.IsAlive) {Update-ThemeTitleBar $reference.Target} else {$script:ThemeState.Windows.RemoveAt($i)}
    }
}
function Update-SystemAppTheme {
    if ($null -eq $script:ThemeState -or $script:ThemeState.Mode -ne 'System') {return}
    $reading=& $script:ThemeState.SystemReader
    if ($reading.Mode -ne $script:ThemeState.Effective) {Apply-AppTheme $reading.Mode}
    $script:ThemeState.SystemError=[string]$reading.Error
    Update-ThemeStatus
}
function Update-ThemeStatus {
    $state=$script:ThemeState
    $errorText=if ($state.SaveError) {$state.SaveError} elseif ($state.Mode -eq 'System' -and $state.SystemError) {$state.SystemError} else {''}
    $Window.FindName('ThemeStatus').Text=$errorText
    $Window.FindName('ThemeStatus').Visibility=if ($errorText) {'Visible'} else {'Collapsed'}
}
function Set-AppThemeMode([ValidateSet('System','Dark','Light')][string]$Mode,[bool]$Persist=$true) {
    $state=$script:ThemeState;$state.Mode=$Mode
    if ($Mode -eq 'System') {Update-SystemAppTheme} else {Apply-AppTheme $Mode}
    if ($Persist) {
        try {Save-ThemePreference $state.Path $Mode;$state.SaveError=''} catch {$state.SaveError='Giao diện đã đổi, nhưng chưa lưu được lựa chọn: '+$_.Exception.Message}
    }
    if ($null -ne $state.Timer) {if ($Mode -eq 'System' -and $state.AutoWatch) {$state.Timer.Start()} else {$state.Timer.Stop()}}
    Update-ThemeStatus
}
function Initialize-ThemeUI {
    $path=Join-Path $script:DataRoot 'ui-settings.json';$preference=Read-ThemePreference $path
    $script:ThemeState=[pscustomobject]@{Mode=$preference.Mode;Effective='';Path=$path;SaveError=$preference.Error;SystemError='';TitleError='';Windows=(New-Object 'Collections.Generic.List[WeakReference]');Timer=$null;AutoWatch=(-not $SelfTest -and -not $GuiProbe);MockNative=([bool]($SelfTest -or $GuiProbe -or $script:IsSimulation));SystemReader={Get-WindowsAppTheme}}
    if ($SelfTest -or ($GuiProbe -and $script:IsSimulation)) {$script:ThemeState.SystemReader={ [pscustomobject]@{Mode='Dark';Error=''} }}
    $box=$Window.FindName('ThemeChoice')
    foreach ($pair in @(@('System','Theo hệ thống'),@('Dark','Tối'),@('Light','Sáng'))) {$entry=New-Object Windows.Controls.ComboBoxItem;$entry.Content=$pair[1];$entry.Tag=$pair[0];$null=$box.Items.Add($entry);if ($pair[0] -eq $preference.Mode) {$box.SelectedItem=$entry}}
    $timer=New-Object Windows.Threading.DispatcherTimer;$timer.Interval=[TimeSpan]::FromSeconds(2);$timer.Add_Tick({Update-SystemAppTheme});$script:ThemeState.Timer=$timer
    Register-ThemeWindow $Window
    Set-AppThemeMode $preference.Mode $false
    $box.Add_SelectionChanged({if ($null -ne $Window.FindName('ThemeChoice').SelectedItem) {Set-AppThemeMode $Window.FindName('ThemeChoice').SelectedItem.Tag}})
    $Window.Add_Activated({if ($script:ThemeState.Mode -eq 'System') {Update-SystemAppTheme}})
    $Window.Add_Closed({$script:ThemeState.Timer.Stop();$script:ThemeState.Windows.Clear()})
}
function Stop-ThemeUI {if ($null -ne $script:ThemeState -and $null -ne $script:ThemeState.Timer) {$script:ThemeState.Timer.Stop();$script:ThemeState.Windows.Clear()}}
