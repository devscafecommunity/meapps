# MeBudget

Orçamento mensal pessoal — local first (SQLite via Drift), sem conta nem nuvem.
Só euros.

## Funcionalidades

- **Resumo**: saldo do mês (receitas, despesas, saldo a cores) e despesas por
  categoria com valor, percentagem do total e barra face ao orçamento mensal
  (quando excedido, a barra fica vermelha e mostra quanto passou).
- **Movimentos**: lista do mês agrupada por dia com o total de cada dia, filtro
  por categoria, tocar para editar e deslizar para apagar com "Desfazer".
- **Categorias**: despesas e receitas com nome, ícone, cor e orçamento mensal
  (só despesas). Apagar pede confirmação e passa os movimentos para "Outros"
  do mesmo tipo (com "Desfazer"). "Outros" é fixa e não se apaga.
- **Novo movimento**: despesa/receita, valor, categoria, data (Hoje, Ontem ou
  escolher) e nota opcional. O cabeçalho do mês (`Novembro 2026 [Este mês] ‹ ›`,
  o `MeMonthHeader` do `meapps_ui`) é comum ao Resumo e aos Movimentos.
- **Aparência** (paleta + claro/escuro) guardada entre arranques.

## Estrutura

```
lib/data/database.dart        schema Drift (v1): categories, entries, settings;
                              dias sem hora (yyyymmdd)
lib/data/app_store.dart       modelos + AppStore (memória + escrita em SQLite)
lib/data/money.dart           formatMoney / parseMoney (cêntimos inteiros)
lib/data/category_icon.dart   ícones das categorias (enum -> Icons const)
lib/screens/                  ecrãs e sheets
lib/widgets/                  EntryTile, CategoryAvatar, cores
```

O `AppStore` é a única fonte de verdade: cada alteração atualiza a memória,
notifica a UI e escreve no SQLite. Todos os totais (mês, dia, categoria,
orçamento) são calculados no `AppStore`.

Valores sempre em **cêntimos inteiros** (nunca `double`). As datas dos
movimentos guardam-se como `yyyymmdd`, para não mudarem de dia com o fuso
horário. Os ícones guardam-se pelo nome do enum e mapeiam para `Icons` const
(nunca `IconData` a partir de code points, para não partir o tree-shaking).

## Desenvolvimento

```bash
flutter test
dart run build_runner build      # após mudar o schema
flutter run -d linux
```

Ao mudar o schema: subir `schemaVersion`, acrescentar o passo em `onUpgrade` e
um teste de migração.
