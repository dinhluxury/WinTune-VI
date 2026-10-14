# Application-owned lifecycle smoke test; not external desktop automation.
if (-not $script:IsSimulation -and -not $script:WriteBlocked) { throw 'GUI probe requires simulated or blocked writes.' }
$null=New-Item -ItemType Directory -Path (Join-Path $PSScriptRoot 'evidence') -Force
$script:ProbeRendered=$false
$script:ProbeTimer=New-Object Windows.Threading.DispatcherTimer
$script:ProbeTimer.Interval=[TimeSpan]::FromSeconds(2)
$script:ProbeTimer.Add_Tick({ $script:ProbeTimer.Stop(); $script:Window.Close() })
$script:Window.Add_ContentRendered({
    if ($script:ProbeRendered) { return }
    $source=[Windows.PresentationSource]::FromVisual($script:Window)
    $record=[pscustomobject]@{
        Title=$script:Window.Title
        Visible=$script:Window.IsVisible
        Features=$script:List.Items.Count
        Selected=$script:Selected.Count
        SimulatedWrites=$script:SimWriteCount
        RealWritesBlocked=$script:WriteBlocked
        Width=$script:Window.ActualWidth
        Height=$script:Window.ActualHeight
        DpiScale=$source.CompositionTarget.TransformToDevice.M11
        PreviewEnabled=$script:Window.FindName('Preview').IsEnabled
        Scope='Application lifecycle and layout only; no external screen observation'
    }
    $record | ConvertTo-Json | Set-Content "$PSScriptRoot/evidence/gui-lifecycle.json" -Encoding UTF8
    $script:ProbeRendered=$true
    $script:ProbeDialog=New-TextDialog 'Kiểm tra hộp thoại WPF' 'Đây là kiểm tra dựng hộp thoại. Không áp dụng thay đổi.' $false
    $script:ModalRendered=$false
    $script:ModalTimer=New-Object Windows.Threading.DispatcherTimer
    $script:ModalTimer.Interval=[TimeSpan]::FromMilliseconds(500)
    $script:ModalTimer.Add_Tick({ $script:ModalTimer.Stop(); $script:ProbeDialog.DialogResult=$false })
    $script:ProbeDialog.Add_ContentRendered({ $script:ModalRendered=$true; $script:ModalTimer.Start() })
    $null=$script:ProbeDialog.ShowDialog()
    if (-not $script:ModalRendered) { throw 'Native WPF dialog did not render.' }
    $record | Add-Member ModalRendered $script:ModalRendered
    $record | Add-Member ModalOwnerMatches ($script:ProbeDialog.Owner -eq $script:Window)
    $record | ConvertTo-Json | Set-Content "$PSScriptRoot/evidence/gui-lifecycle.json" -Encoding UTF8
    $script:ProbeTimer.Start()
})
$null=$script:Window.ShowDialog()
if (-not $script:ProbeRendered -or $script:SimWriteCount -ne 0 -or $script:Selected.Count -ne 0) { throw 'GUI lifecycle probe failed.' }
Write-Output 'GUI LIFECYCLE PASSED: main window and owned dialog rendered and closed, no selections and no writes. External interaction remains unverified.'
