# Fixed shortcut to the existing current-user Appx removal engine.
function New-CopilotRemovalPreview {
    $apps=@(Get-AllAppInventory | Where-Object Name -CEQ 'Microsoft.Copilot')
    if (-not $apps.Count) {return [pscustomobject]@{Found=$false;Rows=@();Message='Không tìm thấy ứng dụng Microsoft Copilot dạng Appx/MSIX của tài khoản này; không có gói phù hợp để gỡ.'}}
    if ($apps.Count -ne 1) {throw 'Có nhiều phiên bản Copilot cùng lúc. Chưa tự gỡ để tránh xử lý nhầm phiên bản; đọc lại sau khi Windows hoàn tất cập nhật ứng dụng.'}
    if ($apps[0].PublisherId -cne '8wekyb3d8bbwe') {throw 'Gói mang tên Copilot không khớp nhà phát hành Microsoft đã xác minh; chưa gỡ.'}
    Assert-ActionItem $apps[0]
    $rows=@(New-ActionPlan 'Appx' @($apps[0].Id))
    return [pscustomobject]@{Found=$true;Rows=$rows;Message='Đã tìm thấy ứng dụng Microsoft Copilot của tài khoản hiện tại. Chưa gỡ.'}
}
