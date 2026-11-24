# meapps_ui

Design system partilhado por todas as apps MeApps. Todas usam o mesmo visual,
e só o `MeAppTheme` muda (seed, accent e nome).

## Conteúdo

| Área | O quê |
| --- | --- |
| Tema | `MeAppTheme` (`meremind`, `metasks`, `mebudget`, `mehabits`), `MeSpacing`, `MeRadius` |
| App | `MeApp` (MaterialApp com pt_PT, tema e loading inicial), `AppearanceController`, `showAppearanceSheet` |
| Feedback | `showUndoSnackBar` ("Desfazer"), `confirmDelete` (Cancelar / Apagar) |
| Widgets | `MeCard` + `MeTone` (`label`, `swatch`), `MeTonePicker`, `MeTag`, `MeEmptyState`, `MeSectionHeader`, `MeMonthGrid`, `MeMonthHeader`, `MeThemeSwatches` |
| Utilitários | datas em pt (`formatDayLabel`, `formatAgo`, `formatTime`, `formatMonth`, `isSameDay`, `dateOnly`), aritmética de datas sem problemas de DST (`addDays`, `daysBetween`, `weekStart`, `monthOf`, `addMonths`, `isSameMonth`), `pickDate`, `pickDateTime` |

## Uso típico

```dart
final appearance = AppearanceController(defaultTheme: MeAppTheme.metasks);
late final Future<void> ready = store.init().then((_) {
  appearance
    ..restore(store.settings)
    ..addListener(saveAppearance);
});

MeApp(
  title: 'MeTasks',
  appearance: appearance,
  ready: ready,
  home: (_) => HomeShell(store: store, appearance: appearance),
);
```

Um widget que sirva a mais de uma app vem para aqui, não se copia entre apps.

```bash
flutter test
```
