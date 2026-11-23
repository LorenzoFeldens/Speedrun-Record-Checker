# Fluxo do processo – Speedrun Record Checker

Este documento descreve, passo a passo, o que o robô faz em cada execução. Todo o processo fica no
[`Main.xaml`](Main.xaml).

## Visão geral

O gatilho do Orchestrator inicia o robô a cada 15 minutos, mas a verificação só acontece uma vez por dia,
depois do horário do asset `ExecuteTime`. Nela, o robô consulta a API do speedrun.com, encontra as runs
verificadas desde a última verificação que estão em 1º lugar no leaderboard e envia um único e-mail com os
novos recordes mundiais.

## Diagrama

```mermaid
flowchart TD
    A([Gatilho a cada 15 min]) --> B["Ler assets<br/><i>SendTo, ExecuteTime, GameList</i>"]
    B --> C{"Hora de verificar?<br/><i>Verificar horário de execução</i>"}
    C -->|"antes do ExecuteTime,<br/>já verificou hoje ou<br/>falhou há menos de 60 min"| N[Registrar no log: fora do horário]
    N --> Z([Fim])

    C -->|sim| D[Registrar tentativa em last-attempt.txt]
    D --> E{Próximo nome do GameList?}
    E -->|sim| F["Buscar a série no speedrun.com<br/>(ou um jogo com esse nome)"]
    F --> G{Próximo jogo?}
    G -->|sim| H["Ler runs verificadas desde a última verificação<br/><i>/runs?status=verified&orderby=verify-date</i>"]
    H --> I{Próxima run?}
    I -->|sim| J["Abrir o leaderboard da run<br/>(categoria, nível e subcategorias)"]
    J --> K{Está em 1º lugar?}
    K -->|sim| L[Adicionar aos novos recordes]
    K -->|não| I
    L --> I
    I -->|não| G
    G -->|não| E

    E -->|não| M{Encontrou recordes?}
    M -->|sim| O["Montar e enviar um único e-mail<br/>com um cartão por recorde (Gmail)"]
    M -->|não| P[Registrar no log: nenhum recorde novo]
    O --> Q[Gravar horário da verificação em last-check.txt]
    P --> Q
    Q --> Z

    B -. erro .-> X[Registrar falha no log]
    F -. erro .-> X
    H -. erro .-> X
    O -. erro .-> X
    X --> X1{Destinatário conhecido?}
    X1 -->|sim| X2[Enviar e-mail de erro]
    X1 -->|não| X3([Job finalizado com falha])
    X2 --> X3
```

## Etapas

| # | Etapa | Atividade no `Main.xaml` | O que faz |
|---|-------|--------------------------|-----------|
| 1 | Ler configurações | *Get Asset – SendTo / ExecuteTime / GameList* | Lê os três assets da pasta `SpeedrunRecordChecker` do Orchestrator. |
| 2 | Hora de verificar? | *Verificar horário de execução* | Interpreta o `ExecuteTime` (`08:00`, `8`, `8h`, `8h30`) e só segue se já passou do horário, se ainda não houve verificação hoje e se não houve uma tentativa nos últimos 60 minutos. |
| 3 | Buscar jogos | *Buscar novos recordes mundiais (API speedrun.com)* | Para cada nome do `GameList`, procura a série e pega todos os jogos dela. Sem série com esse nome, procura um jogo. |
| 4 | Runs novas | *Buscar novos recordes mundiais* | Lê as runs verificadas desde o horário de `last-check.txt`. Na primeira execução, olha as últimas 24 horas. |
| 5 | Filtrar recordes | *Buscar novos recordes mundiais* | Abre o leaderboard de cada run (mesma categoria, nível e subcategorias) e fica só com as que estão em 1º lugar. Entram jogo completo e níveis individuais. |
| 6 | E-mail | *Send Email – Novos recordes* | Envia um único e-mail pelo Gmail com um cartão por recorde: jogo, categoria, tempo, jogador, datas, vídeo, página da run e leaderboard. |
| 7 | Gravar estado | *Salvar horário da última verificação* | Grava em `last-check.txt` o horário (UTC) em que a verificação começou. |

## Entradas

**Assets do Orchestrator** (pasta `SpeedrunRecordChecker`):

| Asset | Exemplo | Uso |
|---|---|---|
| `SendTo` | `voce@exemplo.com` | Destinatário dos e-mails de recordes e de erro |
| `ExecuteTime` | `08:00` | Horário diário da verificação |
| `GameList` | `Resident Evil, Dino Crisis` | Séries (ou jogos) separados por vírgula, ponto e vírgula ou quebra de linha |

**Arquivos de estado** (`%LOCALAPPDATA%\SpeedrunRecordChecker`): `last-check.txt` (última verificação
concluída) e `last-attempt.txt` (última tentativa).

## Saídas

- **E-mail de recordes**, só quando há recordes novos. Assunto:
  - 1 recorde: `Novo recorde mundial <jogo> – <categoria>`;
  - mais de um: `Novos recordes mundiais: <jogo> – <categoria>; <jogo> – <categoria>`;
  - acima de 150 caracteres: `Muitos novos recordes mundiais (N)`.
- **E-mail de erro**, quando a verificação falha.

## Regras de exceção

| Situação | O que acontece |
|----------|----------------|
| Antes do `ExecuteTime` ou já verificou hoje | Registra no log e termina sem consultar a API. |
| `ExecuteTime` em formato inválido | Erro com a mensagem do formato esperado; e-mail de erro e job **com falha**. |
| Limite de requisições do speedrun.com (420/429) ou erro 5xx | Pausa entre chamadas e tenta de novo até 4 vezes, esperando mais a cada tentativa. |
| Qualquer outra falha na verificação ou no envio | E-mail de erro para `SendTo` e job **com falha**. O `last-check.txt` não muda, então a próxima tentativa (depois de 60 minutos) cobre o período perdido. |
| O próprio `SendTo` não pôde ser lido | A falha fica só no log, porque não há para quem enviar o e-mail de erro. |

## Sistemas envolvidos

- **speedrun.com** (API REST v1): séries, jogos, runs e leaderboards
- **Gmail** (UiPath Integration Service): envio dos e-mails
- **UiPath Orchestrator**: assets, gatilho e robô não assistido
