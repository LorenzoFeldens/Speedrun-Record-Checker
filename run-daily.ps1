# Chamado a cada 5 minutos pela tarefa "Speedrun Record Checker" do Agendador de Tarefas do Windows.
# O horário de verdade vem do asset ExecuteTime, lido pelo Main.xaml. Este script só evita abrir o robô
# quando não há nada a fazer:
#   - a verificação de hoje já foi feita (last-check.txt é de hoje);
#   - ainda não chegou o horário salvo pelo robô na última execução (execute-time.txt);
#   - houve uma tentativa há menos de 60 minutos (evita repetir e-mails de erro a cada 5 minutos).
# A saída de cada execução vai para %LOCALAPPDATA%\SpeedrunRecordChecker\logs.
$ErrorActionPreference = 'Stop'
$projectDir = $PSScriptRoot
$stateDir = Join-Path $env:LOCALAPPDATA 'SpeedrunRecordChecker'
$logDir = Join-Path $stateDir 'logs'
$lastCheckFile = Join-Path $stateDir 'last-check.txt'
$executeTimeFile = Join-Path $stateDir 'execute-time.txt'
$lastAttemptFile = Join-Path $stateDir 'last-attempt.txt'
$now = Get-Date
$inv = [Globalization.CultureInfo]::InvariantCulture

if (Test-Path $lastCheckFile) {
    $lastCheck = [datetime]::MinValue
    $styles = [Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal
    if ([datetime]::TryParse((Get-Content $lastCheckFile -Raw).Trim(), $inv, $styles, [ref]$lastCheck) -and
        $lastCheck.ToLocalTime().Date -eq $now.Date) { exit 0 }
}

if (Test-Path $executeTimeFile) {
    $executeAt = [timespan]::Zero
    if ([timespan]::TryParse((Get-Content $executeTimeFile -Raw).Trim(), $inv, [ref]$executeAt) -and
        $now.TimeOfDay -lt $executeAt) { exit 0 }
}

if (Test-Path $lastAttemptFile) {
    $lastAttempt = [datetime]::MinValue
    if ([datetime]::TryParse((Get-Content $lastAttemptFile -Raw).Trim(), $inv, [Globalization.DateTimeStyles]::None, [ref]$lastAttempt) -and
        ($now - $lastAttempt).TotalMinutes -lt 60) { exit 0 }
}

New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$now.ToString('s', $inv) | Set-Content -Path $lastAttemptFile -Encoding ascii
$log = Join-Path $logDir ("run-{0:yyyy-MM-dd_HHmm}.txt" -f $now)

& "$env:APPDATA\npm\uip.ps1" rpa run --file-path 'Main.xaml' --project-dir $projectDir --output json *>&1 |
    Out-File -FilePath $log -Encoding utf8

# Mantém só os 30 logs mais recentes.
Get-ChildItem $logDir -Filter 'run-*.txt' | Sort-Object Name -Descending | Select-Object -Skip 30 | Remove-Item -Force
