# Dashboard-only, on-demand read. Reuses the existing Windows readers.
function Get-DiagnosticField($Data,[string]$Name) {
    if ($null -eq $Data -or $null -eq $Data.PSObject.Properties[$Name]) {return $null}
    return ,$Data.PSObject.Properties[$Name].Value
}
function Format-DiagnosticSwitch($Value) {
    if ($Value -is [bool]) {if ($Value) {return 'Bật'} else {return 'Tắt'}}
    # Firewall uses a CIM enum; NotConfigured and null must remain unknown.
    if ($null -ne $Value -and [string]$Value -in @('True','1')) {return 'Bật'}
    if ($null -ne $Value -and [string]$Value -in @('False','0')) {return 'Tắt'}
    return 'Chưa đọc được'
}
function Show-DashboardDiagnostics($Data) {
    $Window.FindName('DiagnosticsResults').Visibility='Visible'
    foreach ($name in @('DiagnosticsTpm','DiagnosticsBoot','DiagnosticsDefender','DiagnosticsFirewall','DiagnosticsDevices')) {Set-MonitorText $name 'Chưa đọc được'}
    if ((Get-DiagnosticField $Data Mode) -eq 'MÔ PHỎNG') {
        Set-MonitorText 'DiagnosticsStatus' 'MÔ PHỎNG — không kiểm tra bảo mật hoặc thiết bị thật.'
        return
    }
    $time=Get-DiagnosticField $Data Time
    try {$time=[DateTime]::Parse($time).ToLocalTime().ToString('HH:mm:ss')} catch {$time='không rõ thời điểm'}
    Set-MonitorText 'DiagnosticsStatus' "Kết quả lúc $time • Chỉ đọc • Bấm Kiểm tra lại để cập nhật"
    $tpm=Get-DiagnosticField $Data TPM
    if ($null -ne $tpm -and $tpm -isnot [string]) {
        $present=Get-DiagnosticField $tpm TpmPresent
        $label=if ($present -is [bool]) {if ($present) {'Có TPM'} else {'Windows báo không có TPM'}} else {'Chưa đọc được'}
        Set-MonitorText 'DiagnosticsTpm' ($label+"`nTrạng thái: "+(Format-DiagnosticSwitch (Get-DiagnosticField $tpm TpmEnabled))+"`nSẵn sàng: "+(Format-DiagnosticSwitch (Get-DiagnosticField $tpm TpmReady)))
    } elseif ($tpm -is [string]) {Set-MonitorText 'DiagnosticsTpm' $tpm}
    $boot=Get-DiagnosticField $Data 'Secure Boot'
    Set-MonitorText 'DiagnosticsBoot' $(if ($boot -is [string]) {$boot} else {Format-DiagnosticSwitch $boot})
    $defender=Get-DiagnosticField $Data Defender
    if ($null -ne $defender -and $defender -isnot [string]) {
        Set-MonitorText 'DiagnosticsDefender' ("Bảo vệ thời gian thực: "+(Format-DiagnosticSwitch (Get-DiagnosticField $defender RealTimeProtectionEnabled))+"`nChống virus: "+(Format-DiagnosticSwitch (Get-DiagnosticField $defender AntivirusEnabled)))
    } elseif ($defender -is [string]) {Set-MonitorText 'DiagnosticsDefender' $defender}
    $firewall=Get-DiagnosticField $Data Firewall
    if ($null -ne $firewall -and $firewall -isnot [string]) {
        $lines=@();$labels=@{Domain='Mạng cơ quan';Private='Mạng riêng';Public='Mạng công cộng'}
        foreach ($profile in @($firewall)) {
            $name=[string](Get-DiagnosticField $profile Name);$label=if ($labels.ContainsKey($name)) {$labels[$name]} elseif ($name) {$name} else {'Cấu hình chưa rõ'}
            $lines+=($label+': '+(Format-DiagnosticSwitch (Get-DiagnosticField $profile Enabled)))
        }
        if ($lines.Count) {Set-MonitorText 'DiagnosticsFirewall' ($lines -join "`n")}
    } elseif ($firewall -is [string]) {Set-MonitorText 'DiagnosticsFirewall' $firewall}
    # An empty successful device query differs from a failed/missing query.
    $devices=Get-DiagnosticField $Data 'Lỗi thiết bị'
    if ($devices -is [string]) {Set-MonitorText 'DiagnosticsDevices' $devices}
    elseif ($null -ne $devices) {
        $rows=@($devices | Where-Object {$null -ne $_})
        if (-not $rows.Count) {Set-MonitorText 'DiagnosticsDevices' 'Windows không báo thiết bị lỗi trong lần kiểm tra này.'}
        else {Set-MonitorText 'DiagnosticsDevices' (($rows | ForEach-Object {([string](Get-DiagnosticField $_ Name))+' — mã lỗi '+(Get-DiagnosticField $_ ConfigManagerErrorCode)}) -join "`n")}
    }
}
function Start-DashboardDiagnostics {
    if ($script:MonitorState.Closing -or $null -ne $script:MonitorState.DiagnosticsJob) {return}
    $Window.FindName('DiagnosticsResults').Visibility='Collapsed'
    Set-MonitorText 'DiagnosticsStatus' 'Đang kiểm tra… Bạn vẫn có thể dùng giao diện.'
    try {
        $script:MonitorState.DiagnosticsJob=New-MonitorJob Diagnostics
        $Window.FindName('DashboardDiagnostics').IsEnabled=$false
        $script:MonitorState.Timer.Start()
    } catch {Set-MonitorText 'DiagnosticsStatus' ('Không bắt đầu kiểm tra được: '+$_.Exception.Message)}
}
function Poll-DashboardDiagnostics {
    $job=$script:MonitorState.DiagnosticsJob
    if ($null -eq $job -or -not $job.Handle.IsCompleted) {return}
    $script:MonitorState.DiagnosticsJob=$null
    try {$result=Receive-MonitorJob $job;if (-not $script:MonitorState.Closing) {Show-DashboardDiagnostics $result}}
    catch {if (-not $script:MonitorState.Closing) {Set-MonitorText 'DiagnosticsStatus' ('Không kiểm tra được: '+$_.Exception.Message)}}
    $Window.FindName('DashboardDiagnostics').IsEnabled=$true
    $Window.FindName('DashboardDiagnostics').Content='Kiểm tra lại'
    if ($script:IsSimulation) {$script:MonitorState.Timer.Stop()}
}
