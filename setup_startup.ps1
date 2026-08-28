# 以管理员身份运行此脚本，创建开机后每 10 分钟执行一次的计划任务
# 运行方式：右键 PowerShell -> 以管理员身份运行，然后执行：
#   & "E:\CET-4 App\setup_startup.ps1"

$TaskName = "XfyunChatAutoSend"
$ScriptPath = "E:\CET-4 App\chat_automation.py"
$PythonPath = (Get-Command python -ErrorAction SilentlyContinue).Source

if (-not $PythonPath) {
    Write-Error "未找到 python，请先安装 Python 并添加到环境变量 PATH"
    exit 1
}

$Action = New-ScheduledTaskAction -Execute $PythonPath -Argument "`"$ScriptPath`""

# 登录时触发，之后每 10 分钟重复一次
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Trigger.RepetitionInterval = (New-TimeSpan -Minutes 10)
$Trigger.RepetitionDuration = (New-TimeSpan -Days 365)

$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$Principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive

try {
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal -Force
    Write-Host "计划任务 '$TaskName' 创建成功，登录后每 10 分钟运行一次。" -ForegroundColor Green
} catch {
    Write-Error "创建计划任务失败: $_"
}
