# MeTasks

Listas de tarefas — local first (SQLite via Drift), sem conta nem nuvem.

## Funcionalidades

- **Hoje**: tarefas em atraso, de hoje e concluídas hoje. "Nova tarefa" já vem
  com a data de hoje.
- **Próximas**: tarefas por fazer agrupadas por dia a partir de amanhã, depois
  as que não têm data.
- **Listas**: cartões com o número de tarefas por fazer; cada lista abre com as
  pendentes e uma secção "Concluídas" que se pode expandir. Criar, mudar o nome
  e a cor, apagar (com confirmação e "Desfazer"). As tarefas de uma lista
  apagada passam para a **Caixa de entrada**, que se pode renomear mas nunca
  apagar.
- **Tarefas**: título, notas, lista, data rápida (Hoje / Amanhã / Próxima semana)
  ou personalizada, prioridade (nenhuma, baixa, média, alta) e subtarefas.
  Concluir e apagar (deslizar ou no editor) com "Desfazer". Ordenadas por
  prioridade, data e posição.
- **Pesquisa** na barra de topo (título, notas e subtarefas).
- **Aparência** (paleta + claro/escuro) guardada entre arranques.

## Estrutura

```
lib/data/database.dart           schema Drift (v1)
lib/data/app_store.dart          modelos + AppStore (memória + escrita em SQLite)
lib/screens/                     ecrãs (Hoje, Próximas, Listas, lista) e sheets
lib/widgets/                     TaskTile, TaskSection, snackbar com "Desfazer"
```

O `AppStore` é a única fonte de verdade: cada alteração atualiza a memória,
notifica a UI e escreve no SQLite. As subtarefas são linhas de `subtasks`
(apagadas em cascata com a tarefa). Os dados de demonstração só entram numa
base de dados nova.

## Desenvolvimento

```bash
flutter test
dart run build_runner build --delete-conflicting-outputs   # após mudar o schema
flutter run -d linux
```

Ao mudar o schema: subir `schemaVersion`, acrescentar o passo em `onUpgrade` e
um teste de migração.
