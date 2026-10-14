#Requires -Version 5.1
$ErrorActionPreference='Stop'
$catalog=Get-Content "$PSScriptRoot/features.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$total=0
$strings=0
function Get-ReviewedTargets([string]$Source) {
    $table=@{}
    if ($Source -match '/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json$') {
        $data=Get-Content "$PSScriptRoot/sources/review-20261014/winutil/config__tweaks.json.txt" -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($entry in $data.PSObject.Properties) {
            if (-not $entry.Value.PSObject.Properties['registry']) {continue}
            foreach ($r in $entry.Value.registry) {
                if ($r.Type -ne 'DWord') {continue}
                $key=$r.Path.Replace(':','').ToLowerInvariant()+'\'+$r.Name.ToLowerInvariant()
                $values=@();foreach ($v in @($r.Value,$r.OriginalValue)) {if ([string]$v -match '^\d+$') {$values+=[int]$v}}
                $table[$key]=[pscustomobject]@{Type='DWord';Values=$values}
            }
        };return $table
    }
    $name=($Source -split '/')[-1];$path=Join-Path "$PSScriptRoot/sources" ($name+'.txt')
    if (-not (Test-Path -LiteralPath $path)) {$path=Join-Path "$PSScriptRoot/sources" $name}
    $bytes=[IO.File]::ReadAllBytes($path);$encoding=if ($bytes.Length -gt 1 -and $bytes[0] -eq 255 -and $bytes[1] -eq 254) {[Text.Encoding]::Unicode} else {[Text.Encoding]::UTF8}
    $raw=$encoding.GetString($bytes);$hive='';$keyPath=''
    foreach ($line in ($raw -split '\r?\n')) {
        if ($line -match '^\[HKEY_CURRENT_USER\\(.+)\]') {$keyPath=$Matches[1];$hive='HKCU'}
        elseif ($line -match '^\[HKEY_LOCAL_MACHINE\\(.+)\]') {$keyPath=$Matches[1];$hive='HKLM'}
        elseif ($line -match '^\[HKEY_') {$keyPath='';$hive=''}
        elseif ($keyPath -and $line -match '^"([^"]+)"=dword:([0-9a-fA-F]{8})') {$table[("$hive\$keyPath\$($Matches[1])").ToLowerInvariant()]=[pscustomobject]@{Type='DWord';Values=@([Convert]::ToInt32($Matches[2],16))}}
        elseif ($keyPath -and $line -match '^"([^"]+)"="([^"\\]*)"$') {$table[("$hive\$keyPath\$($Matches[1])").ToLowerInvariant()]=[pscustomobject]@{Type='String';Values=@($Matches[2])}}
        elseif ($keyPath -and $line -eq '@=""') {$table[("$hive\$keyPath\").ToLowerInvariant()]=[pscustomobject]@{Type='String';Values=@('')}}
    };return $table
}
foreach ($f in $catalog) {
    if ($f.Kind -in @('Settings','Action')) { continue }
    if ($f.Id -eq 'scrollbars' -or $f.Id -in @('pointerprecision','windowsnapping')) {
        $targets=Get-ReviewedTargets $f.Source
        foreach ($c in $f.Changes) {$key=("HKCU\$($c.Path)\$($c.Name)").ToLowerInvariant();if (-not $targets.ContainsKey($key) -or $targets[$key].Type -ne $c.Type -or $c.Value -cnotin $targets[$key].Values) {throw 'New setting differs from pinned source.'};if ($c.Type -eq 'String') {$strings++} else {$total++}}
        continue
    }
    if ($f.Id -in @('edgestartupboost','edgebackground')) {
        $policy=if ($f.Id -eq 'edgestartupboost') {'StartupBoostEnabled'} else {'BackgroundModeEnabled'}
        $source='https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/'+$policy.ToLowerInvariant()
        if ($f.Source -cne $source -or @($f.Changes).Count -ne 1 -or $f.Changes[0].Path -cne 'Software\Policies\Microsoft\Edge' -or $f.Changes[0].Name -cne $policy -or $f.Changes[0].Value -ne 0) { throw 'Edge mapping differs from reviewed Microsoft policy documentation.' }
        $total++; Write-Output "PASS SOURCE: $($f.Id) (reviewed Microsoft policy)"; continue
    }
    if ($f.Id -eq 'widgets') {
        $proof=Get-Content "$PSScriptRoot/sources/microsoft-taskbar-reference.json" -Raw -Encoding UTF8 | ConvertFrom-Json
        $referencePath="$PSScriptRoot/sources/microsoft-taskbar-reference.psm1.txt"
        if ($f.Source -ne $proof.Source -or (Get-FileHash -LiteralPath $referencePath -Algorithm SHA256).Hash -ne $proof.SHA256) { throw 'Microsoft Widgets source differs from reviewed snapshot.' }
        $reference=Get-Content -LiteralPath $referencePath -Raw -Encoding UTF8
        if (-not $reference.Contains("hidden [string] `$TaskbarDa = 'TaskbarDa'") -or -not $reference.Contains('HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\') -or -not $reference.Contains('$desiredWidgetsButtonState = $this.WidgetsButton -eq [ShowHideFeature]::Show ? 1 : 0')) { throw 'Microsoft Widgets mapping differs from reviewed implementation.' }
        if (@($f.Changes).Count -ne 1 -or $f.Changes[0].Path -cne 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -or $f.Changes[0].Name -cne 'TaskbarDa' -or $f.Changes[0].Value -ne 0 -or $f.MinBuild -lt 22000) { throw 'Widgets target differs from the reviewed Windows 11 mapping.' }
        $total++; Write-Output 'PASS SOURCE: widgets (pinned Microsoft winget-dsc)'; continue
    }
    $name=($f.Source -split '/')[-1]
    $sourcePath=Join-Path "$PSScriptRoot/sources" $name
    if (-not (Test-Path -LiteralPath $sourcePath)) { $sourcePath+='.txt' }
    $raw=Get-Content -LiteralPath $sourcePath -Raw -Encoding Unicode
    $table=@{}; $path='';$hive=''
    foreach ($line in ($raw -split '\r?\n')) {
        if ($line -match '^\[HKEY_CURRENT_USER\\(.+)\]') {$path=$Matches[1];$hive='HKCU'}
        elseif ($line -match '^\[HKEY_LOCAL_MACHINE\\(.+)\]') {$path=$Matches[1];$hive='HKLM'}
        elseif ($line -match '^\[HKEY_') { $path='';$hive='' }
        elseif ($path -and $line -match '^"([^"]+)"=dword:([0-9a-fA-F]{8})') { $table[("$hive\$path\$($Matches[1])").ToLowerInvariant()]=[pscustomobject]@{Type='DWord';Value=[Convert]::ToInt32($Matches[2],16)} }
        elseif ($path -and $line -eq '@=""') {$table[("$hive\$path\").ToLowerInvariant()]=[pscustomobject]@{Type='String';Value=''}}
    }
    foreach ($c in $f.Changes) {
        $hive=if ($c.PSObject.Properties['Hive']) {$c.Hive} else {'HKCU'};$type=if ($c.PSObject.Properties['Type']) {$c.Type} else {'DWord'}
        $key=("$hive\$($c.Path)\$($c.Name)").ToLowerInvariant()
        if (-not $table.ContainsKey($key) -or $table[$key].Value -cne $c.Value -or $table[$key].Type -ne $type) { throw "Catalog differs from pinned upstream: $($f.Id) $key" }
        if ($type -eq 'String') {$strings++} else {$total++}
    }
    Write-Output "PASS SOURCE: $($f.Id)"
}
$choiceCount=0
foreach ($f in $catalog | Where-Object {$_.PSObject.Properties['Choices']}) {
    foreach ($choice in $f.Choices) {
        $targets=Get-ReviewedTargets $choice.Source
        for ($i=0;$i -lt @($f.Changes).Count;$i++) {$c=$f.Changes[$i];$key=("HKCU\$($c.Path)\$($c.Name)").ToLowerInvariant();if (-not $targets.ContainsKey($key) -or $targets[$key].Type -ne 'DWord' -or $choice.Values[$i] -cnotin $targets[$key].Values) {throw "Choice differs from pinned source: $($f.Id)/$($choice.Id)"}}
        $choiceCount++
    }
}
$ctt=Get-Content "$PSScriptRoot/sources/winutil/source.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$appxSource="$PSScriptRoot/sources/winutil/appx.json.txt"
if ((Get-FileHash -LiteralPath $appxSource -Algorithm SHA256).Hash -ne $ctt.AppxSHA256) { throw 'WinUtil app list differs from pinned snapshot.' }
$appxData=Get-Content -LiteralPath $appxSource -Raw -Encoding UTF8 | ConvertFrom-Json
$allowedApps=Get-Content "$PSScriptRoot/app-catalog.json" -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($a in @($allowedApps)) {
    $sourceApps=@($appxData.PSObject.Properties | Where-Object { $_.Value.PackageId -ceq $a.Name })
    $store=if ($sourceApps.Count -eq 1 -and $sourceApps[0].Value.PSObject.Properties['StoreId']) {[string]$sourceApps[0].Value.StoreId} else {''}
    if ($sourceApps.Count -ne 1 -or $store -cne $a.StoreId) { throw 'App name or reinstall product differs from pinned WinUtil list.' }
}
$software=Get-Content "$PSScriptRoot/software-catalog.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$appSource=Get-Content "$PSScriptRoot/sources/review-20261014/winutil/config__applications.json.txt" -Raw -Encoding UTF8 | ConvertFrom-Json
$seenSoftware=@{}
foreach ($p in $software) {
    if ($p.Id -ceq 'UniKey.UniKey') {
        $proof=Get-Content "$PSScriptRoot/sources/curated-v014/source.json" -Raw -Encoding UTF8|ConvertFrom-Json
        $manifest=Get-Content "$PSScriptRoot/sources/curated-v014/UniKey.UniKey.locale.en-US.yaml.txt" -Raw -Encoding UTF8
        foreach ($file in $proof.Files) {if ((Get-FileHash -LiteralPath (Join-Path "$PSScriptRoot/sources/curated-v014" $file.Name) -Algorithm SHA256).Hash -cne $file.SHA256) {throw 'Curated WinGet source changed after review.'}}
        $installer=Get-Content "$PSScriptRoot/sources/curated-v014/UniKey.UniKey.installer.yaml.txt" -Raw -Encoding UTF8
        if ($proof.Version -cne '4.6.230919' -or $p.Version -cne $proof.Version -or $proof.Architecture -cne 'x64' -or $p.Architecture -cne $proof.Architecture -or -not $installer.Contains('PackageVersion: 4.6.230919') -or -not $installer.Contains('- Architecture: x64') -or -not $installer.Contains('InstallerUrl: https://www.unikey.org/assets/release/unikey46RC2-230919-win64.zip')) {throw 'UniKey must use the reviewed official x64 installer.'}
        if ($proof.PackageId -cne $p.Id -or -not $manifest.Contains('PackageIdentifier: UniKey.UniKey') -or -not $manifest.Contains('PublisherUrl: https://www.unikey.org/') -or $p.Source -cne ('https://github.com/microsoft/winget-pkgs/tree/'+$proof.Commit+'/'+$proof.Path) -or $seenSoftware.ContainsKey($p.Id)) {throw 'UniKey differs from pinned official WinGet manifest.'}
        $seenSoftware[$p.Id]=$true;continue
    }
    $sourceTitle=if ($p.PSObject.Properties['UpstreamTitle']) {$p.UpstreamTitle} else {$p.Title}
    $matched=@($appSource.PSObject.Properties | Where-Object {$_.Value.PSObject.Properties['winget'] -and $_.Value.winget -ceq $p.Id -and $_.Value.content -ceq $sourceTitle})
    if ($matched.Count -ne 1 -or $seenSoftware.ContainsKey($p.Id)) {throw 'Software catalog differs from pinned WinUtil IDs/names.'};$seenSoftware[$p.Id]=$true
}
Write-Output "SOURCE VERIFICATION PASSED: $total DWORDs, $strings REG_SZ, $choiceCount choices; $($software.Count) software IDs and $($allowedApps.Count) apps match pinned sources. Does not prove runtime effectiveness or all installers."
