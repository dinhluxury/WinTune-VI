#Requires -Version 5.1
# Native Microsoft hosts and harmless local fixtures; no installed app/PATH writes.
$ErrorActionPreference='Stop';$pass=0
function Check($Ok,$Name) {if(-not $Ok){throw "SOURCE COMMAND FAILED: $Name"};$script:pass++;Write-Output "PASS SOURCE COMMAND: $Name"}
$test=Join-Path $PSScriptRoot ('.test-runs/Lệnh mở tiếng Việt '+[guid]::NewGuid().ToString('N').Substring(0,8));$install=Join-Path $test 'install';$folder=Join-Path $install 'command';$app=Join-Path $install 'apps/v0.15.1-fixture'
$null=New-Item -ItemType Directory -Path $folder,$app
Copy-Item -LiteralPath "$PSScriptRoot/CommandRouter.ps1" -Destination $folder
Copy-Item -LiteralPath "$PSScriptRoot/Wintune.Registered.cmd" -Destination (Join-Path $folder 'wintune.cmd')
Copy-Item -LiteralPath "$PSScriptRoot/Distribution.Core.ps1" -Destination $app
foreach($name in @('WinTune-VI.exe','WinTune-Demo.exe','MainWindow.xaml','features.json','Core.ps1','Tools.Core.ps1','Tools.Worker.ps1','Theme.UI.ps1','Monitor.UI.ps1','release-config.json','Wintune.Command.exe')){[IO.File]::WriteAllText((Join-Path $app $name),'fixture; never executed')}
[IO.File]::WriteAllText((Join-Path $app 'version.json'),'{"Schema":1,"Version":"0.15.1","MinimumBuild":22000,"Architecture":"x64"}')
$stub=@'
param([switch]$Simulation,[switch]$Updates,[switch]$GuiProbe)
$null=New-Item -ItemType Directory -Path (Join-Path $PSScriptRoot 'evidence') -Force
[pscustomobject]@{Simulation=[bool]$Simulation;Updates=[bool]$Updates;GuiProbe=[bool]$GuiProbe;Apartment=[Threading.Thread]::CurrentThread.ApartmentState.ToString()}|ConvertTo-Json|Set-Content (Join-Path $PSScriptRoot 'evidence/child.json') -Encoding UTF8
'@
[IO.File]::WriteAllText((Join-Path $app 'WinTune.ps1'),$stub,[Text.UTF8Encoding]::new($true))
@(Get-ChildItem -LiteralPath $app -File|ForEach-Object {(Get-FileHash $_.FullName).Hash+'  '+$_.Name})|Set-Content (Join-Path $app 'SHA256.txt') -Encoding UTF8
$pointer=Join-Path $install 'current.txt';[IO.File]::WriteAllText($pointer,$app)
$ps=Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe';$router=Join-Path $folder 'CommandRouter.ps1';$marker=Join-Path $app 'evidence/child.json'
function Run-Router([string]$Mode,[string]$Extra='') {
    $ErrorActionPreference='Continue'
    $arguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$router,'-Mode',$Mode)
    if($Extra){$arguments+=@('-Extra',$Extra)}
    $output=& $ps @arguments 2>&1
    return [pscustomobject]@{Code=$LASTEXITCODE;Text=($output|Out-String).Trim()}
}
function Wait-Marker {
    for($i=0;$i -lt 60 -and -not(Test-Path $marker);$i++){Start-Sleep -Milliseconds 100}
    if(-not(Test-Path $marker)){throw 'Child fixture did not finish.'}
    return Get-Content $marker -Raw|ConvertFrom-Json
}
$result=Run-Router resolve;if($result.Code -ne 0){throw $result.Text};Check ($result.Text -ceq $app -and -not(Test-Path $marker)) 'Resolve handles Unicode/spaced paths and launches no app'
foreach($mode in @('app','demo','update','probe')){
    if(Test-Path $marker){[IO.File]::Delete($marker)}
    $result=Run-Router $mode;Check ($result.Code -eq 0) "Microsoft PowerShell source route succeeds: $mode"
    $record=Wait-Marker
    Check ($record.Apartment -eq 'STA' -and $record.Simulation -eq ($mode -eq 'demo') -and $record.Updates -eq ($mode -eq 'update') -and $record.GuiProbe -eq ($mode -eq 'probe')) "Only fixed allowed switches reach the child: $mode"
}
[IO.File]::Delete($marker)
$result=Run-Router 'app;Write-Output injected';Check ($result.Code -ne 0 -and -not(Test-Path $marker)) 'Arguments are validated as data, never evaluated as code'
$result=Run-Router app extra;Check ($result.Code -ne 0 -and -not(Test-Path $marker)) 'Extra arguments are refused'
[IO.File]::WriteAllText($pointer,$test);$result=Run-Router probe;Check ($result.Code -ne 0 -and -not(Test-Path $marker)) 'Pointer outside apps is rejected before any source execution';[IO.File]::WriteAllText($pointer,$app)
$entry=Join-Path $app 'WinTune.ps1';[IO.File]::WriteAllText($entry,'throw "changed"');$result=Run-Router probe;Check ($result.Code -ne 0 -and -not(Test-Path $marker)) 'Changed entry script cannot be executed';[IO.File]::WriteAllText($entry,$stub,[Text.UTF8Encoding]::new($true))
$savedPath=$env:PATH
try {
    $env:PATH=$folder+';'+$savedPath
    Push-Location -LiteralPath $test
    $out=& $env:ComSpec /d /c 'wintune resolve' 2>&1
    Check ($LASTEXITCODE -eq 0 -and ($out|Out-String).Trim() -ceq $app) 'CMD finds registered wintune through process-only PATH without an EXE'
    $out=& $ps -NoProfile -Command 'wintune resolve' 2>&1
    Check ($LASTEXITCODE -eq 0 -and ($out|Out-String).Trim() -ceq $app) 'PowerShell finds registered wintune through process-only PATH'
    $process=Start-Process -FilePath 'wintune' -ArgumentList 'probe' -WorkingDirectory $test -WindowStyle Hidden -Wait -PassThru
    Check ($process.ExitCode -eq 0 -and (Test-Path $marker)) 'Windows ShellExecute resolves wintune without an extension using PATH'
} finally {Pop-Location;$env:PATH=$savedPath}
Check ($env:PATH -ceq $savedPath) 'Fixture leaves parent process PATH unchanged; no User/Machine PATH changes'
Write-Output "SOURCE COMMAND TESTS PASSED: $pass; Microsoft host/CLI/ShellExecute fixtures only, no native registration or Windows changes."
