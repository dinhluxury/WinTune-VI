# Data only from Releases. Never import downloaded scripts, modules or expressions.
Set-StrictMode -Version Latest
function Get-WinTuneVersion([string]$Root) {
    $v=Get-Content -LiteralPath (Join-Path $Root 'version.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($v.Schema -ne 1 -or $v.Version -notmatch '^\d{1,4}\.\d{1,4}\.\d{1,4}$' -or $v.Architecture -ne 'x64' -or $v.MinimumBuild -lt 22000) {throw 'Thông tin phiên bản không hợp lệ.'}
    return $v
}
function Assert-ReleaseTrust($Config) {
    if ($Config.Schema -ne 1 -or $Config.Channel -ne 'stable' -or $Config.Repository -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]{0,99}/[A-Za-z0-9][A-Za-z0-9_.-]{0,99}$' -or -not $Config.PublicKeyXml) {throw 'Chưa cấu hình repository GitHub và khóa công khai tin cậy. Xem DISTRIBUTION.md.'}
    if ($Config.PublicKeyXml -match '<(D|P|Q|DP|DQ|InverseQ)>') {throw 'Không được phân phối khóa riêng trong cấu hình.'}
    if ($Config.PublicKeyXml.Length -gt 8192 -or $Config.PublicKeyXml.Contains('<!')) {throw 'Khóa công khai không hợp lệ.'}
    [xml]$keyXml=$Config.PublicKeyXml
    if ($keyXml.DocumentElement.Name -cne 'RSAKeyValue' -or @($keyXml.DocumentElement.ChildNodes | Where-Object {$_.NodeType -eq 'Element' -and $_.Name -notin @('Modulus','Exponent')}).Count) {throw 'Chỉ cho phép các thành phần khóa công khai RSA.'}
    $rsa=New-Object Security.Cryptography.RSACryptoServiceProvider
    $rsa.PersistKeyInCsp=$false
    try {$rsa.FromXmlString($Config.PublicKeyXml);if ($rsa.KeySize -lt 2048) {throw 'Khóa ký phải có ít nhất 2048 bit.'}} finally {$rsa.Dispose()}
}
function Get-ReleaseConfig([string]$Root) {
    $cfg=Get-Content -LiteralPath (Join-Path $Root 'release-config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-ReleaseTrust $cfg;return $cfg
}
function Assert-DistributionCancelled($Cancellation) {
    if ($null -ne $Cancellation -and $Cancellation.IsCancellationRequested) {throw [OperationCanceledException]::new('Đã hủy; không kích hoạt bản mới.')}
}
function Assert-DistributionUrl([string]$Url) {
    $uri=[uri]$Url
    if (-not $uri.IsAbsoluteUri -or $uri.Scheme -cne 'https' -or $uri.Port -ne 443 -or $uri.UserInfo -or $uri.Fragment -or $uri.Host -notin @('api.github.com','github.com','release-assets.githubusercontent.com','objects.githubusercontent.com')) {throw 'URL tải nằm ngoài GitHub HTTPS được cho phép.'}
}
function Get-DistributionBytes([string]$Url,[long]$Limit,$Cancellation=$null) {
    Assert-DistributionUrl $Url
    Add-Type -AssemblyName System.Net.Http
    [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
    $last='';$retryable=$true
    for ($attempt=0;$attempt -lt 3;$attempt++) {
        Assert-DistributionCancelled $Cancellation
        $handler=New-DistributionHttpHandler
        $client=New-Object Net.Http.HttpClient $handler;$client.Timeout=[TimeSpan]::FromSeconds(20)
        $client.DefaultRequestHeaders.UserAgent.ParseAdd('WinTuneVI/0.15');$client.DefaultRequestHeaders.Accept.ParseAdd('application/vnd.github+json')
        $requestCancel=if ($null -ne $Cancellation) {[Threading.CancellationTokenSource]::CreateLinkedTokenSource($Cancellation.Token,[Threading.CancellationToken]::None)} else {New-Object Threading.CancellationTokenSource}
        $requestCancel.CancelAfter(30000)
        $response=$null;$inputStream=$null;$bufferStream=New-Object IO.MemoryStream
        try {
            $current=$Url
            for ($redirect=0;$redirect -le 4;$redirect++) {
                Assert-DistributionCancelled $Cancellation;Assert-DistributionUrl $current
                $token=$requestCancel.Token
                $response=$client.GetAsync($current,[Net.Http.HttpCompletionOption]::ResponseHeadersRead,$token).GetAwaiter().GetResult()
                $code=[int]$response.StatusCode
                if ($code -in @(301,302,303,307,308)) {
                    if ($redirect -eq 4 -or $null -eq $response.Headers.Location) {throw 'Quá nhiều lần chuyển hướng.'}
                    $current=([uri]::new([uri]$current,$response.Headers.Location)).AbsoluteUri;$response.Dispose();$response=$null;continue
                }
                if ($code -ne 200) {$retryable=$code -in @(408,429,500,502,503,504);throw "GitHub trả HTTP $code. Kiểm tra kết nối, repository hoặc giới hạn API."}
                break
            }
            if ($response.Content.Headers.ContentLength -gt $Limit) {$retryable=$false;throw 'Tệp tải vượt giới hạn dung lượng.'}
            $inputStream=$response.Content.ReadAsStreamAsync().GetAwaiter().GetResult();$buffer=New-Object byte[] 65536
            $deadline=[DateTime]::UtcNow.AddSeconds(25)
            while ($true) {
                Assert-DistributionCancelled $Cancellation
                if ([DateTime]::UtcNow -gt $deadline) {throw 'Tải tệp quá thời gian cho phép.'}
                $read=$inputStream.ReadAsync($buffer,0,$buffer.Length,$token).GetAwaiter().GetResult();if (-not $read) {break}
                if ($bufferStream.Length+$read -gt $Limit) {$retryable=$false;throw 'Tệp tải vượt giới hạn dung lượng.'}
                $bufferStream.Write($buffer,0,$read)
            }
            return ,$bufferStream.ToArray()
        } catch {
            Assert-DistributionCancelled $Cancellation;$last=$_.Exception.Message
            if (-not $retryable -or $attempt -eq 2) {break}
            Start-Sleep -Milliseconds (250*($attempt+1))
        } finally {
            if ($null -ne $inputStream) {$inputStream.Dispose()};if ($null -ne $response) {$response.Dispose()}
            $bufferStream.Dispose();$client.Dispose();$handler.Dispose();$requestCancel.Dispose()
        }
    }
    throw ('Không tải được bản phát hành. Không chạy mã tải về. '+$last)
}
function New-DistributionHttpHandler {$handler=New-Object Net.Http.HttpClientHandler;$handler.AllowAutoRedirect=$false;return $handler}
function Get-DistributionHash([byte[]]$Bytes) {
    $sha=[Security.Cryptography.SHA256]::Create();try {return [BitConverter]::ToString($sha.ComputeHash($Bytes)).Replace('-','')} finally {$sha.Dispose()}
}
function Read-SignedRelease([byte[]]$Manifest,[byte[]]$Signature,$Config,[string]$Tag) {
    Assert-ReleaseTrust $Config
    if ($Manifest.Length -gt 65536 -or $Signature.Length -gt 1024) {throw 'Manifest/chữ ký vượt giới hạn.'}
    $rsa=New-Object Security.Cryptography.RSACryptoServiceProvider;$rsa.PersistKeyInCsp=$false
    try {$rsa.FromXmlString($Config.PublicKeyXml);if (-not $rsa.VerifyData($Manifest,[Security.Cryptography.CryptoConfig]::MapNameToOID('SHA256'),$Signature)) {throw 'Chữ ký manifest không đúng khóa tin cậy; dừng cập nhật.'}} finally {$rsa.Dispose()}
    $m=([Text.Encoding]::UTF8.GetString($Manifest)) | ConvertFrom-Json
    if ($m.Schema -ne 1 -or $m.Repository -cne $Config.Repository -or $m.Version -notmatch '^\d{1,4}\.\d{1,4}\.\d{1,4}$' -or $Tag -cne ('v'+$m.Version) -or $m.Architecture -cne 'x64' -or $m.MinimumBuild -lt 22000 -or $m.Asset -cne ('WinTune-VI-v'+$m.Version+'-portable.zip') -or $m.SHA256 -notmatch '^[0-9A-Fa-f]{64}$' -or $m.Size -le 0 -or $m.Size -gt 67108864) {throw 'Manifest không khớp repository, tag, kiến trúc hoặc gói portable.'}
    return $m
}
function Get-DistributionUpdate($Config,[string]$CurrentVersion,$Cancellation=$null) {
    Assert-ReleaseTrust $Config
    $url='https://api.github.com/repos/'+$Config.Repository+'/releases/latest'
    $raw=Get-DistributionBytes $url 1048576 $Cancellation;$release=([Text.Encoding]::UTF8.GetString($raw)) | ConvertFrom-Json
    if ($release.draft -or $release.prerelease -or $release.tag_name -notmatch '^v\d{1,4}\.\d{1,4}\.\d{1,4}$') {throw 'Chỉ hỗ trợ bản stable với tag vX.Y.Z.'}
    $tag=[string]$release.tag_name;$prefix='https://github.com/'+$Config.Repository+'/releases/download/'+$tag+'/'
    $assets=@{};foreach ($a in $release.assets) {if ($a.name -in @('release.json','release.sig',('WinTune-VI-'+$tag+'-portable.zip'))) {if ($assets.ContainsKey($a.name) -or $a.browser_download_url -cne ($prefix+$a.name) -or $a.state -ne 'uploaded') {throw 'Asset phát hành không hợp lệ.'};$assets[$a.name]=$a.browser_download_url}}
    if (-not $assets.ContainsKey('release.json') -or -not $assets.ContainsKey('release.sig')) {throw 'Release thiếu manifest ký số; không tải ứng dụng.'}
    $manifestBytes=Get-DistributionBytes $assets['release.json'] 65536 $Cancellation;$signatureBytes=Get-DistributionBytes $assets['release.sig'] 1024 $Cancellation
    $m=Read-SignedRelease $manifestBytes $signatureBytes $Config $tag
    if (-not $assets.ContainsKey($m.Asset)) {throw 'Release thiếu ZIP đã ký.'}
    return [pscustomobject]@{Status=$(if ([version]$m.Version -gt [version]$CurrentVersion) {'Available'} else {'Current'});Manifest=$m;ManifestBytes=$manifestBytes;SignatureBytes=$signatureBytes;Url=$assets[$m.Asset];ReleaseUrl=('https://github.com/'+$Config.Repository+'/releases/tag/'+$tag);CurrentVersion=$CurrentVersion}
}
function Assert-DistributionPath([string]$Path,[string]$Root) {
    $base=[IO.Path]::GetFullPath($Root).TrimEnd('\');$full=[IO.Path]::GetFullPath($Path)
    if ($full -ne $base -and -not $full.StartsWith($base+'\',[StringComparison]::OrdinalIgnoreCase)) {throw 'Đường dẫn nằm ngoài thư mục WinTune.'}
    $cursor=$full
    while ($cursor) {
        if ((Test-Path -LiteralPath $cursor) -and (([IO.File]::GetAttributes($cursor) -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {throw 'Không dùng đường dẫn junction/symlink.'}
        $parent=[IO.Path]::GetDirectoryName($cursor);if ($parent -eq $cursor) {break};$cursor=$parent
    }
    return $full
}
function Assert-PackageName([string]$Name) {
    $name=$Name.Replace('\','/')
    if (-not $name -or $name.Length -gt 240 -or $name -match '^/|[\x00-\x1f:]') {throw 'Tên tệp ZIP không an toàn.'}
    foreach ($part in $name.TrimEnd('/').Split('/')) {if (-not $part -or $part -in @('.','..') -or $part -match '[ .]$|[<>"|?*]' -or $part -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)') {throw 'Tên tệp ZIP có traversal hoặc tên dành riêng.'}}
    return $name
}
function Test-PortableIntegrity([string]$Root,[string]$Version) {
    $root=Assert-DistributionPath $Root $Root;$seen=@{}
    foreach ($line in @(Get-Content -LiteralPath (Join-Path $root 'SHA256.txt') -Encoding UTF8)) {
        if ($line -notmatch '^([0-9A-F]{64})  (.+)$') {throw 'Bảng checksum portable không hợp lệ.'}
        $hash=$Matches[1];$name=Assert-PackageName $Matches[2]
        if ($name -ceq 'SHA256.txt' -or $seen.ContainsKey($name)) {throw 'Checksum tự tham chiếu hoặc trùng tên.'}
        $path=Assert-DistributionPath (Join-Path $root $name) $root
        if (-not (Test-DistributionMutableFile $name) -and (-not [IO.File]::Exists($path) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $hash)) {throw ('Tệp thiếu hoặc checksum sai: '+$name)}
        $seen[$name]=$true
    }
    foreach ($file in @(Get-ChildItem -LiteralPath $root -Recurse -File)) {
        if ($file.FullName -ceq (Join-Path $root 'SHA256.txt')) {continue}
        $name=$file.FullName.Substring($root.Length+1).Replace('\','/')
        if (-not $seen.ContainsKey($name) -and -not (Test-DistributionMutableFile $name)) {throw 'Gói chứa tệp ngoài bảng checksum.'}
    }
    foreach ($name in @('WinTune-VI.exe','WinTune-Demo.exe','WinTune.ps1','MainWindow.xaml','features.json','Core.ps1','Tools.Core.ps1','Tools.Worker.ps1','Theme.UI.ps1','Monitor.UI.ps1','version.json','release-config.json','Wintune.Command.exe')) {if (-not $seen.ContainsKey($name)) {throw ('Gói thiếu thành phần bắt buộc: '+$name)}}
    if ((Get-WinTuneVersion $root).Version -cne $Version) {throw 'Phiên bản bên trong ZIP không khớp manifest.'}
}
function Test-DistributionMutableFile([string]$Name) {
    # App/demo/test output is never loaded as startup code. Immutable scripts,
    # XAML, JSON catalogs and executable files still require their exact hashes.
    $name=$Name.Replace('\','/')
    return $name -in @('startup-error.log','launcher-error.log') -or $name.StartsWith('simulation-data/',[StringComparison]::OrdinalIgnoreCase) -or $name.StartsWith('.test-runs/',[StringComparison]::OrdinalIgnoreCase) -or ($name.StartsWith('evidence/',[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetExtension($name) -in @('.log','.png','.json'))
}
function Expand-VerifiedPackage([string]$Zip,[string]$Stage,[string]$Version,$Cancellation=$null) {
    Add-Type -AssemblyName System.IO.Compression,System.IO.Compression.FileSystem
    if (Test-Path -LiteralPath $Stage) {throw 'Thư mục staging phải mới.'}
    $stage=Assert-DistributionPath $Stage ([IO.Path]::GetDirectoryName($Stage));$archive=[IO.Compression.ZipFile]::OpenRead($Zip)
    $seen=@{};$expanded=0L;$prefix='WinTune-VI-v'+$Version+'/'
    try {
        if ($archive.Entries.Count -gt 2500) {throw 'ZIP có quá nhiều mục.'}
        foreach ($entry in $archive.Entries) {
            $name=Assert-PackageName $entry.FullName
            if (-not $name.StartsWith($prefix,[StringComparison]::Ordinal) -or $seen.ContainsKey($name) -or (($entry.ExternalAttributes -shr 16) -band 0xf000) -eq 0xa000 -or ($entry.ExternalAttributes -band 0x400) -ne 0) {throw 'ZIP có đích ngoài gói, trùng tên hoặc symlink.'}
            $seen[$name]=$true;$expanded+=$entry.Length
            if ($expanded -gt 134217728 -or $entry.Length -gt 33554432) {throw 'ZIP vượt dung lượng giải nén cho phép.'}
        }
        $null=New-Item -ItemType Directory -Path $stage
        foreach ($entry in $archive.Entries) {
            Assert-DistributionCancelled $Cancellation;$name=Assert-PackageName $entry.FullName;$dest=Assert-DistributionPath (Join-Path $stage $name) $stage
            if ($name.EndsWith('/')) {$null=New-Item -ItemType Directory -Path $dest -Force;continue}
            $null=New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($dest)) -Force
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$dest,$false)
        }
        $package=Join-Path $stage $prefix.TrimEnd('/');Test-PortableIntegrity $package $Version;return $package
    } finally {$archive.Dispose()}
}
function Write-DistributionAtomic([string]$Path,[string]$Text) {
    $temp=$Path+'.'+[guid]::NewGuid().ToString('N')+'.tmp';[IO.File]::WriteAllText($temp,$Text,(New-Object Text.UTF8Encoding($true)))
    if ([IO.File]::Exists($Path)) {[IO.File]::Replace($temp,$Path,$Path+'.previous')} else {[IO.File]::Move($temp,$Path)}
}
function Enter-WinTuneDistributionLock([string]$Root) {
    $hash=Get-DistributionHash ([Text.Encoding]::UTF8.GetBytes([IO.Path]::GetFullPath($Root).ToLowerInvariant()))
    $mutex=New-Object Threading.Mutex $false,('Local\WinTuneVI-Distribution-'+$hash.Substring(0,16))
    try {$owned=$mutex.WaitOne(0)} catch [Threading.AbandonedMutexException] {$owned=$true}
    if (-not $owned) {$mutex.Dispose();throw 'Một tác vụ WinTune khác đang kích hoạt/đăng ký. Đợi xong rồi thử lại.'}
    return $mutex
}
function Exit-WinTuneDistributionLock($Mutex) {try {$Mutex.ReleaseMutex()} finally {$Mutex.Dispose()}}
function Activate-DistributionPackage([string]$Package,[string]$Root,[string]$Version,[string]$Digest,$Cancellation=$null) {
    $mutex=Enter-WinTuneDistributionLock $Root
    try {return Complete-DistributionActivation $Package $Root $Version $Digest $Cancellation} finally {Exit-WinTuneDistributionLock $mutex}
}
function Complete-DistributionActivation([string]$Package,[string]$Root,[string]$Version,[string]$Digest,$Cancellation=$null) {
    Assert-DistributionCancelled $Cancellation
    $root=Assert-DistributionPath $Root $Root;$null=New-Item -ItemType Directory -Path (Join-Path $root 'apps') -Force
    if (Test-Path -LiteralPath (Join-Path $root 'current.txt')) {
        $current=(Get-Content -LiteralPath (Join-Path $root 'current.txt') -Raw).Trim();$current=Assert-DistributionPath $current (Join-Path $root 'apps')
        if ([version](Get-WinTuneVersion $current).Version -gt [version]$Version) {throw 'Đã có bản mới hơn; không hạ phiên bản hoặc ghi đè current.txt.'}
    }
    $dest=Assert-DistributionPath (Join-Path $root ('apps/v'+$Version+'-'+$Digest.Substring(0,12)+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))) $root
    Test-PortableIntegrity $Package $Version
    Move-Item -LiteralPath $Package -Destination $dest
    # Side-by-side installation: never modify running binaries or v2 journals.
    Write-DistributionAtomic (Join-Path $root 'current.txt') $dest
    $receipt=[pscustomobject]@{Time=(Get-Date).ToString('o');Version=$Version;Digest=$Digest;Path=$dest;Status='Prepared'}
    $warning=''
    try {Add-Content -LiteralPath (Join-Path $root 'distribution-history.jsonl') -Value ($receipt|ConvertTo-Json -Compress) -Encoding UTF8} catch {$warning=' Không ghi được lịch sử phân phối: '+$_.Exception.Message}
    return [pscustomobject]@{Version=$Version;Path=$dest;Status='Prepared';Message=('Đã xác minh và chuẩn bị bản mới. Đóng WinTune rồi mở lại; không tự chạy bản cập nhật.'+$warning);HistoryWarning=$warning}
}
function Install-DistributionUpdate($Info,[string]$Root,[bool]$Confirmed,$Cancellation=$null,$Config=$null) {
    if (-not $Confirmed -or $Info.Status -ne 'Available') {throw 'Chưa xác nhận hoặc không có bản mới; chưa tải ZIP.'}
    Assert-DistributionCancelled $Cancellation
    $m=Read-SignedRelease $Info.ManifestBytes $Info.SignatureBytes $Config ('v'+$Info.Manifest.Version)
    if ($m.SHA256 -cne $Info.Manifest.SHA256 -or $m.Size -ne $Info.Manifest.Size -or $m.Asset -cne $Info.Manifest.Asset -or $m.MinimumBuild -ne $Info.Manifest.MinimumBuild) {throw 'Dữ liệu xem trước bị thay đổi; kiểm tra lại trước khi tải.'}
    $expected='https://github.com/'+$Config.Repository+'/releases/download/v'+$m.Version+'/'+$m.Asset
    if ($Info.Url -cne $expected -or [version]$m.Version -le [version]$Info.CurrentVersion) {throw 'Đích cập nhật bị thay đổi hoặc là bản cũ.'}
    if (-not [Environment]::Is64BitOperatingSystem -or (Get-DistributionBuild) -lt $m.MinimumBuild) {throw 'Bản phát hành không hỗ trợ Windows hiện tại.'}
    $root=Assert-DistributionPath $Root $Root;$stage=Join-Path $root ('staging/'+[guid]::NewGuid().ToString('N'))
    $null=New-Item -ItemType Directory -Path $stage -Force
    $bytes=Get-DistributionBytes $Info.Url 67108864 $Cancellation
    if ($bytes.Length -ne $m.Size -or (Get-DistributionHash $bytes) -ine $m.SHA256) {throw 'Checksum hoặc dung lượng ZIP không khớp manifest đã ký; không chạy.'}
    Assert-DistributionCancelled $Cancellation;$zip=Join-Path $stage 'package.zip';[IO.File]::WriteAllBytes($zip,$bytes);$bytes=$null
    $package=Expand-VerifiedPackage $zip (Join-Path $stage 'unpacked') $m.Version $Cancellation
    return Activate-DistributionPackage $package $root $m.Version $m.SHA256 $Cancellation
}
function Get-DistributionBuild {return [int](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop).CurrentBuild}
function Get-PreparedDistributionVersion([string]$Root,[string]$Fallback) {
    $current=Join-Path $Root 'current.txt'
    if (-not (Test-Path -LiteralPath $current)) {return $Fallback}
    $path=Assert-DistributionPath ((Get-Content -LiteralPath $current -Raw).Trim()) (Join-Path $Root 'apps')
    $version=(Get-WinTuneVersion $path).Version;Test-PortableIntegrity $path $version
    return $(if ([version]$version -gt [version]$Fallback) {$version} else {$Fallback})
}
function Install-LocalDistribution([string]$Source,[string]$Root,[bool]$Confirmed) {
    if (-not $Confirmed) {throw 'Chưa xác nhận cài bản local hoặc đăng ký lệnh.'}
    $v=Get-WinTuneVersion $Source;Test-PortableIntegrity $Source $v.Version
    $root=Assert-DistributionPath $Root $Root
    if (Test-Path -LiteralPath (Join-Path $root 'current.txt')) {
        $current=(Get-Content -LiteralPath (Join-Path $root 'current.txt') -Raw).Trim();$current=Assert-DistributionPath $current (Join-Path $root 'apps')
        if ([version](Get-WinTuneVersion $current).Version -ge [version]$v.Version) {Test-PortableIntegrity $current (Get-WinTuneVersion $current).Version;return [pscustomobject]@{Path=$current;Version=(Get-WinTuneVersion $current).Version;Status='Existing'}}
    }
    if ([IO.Path]::GetFullPath($Source).StartsWith((Join-Path $root 'apps')+'\',[StringComparison]::OrdinalIgnoreCase)) {return [pscustomobject]@{Path=$Source;Version=$v.Version;Status='Existing'}}
    $stage=Join-Path $root ('staging/local-'+[guid]::NewGuid().ToString('N'));$null=New-Item -ItemType Directory -Path $stage -Force
    foreach ($line in Get-Content -LiteralPath (Join-Path $Source 'SHA256.txt') -Encoding UTF8) {
        $name=$line.Substring(66);$dest=Assert-DistributionPath (Join-Path $stage $name) $stage;$null=New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($dest)) -Force
        [IO.File]::Copy((Join-Path $Source $name),$dest,$false)
    }
    [IO.File]::Copy((Join-Path $Source 'SHA256.txt'),(Join-Path $stage 'SHA256.txt'),$false)
    return Activate-DistributionPackage $stage $root $v.Version ((Get-FileHash -LiteralPath (Join-Path $Source 'SHA256.txt')).Hash)
}
