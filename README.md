# Speedrun Record Checker

Robô UiPath (VB.NET, Windows) que verifica uma vez por dia no speedrun.com se surgiram novos **recordes
mundiais** nos jogos das séries configuradas (hoje *Resident Evil* e *Dino Crisis*) e envia um e-mail com
os recordes novos e o link do vídeo de cada um.

## Como funciona

O processo roda no Orchestrator todos os dias às 08:00 (Brasília). Em cada execução:

1. Lê os assets `SendTo` e `GameList` da pasta **SpeedrunRecordChecker**.
2. Para cada nome do `GameList`, procura a série no speedrun.com e pega todos os jogos dela. Se não achar
   uma série com esse nome, procura um jogo com esse nome.
3. Para cada jogo, lê as runs verificadas desde a última verificação
   (`/runs?status=verified&orderby=verify-date`). A primeira execução olha as últimas 24 horas.
4. Para cada uma dessas runs, abre o leaderboard dela (mesma categoria, nível e subcategorias) e só fica
   com as que estão em **1º lugar**. Entram recordes de jogo completo e de níveis individuais.
5. Se houver recordes novos, envia **um único e-mail** pela conexão do Gmail no Integration Service:
   - assunto com 1 recorde: `Novo recorde mundial <jogo> – <categoria>`;
   - assunto com mais de um: `Novos recordes mundiais: <jogo> – <categoria>; <jogo> – <categoria>`;
   - se o assunto passar de 150 caracteres: `Muitos novos recordes mundiais (N)`;
   - corpo: um cartão por recorde, com jogo, categoria, tempo, jogador, datas, link do vídeo, página da run
     e leaderboard.
6. Grava o horário da verificação. Se algo falhar, envia um e-mail com o erro e mantém o horário anterior,
   para que a execução do dia seguinte cubra o período perdido.

O passo a passo completo, com diagrama, está em **[WORKFLOW.md](WORKFLOW.md)**.

## Configuração no Orchestrator

Tudo fica na pasta **SpeedrunRecordChecker**.

### Assets

| Asset | Tipo | Exemplo | Uso |
|---|---|---|---|
| `SendTo` | Text | `voce@exemplo.com` | Destinatário dos e-mails de recordes e de erro |
| `GameList` | Text | `Resident Evil, Dino Crisis` | Nomes das séries (ou jogos) do speedrun.com, separados por vírgula, ponto e vírgula ou quebra de linha. |

### Argumentos do `Main.xaml`

| Argumento | Padrão | Descrição |
|---|---|---|
| `in_AssetFolder` | `SpeedrunRecordChecker` | Pasta dos assets |

### Processo e gatilho

| Item | Valor |
|---|---|
| Processo | `Speedrun Record Checker` (pacote `Speedrun.Record.Checker`) |
| Gatilho | `Speedrun Record Checker - diário 08h`, cron `0 0 8 ? * *`, fuso *E. South America Standard Time*, robô não assistido |

Para mudar o horário, edite o cron do gatilho no Orchestrator. Se o computador estiver desligado às 08:00,
o job fica pendente no Orchestrator até o robô ficar disponível. Em todo caso, cada execução cobre todo o
período desde a última verificação concluída, então nenhum recorde se perde.

### Robô

A pasta tem o *machine template* **PC-0** (1 slot não assistido) e o seu usuário com o papel
*Automation User*, como na pasta AfternoonWalk. O computador precisa estar ligado e conectado ao
Orchestrator pelo UiPath Assistant (*Machine Key*). O horário (UTC) da última verificação concluída fica no
próprio computador, em `%LOCALAPPDATA%\SpeedrunRecordChecker\last-check.txt`.

### Conexão do Gmail

O e-mail é enviado por uma conexão do Gmail no Integration Service. Se criar uma conexão nova, atualize o
`ConnectionId` das duas atividades *Send Email* no `Main.xaml`. Se o próprio asset `SendTo` não puder ser
lido, a falha fica só no log, porque não há para quem enviar o e-mail de erro.

## Desenvolvimento

Com a [UiPath CLI](https://docs.uipath.com/coding-agents/standalone/latest/user-guide/install-and-set-up):

```powershell
uip rpa validate --file-path Main.xaml --project-dir .
```

```powershell
uip rpa build --project-dir .
```

Para publicar uma nova versão, aumente `projectVersion` no `project.json` e rode:

```powershell
uip rpa pack . ..\pacotes
```

```powershell
uip rpa publish ..\pacotes\Speedrun.Record.Checker.<versão>.nupkg
```

Depois, atualize o processo para a nova versão no Orchestrator.

Para testar, inicie o processo manualmente no Orchestrator. Para olhar de novo as últimas 24 horas, apague
antes o `last-check.txt`.
