function Initialize-Profiles {
    $data=Get-Content "$PSScriptRoot/profiles.json" -Raw -Encoding UTF8 | ConvertFrom-Json
    $script:Profiles=@($data)
    if (($Profiles.Id -join ',') -ne 'custom,minimal,standard,advanced') {throw 'Danh mục hồ sơ không hợp lệ.'}
    foreach ($p in $Profiles) {foreach ($id in $p.Ids) {if ((Get-Feature $id).Kind -ne 'Registry') {throw 'Hồ sơ không được mở công cụ/gỡ app.'}}}
}
function Get-ProfileSelection([string]$Id) {
    $p=@($Profiles | Where-Object Id -CEQ $Id)
    if ($p.Count -ne 1) {throw 'Không nhận diện hồ sơ.'}
    foreach ($id in $p[0].Ids) {
        $f=Get-Feature $id
        if ($Build -lt $f.MinBuild -or ($f.MaxBuild -gt 0 -and $Build -gt $f.MaxBuild)) {continue}
        # Unreadable current state never qualifies as a prepared change.
        foreach ($c in $f.Changes) {$null=Read-RegistryValue $c}
        $id
    }
}
