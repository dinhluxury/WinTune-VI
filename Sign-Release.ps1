#Requires -Version 5.1
# AUTHOR TOOL: only signs an existing local manifest, never publishes.
param([Parameter(Mandatory=$true)][string]$Manifest,[Parameter(Mandatory=$true)][string]$PrivateKey)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Security
. "$PSScriptRoot/Distribution.Core.ps1"
$cfg=Get-ReleaseConfig $PSScriptRoot;$bytes=[IO.File]::ReadAllBytes($Manifest)
$private=[Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($PrivateKey),$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
$rsa=New-Object Security.Cryptography.RSACryptoServiceProvider;$rsa.PersistKeyInCsp=$false
try {
    $rsa.FromXmlString([Text.Encoding]::UTF8.GetString($private))
    if ($rsa.ToXmlString($false) -cne $cfg.PublicKeyXml) {throw 'Khóa ký không khớp khóa công khai ghim; không ký.'}
    $signature=$rsa.SignData($bytes,[Security.Cryptography.CryptoConfig]::MapNameToOID('SHA256'))
    $m=([Text.Encoding]::UTF8.GetString($bytes)) | ConvertFrom-Json
    $null=Read-SignedRelease $bytes $signature $cfg ('v'+$m.Version)
    $zip=Join-Path ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Manifest))) $m.Asset
    if ((Get-FileHash -LiteralPath $zip).Hash -ine $m.SHA256 -or (Get-Item -LiteralPath $zip).Length -ne $m.Size) {throw 'ZIP không khớp manifest; không ký.'}
    [IO.File]::WriteAllBytes(([IO.Path]::ChangeExtension($Manifest,'.sig')),$signature)
} finally {$rsa.Dispose();[Array]::Clear($private,0,$private.Length)}
Write-Output 'Đã ký release.sig; chưa upload/phát hành. Không thêm private.dpapi vào release.'
