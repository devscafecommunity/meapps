# MeHabits

Registo de hábitos diários — local first (SQLite via Drift), sem conta nem nuvem.

## Funcionalidades

- **Hoje**: faixa da semana (seg…dom) para escolher hoje ou um dia passado; os
  hábitos previstos nesse dia com anel de progresso e `contagem/meta`. Tocar
  regista uma vez, manter premido (ou "−") retira um registo. Cabeçalho
  "3 de 5 concluídos". Os hábitos não previstos nesse dia ficam numa secção à
  parte e podem ser registados na mesma.
- **Progresso**: por hábito, sequência atual, melhor sequência e taxa dos
  últimos 30 dias. O detalhe mostra o calendário do mês com os dias concluídos
  marcados, navegação entre meses e permite corrigir os registos de um dia.
- **Hábitos**: criar/editar (nome, ícone, cor, dias da semana, meta diária),
  reordenar (arrastar), arquivar/desarquivar (secção "Arquivados") e apagar
  com confirmação e "Desfazer" (repõe também os registos).
- **Aparência** (paleta + claro/escuro) guardada entre arranques.

## Regras das estatísticas

- Um dia está **concluído** quando os registos chegam à meta diária.
- **Sequência atual**: dias previstos e concluídos seguidos, a contar de hoje
  para trás. Dias não previstos são ignorados (não contam nem quebram), hoje
  ainda por concluir não quebra (conta a partir de ontem) e o dia de criação
  do hábito é o limite.
- **Melhor sequência**: a maior sequência desde a criação, com as mesmas regras.
- **Taxa a 30 dias**: dias previstos concluídos / dias previstos desde
  max(criação, há 29 dias) até hoje; hoje só entra quando está concluído.

## Estrutura

```
lib/data/database.dart        schema Drift (v1): habits, checkins, settings
lib/data/habit.dart           modelos (Habit, HabitIcon, Weekdays) + estatísticas puras
lib/data/app_store.dart       AppStore (memória + escrita em SQLite) + dados de demonstração
lib/screens/                  shell, Hoje, Progresso (+ detalhe), Hábitos, sheet do hábito
lib/widgets/                  WeekStrip, HabitRing, HabitCheckCard, HabitStatsRow, ações com "Desfazer"
```

O `AppStore` é a única fonte de verdade: cada alteração atualiza a memória,
notifica a UI e escreve no SQLite. Os registos (`checkins`) têm chave
(`habit_id`, `day`) e são apagados em cascata com o hábito. Os dias são
guardados como texto `aaaa-mm-dd`, para o histórico não mudar de dia com o
fuso horário. Os ícones são um `enum` com valores `const` de `Icons` (guardados
pelo nome), para não estragar o tree-shaking dos ícones.

Os dados de demonstração só são criados numa base de dados nova (primeiro
arranque); apagar todos os hábitos não os faz voltar.

## Desenvolvimento

```bash
flutter test
dart run build_runner build --delete-conflicting-outputs   # após mudar o schema
flutter run -d linux
```

Ao mudar o schema: subir `schemaVersion`, acrescentar o passo em `onUpgrade`
(na `MigrationStrategy` de `AppDatabase`) e um teste de migração.

## Web

Na web os dados ficam no armazenamento do browser (OPFS ou IndexedDB, o
Drift escolhe o melhor disponível) através de `web/sqlite3.wasm` e
`web/drift_worker.js`. Os dois ficheiros são gerados por `tool/web_assets.sh`
na raiz e têm de ser atualizados sempre que o `drift` ou o `sqlite3` mudam
de versão no `pubspec.lock`.

```bash
flutter run -d chrome
flutter build web
```
