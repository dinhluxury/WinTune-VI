# WinTune online entry. The short command trusts this file from the official repository.
# The second stage is pinned by SHA256; it checks the signed release and all resources.
param([switch]$CheckOnly)
& {
    param([bool]$OnlyCheck)
    $ErrorActionPreference='Stop'
    $file=Join-Path $env:TEMP ('WinTune-'+[guid]::NewGuid().ToString('N')+'.ps1')
    try {
        Invoke-WebRequest -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop -Uri '__BOOTSTRAP_URL__' -OutFile $file
        if ((Get-FileHash -LiteralPath $file -Algorithm SHA256 -ErrorAction Stop).Hash -cne '__BOOTSTRAP_SHA256__') {throw 'Checksum launcher không khớp; chưa mở WinTune.'}
        $hostExe=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $mode=$(if ($OnlyCheck) {'-CheckOnly'} else {'-Confirmed'})
        & $hostExe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File $file $mode
        if ($LASTEXITCODE -ne 0) {throw ('Không mở được WinTune (mã '+$LASTEXITCODE+'). Xem thông báo phía trên.')}
    } finally {
        try {if ([IO.File]::Exists($file)) {[IO.File]::Delete($file)}} catch {Write-Warning 'Chưa xóa được file launcher tạm.'}
    }
} ([bool]$CheckOnly)
