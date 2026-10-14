#Requires -Version 5.1
# App appearance only. Never writes Windows Personalize keys.
function Get-ThemePalette([ValidateSet('Dark','Light')][string]$Mode) {
    if ($Mode -eq 'Light') {
        return [ordered]@{Window='#F3F3F3';Surface='#FFFFFF';Input='#FAFAFC';Button='#E9E9EF';Text='#202024';Muted='#60606D';Subtle='#686874';Accent='#005FB8';AccentButton='#0067C0';OnAccent='#FFFFFF';Selected='#DCEAF8';Hover='#E7E7ED';Border='#C4C4CD';Warning='#805000';Chart='#F0F0F5';Purple='#7451B8'}
    }
    return [ordered]@{Window='#202020';Surface='#2D2D33';Input='#25252B';Button='#33333B';Text='#EFEFF4';Muted='#B5B5BF';Subtle='#A2A2AF';Accent='#78B9FF';AccentButton='#245B90';OnAccent='#FFFFFF';Selected='#353E4D';Hover='#36363E';Border='#494950';Warning='#E8C991';Chart='#24252B';Purple='#B5A1FA'}
}
function Resolve-AppTheme([ValidateSet('System','Dark','Light')][string]$Mode,[ValidateSet('Dark','Light')][string]$SystemTheme='Dark') {
    if ($Mode -eq 'System') {return $SystemTheme};return $Mode
}
function Get-WindowsAppTheme {
    # Windows' application preference, independent of taskbar theme in Custom mode.
    try {
        $value=[Microsoft.Win32.Registry]::GetValue('HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize','AppsUseLightTheme',$null)
        if ($null -eq $value) {return [pscustomobject]@{Mode='Light';Error='';Default=$true}}
        if ($value -notin @(0,1)) {throw 'Giá trị giao diện ứng dụng của Windows không hợp lệ.'}
        return [pscustomobject]@{Mode=if ($value -eq 0) {'Dark'} else {'Light'};Error='';Default=$false}
    } catch {return [pscustomobject]@{Mode='Dark';Error=('Chưa đọc được giao diện Windows: '+$_.Exception.Message);Default=$false}}
}
function Read-ThemePreference([string]$Path) {
    try {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {return [pscustomobject]@{Mode='System';Error=''}}
        if ((Get-Item -LiteralPath $Path).Length -gt 8192) {throw 'Tệp lựa chọn giao diện quá lớn.'}
        $saved=Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($null -eq $saved -or -not $saved.PSObject.Properties['Version'] -or $saved.Version -ne 1 -or -not $saved.PSObject.Properties['Theme'] -or $saved.Theme -isnot [string] -or $saved.Theme -cnotin @('System','Dark','Light')) {throw 'Tệp lựa chọn giao diện không đúng định dạng.'}
        return [pscustomobject]@{Mode=[string]$saved.Theme;Error=''}
    } catch {return [pscustomobject]@{Mode='System';Error=('Không đọc được lựa chọn đã lưu: '+$_.Exception.Message)}}
}
function Save-ThemePreference([string]$Path,[ValidateSet('System','Dark','Light')][string]$Mode) {
    $folder=[IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path))
    $null=[IO.Directory]::CreateDirectory($folder)
    $temp=Join-Path $folder ('ui-settings-'+[guid]::NewGuid().ToString('N')+'.tmp')
    try {
        $canonical=switch ($Mode) {'System' {'System'} 'Dark' {'Dark'} 'Light' {'Light'}}
        $json=[pscustomobject]@{Version=1;Theme=$canonical} | ConvertTo-Json
        [IO.File]::WriteAllText($temp,$json,(New-Object Text.UTF8Encoding($true)))
        if ([IO.File]::Exists($Path)) {[IO.File]::Replace($temp,$Path,[System.Management.Automation.Language.NullString]::Value)} else {[IO.File]::Move($temp,$Path)}
    } finally {if ([IO.File]::Exists($temp)) {[IO.File]::Delete($temp)}}
}
