function Get-SourceLabel([string]$Url) {
    $uri=[Uri]$Url
    if ($uri.Host -eq 'github.com') {if ($uri.AbsolutePath -match '/Raphire/Win11Debloat/') {return 'Win11Debloat'};if ($uri.AbsolutePath -match '/ChrisTitusTech/winutil/') {return 'WinUtil'};return 'GitHub'}
    if ($uri.Host -like '*.microsoft.com' -or $uri.Host -eq 'microsoft.com') {return 'Microsoft'}
    return $uri.Host
}
function Open-SourceUrl([string]$Url) {
    try {$uri=[Uri]$Url;if ($uri.Scheme -ne 'https') {throw 'Chỉ mở nguồn HTTPS.'};if ($script:IsSimulation) {Message 'Mô phỏng: không mở trang web thật.'} else {Start-Process $uri.AbsoluteUri}} catch {Message $_.Exception.Message}
}
function Set-SourceLink($Block,[string]$Url) {
    $Block.Inlines.Clear();$Block.Inlines.Add([Windows.Documents.Run]::new('Tài liệu: '))
    $link=[Windows.Documents.Hyperlink]::new([Windows.Documents.Run]::new((Get-SourceLabel $Url)));$link.NavigateUri=[Uri]$Url
    Set-ThemeResource $link Foreground Accent
    $link.Add_RequestNavigate({param($sender,$eventArgs) Open-SourceUrl $sender.NavigateUri.AbsoluteUri;$eventArgs.Handled=$true})
    $Block.Inlines.Add($link)
}
