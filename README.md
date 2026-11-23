# Speedrun Record Checker

Robô UiPath (VB.NET, Windows) que verifica uma vez por dia no speedrun.com se surgiram novos **recordes
mundiais** nos jogos das séries configuradas (hoje *Resident Evil* e *Dino Crisis*) e envia um e-mail com
cada recorde novo e o link do vídeo.

## Como funciona

1. Lê os assets `SendTo`, `ExecuteTime` e `GameList` da pasta **SpeedrunRecordChecker** do Orchestrator.
2. **Já é hora?** Se ainda não chegou o horário do `ExecuteTime` (horário do computador) ou se a verificação
   de hoje já foi feita, termina sem consultar nada.
3. Para cada nome do `GameList`, procura a série no speedrun.com e pega todos os jogos dela. Se não achar
   uma série com esse nome, procura um jogo com esse nome.
4. Para cada jogo, lê as runs verificadas desde a última verificação
   (`/runs?status=verified&orderby=verify-date`). A primeira execução olha as últimas 24 horas.
5. Para cada uma dessas runs, abre o leaderboard dela (mesma categoria, nível e subcategorias) e só fica
   com as que estão em **1º lugar**. Entram recordes de jogo completo e de níveis individuais.
6. Se houver recordes novos, envia um e-mail em HTML pela conexão do Gmail no Integration Service, com jogo,
   categoria, tempo, jogador, datas, link do vídeo, página da run e leaderboard.
7. Grava o horário da verificação. Se algo falhar, envia um e-mail com o erro e mantém o horário anterior,
   para que a próxima execução cubra o período perdido.

## Configuração no Orchestrator

Assets na pasta **SpeedrunRecordChecker**:

| Asset | Tipo | Exemplo | Uso |
|---|---|---|---|
| `ExecuteTime` | Text | `08:00` | Horário diário da verificação. Aceita `08:00`, `8`, `8h` ou `8h30`. |
| `GameList` | Text | `Resident Evil, Dino Crisis` | Nomes das séries (ou jogos) do speedrun.com, separados por vírgula, ponto e vírgula ou quebra de linha. |
| `SendTo` | Text | `voce@exemplo.com` | Destinatário dos e-mails de recordes e de erro |

### Argumentos do `Main.xaml`

| Argumento | Padrão | Descrição |
|---|---|---|
| `in_AssetFolder` | `SpeedrunRecordChecker` | Pasta dos assets no Orchestrator |

### Conexão do Gmail

O e-mail é enviado por uma conexão do Gmail no Integration Service. Se criar uma conexão nova, atualize o
`ConnectionId` das duas atividades *Send Email* no `Main.xaml`. Se o próprio asset `SendTo` não puder ser
lido, a falha fica só no log, porque não há para quem enviar o e-mail de erro.

## Agendamento

O robô roda neste computador, pelo Agendador de Tarefas do Windows. A tarefa **Speedrun Record Checker**
chama o `run-daily.ps1` a cada 5 minutos. O script só abre o robô quando:

- a verificação de hoje ainda não foi feita;
- já passou o horário do `ExecuteTime` (o robô salva esse horário em `execute-time.txt`);
- não houve outra tentativa nos últimos 60 minutos (evita e-mails de erro repetidos).

Assim a verificação acontece até 5 minutos depois do `ExecuteTime`. Se o computador estiver desligado
nesse horário, ela roda assim que ele for ligado. A tarefa só roda com o seu usuário logado.

Se o `ExecuteTime` for adiantado (por exemplo, de 08:00 para 06:00), o novo horário vale a partir do dia
seguinte. Se for atrasado, vale no mesmo dia.

Para rodar na hora:

```powershell
Start-ScheduledTask -TaskName "Speedrun Record Checker"
```

Para remover o agendamento:

```powershell
Unregister-ScheduledTask -TaskName "Speedrun Record Checker" -Confirm:$false
```

## Arquivos

| Arquivo | Função |
|---|---|
| `Main.xaml` | Ponto de entrada: lê os assets, decide se é hora de rodar, busca os recordes (Invoke Code em VB), envia o e-mail e grava o estado. |
| `run-daily.ps1` | Chamado pelo Agendador de Tarefas; roda o `Main.xaml` com `uip rpa run` quando é hora. |

Arquivos de estado em `%LOCALAPPDATA%\SpeedrunRecordChecker`:

| Arquivo | Conteúdo |
|---|---|
| `last-check.txt` | Horário (UTC) da última verificação concluída |
| `execute-time.txt` | Último valor lido do asset `ExecuteTime` |
| `last-attempt.txt` | Horário da última vez que o script abriu o robô |
| `logs\run-*.txt` | Saída das últimas 30 execuções |

## Desenvolvimento

Com a [UiPath CLI](https://docs.uipath.com/coding-agents/standalone/latest/user-guide/install-and-set-up):

```powershell
uip rpa validate --file-path Main.xaml --project-dir .
```

```powershell
uip rpa build --project-dir .
```

```powershell
uip rpa run --file-path Main.xaml --project-dir .
```

Para testar de novo no mesmo dia, apague `%LOCALAPPDATA%\SpeedrunRecordChecker\last-check.txt` (o robô
volta a olhar as últimas 24 horas) e `last-attempt.txt`.
