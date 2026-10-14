# WinTune online entry. The short command trusts this file from the official repository.
# The second stage is pinned by SHA256; it checks the signed release and all resources.
param([switch]$CheckOnly)
& {
    param([bool]$OnlyCheck)
    $ErrorActionPreference='Stop'
    $file=Join-Path $env:TEMP ('WinTune-'+[guid]::NewGuid().ToString('N')+'.ps1')
    try {
        Invoke-WebRequest -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop -Uri 'https://github.com/dinhluxury/WinTune-VI/releases/download/v0.15.2/WinTune-Online.ps1' -OutFile $file
        if ((Get-FileHash -LiteralPath $file -Algorithm SHA256 -ErrorAction Stop).Hash -cne '8C63F1439F5415A5AB361754F1B79F647CC6F2DFA09C115D0840CD68388288E4') {throw 'Checksum launcher không khớp; chưa mở WinTune.'}
        $hostExe=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $mode=$(if ($OnlyCheck) {'-CheckOnly'} else {'-Confirmed'})
        & $hostExe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File $file $mode
        if ($LASTEXITCODE -ne 0) {throw ('Không mở được WinTune (mã '+$LASTEXITCODE+'). Xem thông báo phía trên.')}
    } finally {
        try {if ([IO.File]::Exists($file)) {[IO.File]::Delete($file)}} catch {Write-Warning 'Chưa xóa được file launcher tạm.'}
    }
} ([bool]$CheckOnly)
