#Requires -Version 5.1
# Loopback-only HTTP fixture. Served entry and child are trusted local test code.
# No Internet, app launch, registry, PATH or firewall changes.
$ErrorActionPreference='Stop';$pass=0
function Check($Ok,$Name){if(-not $Ok){throw "PAGES FAILED: $Name"};$script:pass++;Write-Output "PASS PAGES: $Name"}
Add-Type @'
using System;using System.IO;using System.Net;using System.Net.Sockets;using System.Text;using System.Threading.Tasks;
public sealed class WinTunePagesFixture:IDisposable {
 readonly TcpListener listener;readonly Task worker;readonly byte[] body;public readonly int Port;public volatile int Requests;
 public WinTunePagesFixture(byte[] data){body=data;listener=new TcpListener(IPAddress.Loopback,0);listener.Start();Port=((IPEndPoint)listener.LocalEndpoint).Port;worker=Task.Run((Action)Serve);}
 void Serve(){try{while(true){using(var client=listener.AcceptTcpClient()){using(var stream=client.GetStream()){
 var reader=new StreamReader(stream,Encoding.ASCII,false,1024,true);string first=reader.ReadLine();string line;while(!String.IsNullOrEmpty(line=reader.ReadLine())){}
 bool redirect=first!=null && first.StartsWith("GET /WinTune-VI HTTP/");Requests++;
 byte[] header=Encoding.ASCII.GetBytes(redirect?"HTTP/1.1 301 Moved Permanently\r\nLocation: /WinTune-VI/\r\nContent-Length: 0\r\nConnection: close\r\n\r\n":"HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: "+body.Length+"\r\nConnection: close\r\n\r\n");
 stream.Write(header,0,header.Length);if(!redirect)stream.Write(body,0,body.Length);stream.Flush();
 }}}}catch(SocketException){}catch(ObjectDisposedException){}}
 public void Dispose(){listener.Stop();try{worker.Wait(1000);}catch(AggregateException){} }
}
'@
$test=Join-Path $PSScriptRoot ('.test-runs/pages-'+[guid]::NewGuid().ToString('N').Substring(0,8));$null=New-Item -ItemType Directory -Path $test
$child=Join-Path $test 'child.ps1';$marker=Join-Path $test 'child.json'
[IO.File]::WriteAllText($child,'param([switch]$Confirmed,[switch]$CheckOnly) [pscustomobject]@{Confirmed=[bool]$Confirmed;CheckOnly=[bool]$CheckOnly}|ConvertTo-Json|Set-Content -LiteralPath $env:WINTUNE_PAGES_MARKER -Encoding UTF8',[Text.UTF8Encoding]::new($true))
$hash=(Get-FileHash $child).Hash
$text=[IO.File]::ReadAllText("$PSScriptRoot/QuickLauncher.template.ps1").Replace('__BOOTSTRAP_URL__','https://github.com/fixture/WinTune/releases/download/v0.15.2/WinTune-Online.ps1').Replace('__BOOTSTRAP_SHA256__',$hash)
$bytes=[Text.Encoding]::UTF8.GetBytes($text)
$server=New-Object WinTunePagesFixture(,$bytes)
$originalTemp=$env:TEMP;$originalMarker=$env:WINTUNE_PAGES_MARKER
function Invoke-WebRequest {[CmdletBinding()]param($Uri,$OutFile,[switch]$UseBasicParsing,$TimeoutSec);[IO.File]::Copy($child,$OutFile,$false)}
try {
    $env:TEMP=$test;$env:WINTUNE_PAGES_MARKER=$marker
    $url='http://127.0.0.1:'+$server.Port+'/WinTune-VI'
    $body=Invoke-RestMethod -Uri $url -TimeoutSec 5
    Check ($body -is [string] -and $body.Contains('param([switch]$CheckOnly)') -and $body.Contains($hash)) 'HTML MIME type returns the PowerShell entry as text'
    Check ($server.Requests -ge 2) 'URL without trailing slash follows the redirect to the index'
    Invoke-Expression $body
    $record=Get-Content -LiteralPath $marker -Raw -Encoding UTF8|ConvertFrom-Json
    Check ($record.Confirmed -and -not $record.CheckOnly) 'Hosted body executes the entry and reaches only the harmless confirmed child'
    Check (@(Get-ChildItem -LiteralPath $test -Filter 'WinTune-*.ps1').Count -eq 0) 'Hosted launch cleans its bootstrap temp file'
} finally {$server.Dispose();$env:TEMP=$originalTemp;$env:WINTUNE_PAGES_MARKER=$originalMarker}
Check ($env:TEMP -ceq $originalTemp -and $env:WINTUNE_PAGES_MARKER -ceq $originalMarker) 'Fixture restores process environment and closes loopback listener'
Write-Output "PAGES SERVING TESTS PASSED: $pass; real loopback HTTP/redirect/text-html, mocked second HTTP, harmless child only."
