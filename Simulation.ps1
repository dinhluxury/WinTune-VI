# Isolated provider: no calls to real Registry write APIs.
$script:Memory=@{}
$script:SimWriteCount=0
$script:SimStateFile=$null
function Get-SimKey($c) { $prefix=if ($c.PSObject.Properties['Hive'] -and $c.Hive -eq 'HKLM') {'HKLM\'} else {''};return ($prefix+"$($c.Path)\$($c.Name)").ToLowerInvariant() }
function Test-RegistryWriteAccess($Change) { return [pscustomobject]@{Allowed=$true;Reason=''} }
function Read-RegistryValue($Change) {
    $key=Get-SimKey $Change
    if ($script:Memory.ContainsKey($key)) { return [pscustomobject]@{Exists=$true;KeyExisted=$true;Value=$script:Memory[$key]} }
    return [pscustomobject]@{Exists=$false;KeyExisted=$false;Value=$(if ($Change.Type -eq 'String') {''} else {0})}
}
function Set-RegistryValue($Change,[bool]$Exists,$Value) {
    $script:SimWriteCount++
    $key=Get-SimKey $Change
    if ($Exists) { $script:Memory[$key]=$Value } else { $script:Memory.Remove($key) }
    if ($script:SimStateFile) { Save-Journal $script:Memory $script:SimStateFile }
}
function Enable-SimulationStorage {
    $script:SimStateFile=Join-Path $script:DataRoot 'virtual-state.dat'
    if (Test-Path -LiteralPath $script:SimStateFile) {
        $state=Get-Content -LiteralPath $script:SimStateFile -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($property in $state.PSObject.Properties) {
            if ($property.Value -isnot [int] -and $property.Value -isnot [long] -and $property.Value -isnot [string]) { throw 'Dữ liệu mô phỏng không hợp lệ.' }
            $script:Memory[$property.Name]=$property.Value
        }
    }
}
