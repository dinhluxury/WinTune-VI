#Requires -Version 5.1
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Care.Core.ps1"
$pass=0
function Check([bool]$Ok,[string]$Name){if(-not $Ok){throw ('CARE TEST FAILED: '+$Name)};$script:pass++}
function Fixture([string]$Id,[int]$Code,[string]$Output){[pscustomobject]@{Id=$Id;Mode='Native';Status='Completed';Message='fixture';Result=[pscustomobject]@{ExitCode=$Code;Output=$Output}}}
$steps=@(Get-CareRepairSteps)
Check (($steps.Id -join ',') -ceq 'dismrestore,sfc,diskcheck') 'Keep only two repair steps in the documented order and one optional read-only disk check'
Check (@($steps|Where-Object {-not $_.When -or -not $_.Action -or -not $_.Note -or -not $_.Button}).Count -eq 0) 'Every action explains when, what happens and the practical effects'
Check ($steps[2].Action.Contains('chỉ đọc') -and $steps[0].Note.Contains('Internet')) 'Disk and download requirements are explicit'
$r=Get-CareRepairResult (Fixture dismrestore 0 'The restore operation completed successfully.')
Check ($r.Title.Contains('hoàn tất bước 1') -and $r.Next.Contains('bước 2')) 'Successful first step explains the next action'
$r=Get-CareRepairResult (Fixture sfc 0 'Windows Resource Protection did not find any integrity violations.')
Check ($r.Title.Contains('Không tìm thấy') -and $r.Next.Contains('không xác nhận toàn bộ máy')) 'Clean SFC does not claim that all problems are fixed'
$r=Get-CareRepairResult (Fixture sfc 0 'Windows Resource Protection found corrupt files and successfully repaired them.')
Check ($r.Title.Contains('Đã sửa') -and $r.Next.Contains('Mở lại ứng dụng')) 'Repaired SFC asks the user to check the actual symptom'
$r=Get-CareRepairResult (Fixture sfc 0 'Windows Resource Protection found corrupt files but was unable to fix some of them.')
Check ($r.Tone -eq 'Warning' -and $r.Next.Contains('bước 1')) 'Partial repair remains visible and actionable'
$r=Get-CareRepairResult (Fixture dismrestore 5 'Access denied')
Check ($r.Title -eq 'Chưa hoàn tất' -and $r.Tone -eq 'Warning') 'Nonzero failure never appears as repaired'
$r=Get-CareRepairResult (Fixture sfc 0 'localized or unknown output')
Check ($r.Title.Contains('cần đọc') -and $r.Next.Contains('Không cần chạy lặp lại')) 'Unknown localized output stays inconclusive without encouraging repeated repairs'
$r=Get-CareRepairResult (Fixture dismrestore 3010 'fixture')
Check ($r.Title.Contains('khởi động lại') -and $r.Next.Contains('tự khởi động lại')) 'Restart-required is distinct from a completed repair'
$r=Get-CareRepairResult (Fixture diskcheck 0 'fixture')
Check ($r.Body.Contains('mã 0') -and $r.Next.Contains('không chứng minh phần cứng')) 'Read-only disk result explains its limits'
$fixture=Fixture sfc 0 'successfully repaired';$fixture.Mode='Simulation';$r=Get-CareRepairResult $fixture
Check ($r.Title.Contains('mô phỏng') -and $r.Body.Contains('chưa')) 'Simulated repairs are never shown as Windows repairs'
$r=Get-CareRepairResult ([pscustomobject]@{Status='Failed';Message='Worker did not start'})
Check ($r.Title -eq 'Chưa hoàn tất' -and $r.Body.Contains('did not start')) 'Missing child-process results remain a failure'
Write-Output "CARE CORE TESTS PASSED: $pass; result fixtures only, no Windows changes."
