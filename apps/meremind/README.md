# MeRemind

Agenda, notas e lembretes — local first (SQLite via Drift), sem conta nem nuvem.

## Funcionalidades

- **Agenda**: calendário mensal com marcadores; "Novo lembrete" usa o dia selecionado.
- **Notas**: texto ou checklist, fixar, cor, etiqueta, lembrete, arquivo, pesquisa
  (título, corpo, etiqueta, itens) e apagar com "Desfazer". Guarda ao sair.
- **Lembretes**: criar/editar/apagar (deslizar), data rápida ou personalizada,
  repetição diária/semanal/mensal/anual. Concluir um lembrete repetido passa-o
  para a próxima ocorrência.
- **Notificações do sistema** em Android, iOS e macOS (`flutter_local_notifications`).
  Na Web/Linux/Windows a app funciona sem notificações.
- **Aparência** (paleta + claro/escuro) guardada entre arranques.

## Estrutura

```
lib/data/database.dart           schema Drift (v2) + migrações
lib/data/app_store.dart          modelos + AppStore (memória + escrita em SQLite)
lib/services/reminder_notifier.dart  notificações (interface + plugin + noop)
lib/screens/                     ecrãs e sheets
lib/widgets/                     ReminderTile, pickDateTime
```

O `AppStore` é a única fonte de verdade: cada alteração atualiza a memória,
notifica a UI, escreve no SQLite e sincroniza a notificação do lembrete.
Os lembretes de uma nota são linhas de `reminders` com `note_id`.

## Desenvolvimento

```bash
flutter test
dart run build_runner build --delete-conflicting-outputs   # após mudar o schema
flutter run -d linux
```

Ao mudar o schema: subir `schemaVersion`, acrescentar o passo em `onUpgrade` e
um teste em `test/migration_test.dart`.
