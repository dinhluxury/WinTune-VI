#Requires -Version 5.1
# AUTHOR TOOL: explicitly run outside the project; never run by app/build/tests.
param([Parameter(Mandatory=$true)][string]$Directory)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Security
$dir=[IO.Path]::GetFullPath($Directory)
if ($dir.Equals($PSScriptRoot,[StringComparison]::OrdinalIgnoreCase) -or $dir.StartsWith($PSScriptRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {throw 'Lưu khóa riêng ngoài workspace và Git repository.'}
if (Test-Path -LiteralPath $dir) {throw 'Chọn thư mục khóa mới; không ghi đè.'}
$rsa=New-Object Security.Cryptography.RSACryptoServiceProvider 3072;$rsa.PersistKeyInCsp=$false
$private=$null
try {
    $private=[Text.Encoding]::UTF8.GetBytes($rsa.ToXmlString($true))
    $protected=[Security.Cryptography.ProtectedData]::Protect($private,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
    $null=New-Item -ItemType Directory -Path $dir
    [IO.File]::WriteAllBytes((Join-Path $dir 'private.dpapi'),$protected)
    [IO.File]::WriteAllText((Join-Path $dir 'public.xml'),$rsa.ToXmlString($false))
} finally {if ($null -ne $private) {[Array]::Clear($private,0,$private.Length)};$rsa.Dispose()}
Write-Output 'Đã tạo RSA3072. private.dpapi chỉ giải mã bởi tài khoản này; giữ ngoài repo. public.xml được ghim vào release-config.json.'
