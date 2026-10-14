$ErrorActionPreference='Stop'
. "$PSScriptRoot/Core.ps1"
$testParent=Join-Path $PSScriptRoot '.test-runs'
$root=Join-Path $testParent ('core-'+[guid]::NewGuid().ToString('N'))
Initialize-WinTune "$PSScriptRoot/features.json" $root 'test-user' 26100
$script:Memory=@{}
$script:FailName=''
function Test-RegistryWriteAccess($Change) { return [pscustomobject]@{Allowed=$true;Reason=''} }
function Key($c) {return "$($c.Path)\$($c.Name)"}
function Read-RegistryValue($Change) {
    $k=Key $Change
    if ($script:Memory.ContainsKey($k)) {return [pscustomobject]@{Exists=$true;Value=[int]$script:Memory[$k]}}
    return [pscustomobject]@{Exists=$false;Value=0}
}
function Set-RegistryValue($Change,[bool]$Exists,[int]$Value) {
    if ($Change.Name -eq $script:FailName) {throw 'Injected write failure'}
    $k=Key $Change
    if ($Exists) {$script:Memory[$k]=$Value} else {$script:Memory.Remove($k)}
}
function Assert([bool]$Condition,[string]$Description) {if(-not $Condition){throw "FAILED: $Description"};Write-Output "PASS: $Description"}
function Expect-Failure([scriptblock]$Action,[string]$Description) {
    $threw=$false
    try {& $Action | Out-Null} catch {$threw=$true}
    Assert $threw $Description
}
try {
    $rows=@(New-ChangePlan @('ads','dvr'))
    Assert ($rows.Count -eq 3) 'Plan contains only selected registry changes'
    Assert ($script:Memory.Count -eq 0) 'Preview does not mutate registry'
    $null=Invoke-ChangePlan $rows
    Assert ((Get-LatestJournal).Journal.Status -eq 'Applied') 'Successful batch journal persisted'
    Assert ($script:Memory.Count -eq 3) 'All selected values applied'
    Assert (@(New-ChangePlan @('ads','dvr')).Count -eq 0) 'Already-applied settings are no-ops'
    $null=Undo-LatestJournal
    Assert ($script:Memory.Count -eq 0) 'Undo restores missing values by removal'
    Assert ($null -eq (Get-LatestJournal)) 'Undone batch leaves active history'

    $ads=(Get-Feature 'ads').Changes[0]
    $script:Memory[(Key $ads)]=1
    $rows=@(New-ChangePlan @('ads'))
    $script:Memory[(Key $ads)]=2
    Expect-Failure {Invoke-ChangePlan $rows} 'Reject stale preview before first write'
    $script:Memory[(Key $ads)]=1
    $null=Invoke-ChangePlan @(New-ChangePlan @('ads'))
    $null=Invoke-ChangePlan @(New-ChangePlan @('extensions'))
    $null=Undo-LatestJournal
    Assert ($script:Memory[(Key $ads)] -eq 0) 'Undo latest batch retains preceding batch'
    $script:Memory[(Key $ads)]=2
    Expect-Failure {Undo-LatestJournal} 'External modification blocks rollback'
    Assert ($script:Memory[(Key $ads)] -eq 2) 'Conflicting external value is not overwritten'
    $script:Memory[(Key $ads)]=0
    $null=Undo-LatestJournal
    Assert ($script:Memory[(Key $ads)] -eq 1) 'Undo restores exact prior DWORD'

    $script:FailName='AppCaptureEnabled'
    Expect-Failure {Invoke-ChangePlan @(New-ChangePlan @('dvr'))} 'Simulated mid-batch write failure'
    Assert ((Get-LatestJournal).Journal.Status -eq 'Pending') 'Incomplete batch keeps recoverable journal'
    Expect-Failure {New-ChangePlan @('ads')} 'Pending batch blocks new writes'
    $script:FailName=''
    $null=Undo-LatestJournal
    Assert (-not (Read-RegistryValue (Get-Feature 'dvr').Changes[0]).Exists) 'Rollback recovers partial batch'

    $script:Build=19045
    Expect-Failure {New-ChangePlan @('endtask')} 'Unsupported build rejected'
    $script:Build=26100
    $null=Invoke-ChangePlan @(New-ChangePlan @('ads'))
    $latest=Get-LatestJournal
    $latest.Journal.Rows[0].Feature='unknown'
    Save-Journal $latest.Journal $latest.Path
    Expect-Failure {Undo-LatestJournal} 'Tampered backup cannot select arbitrary targets'
    Write-Output 'ALL CORE TESTS PASSED (in-memory registry; not Windows integration tests).'
} finally {
    $absolute=[IO.Path]::GetFullPath($root)
    if (-not $absolute.StartsWith([IO.Path]::GetFullPath($testParent)+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe test cleanup path.' }
    Remove-Item -LiteralPath $absolute -Recurse -Force
}
