# MeApps

Suite de apps simples do dia a dia em Flutter, **local first**.

```
packages/meapps_ui   design system partilhado (tokens, MeAppTheme, widgets)
apps/meremind        calendario + notas + lembretes (mockups)
```

Pub workspace: `flutter pub get` na raiz resolve tudo.

## Regra de ouro
Todas as apps partilham o mesmo visual; so muda o `MeAppTheme` (seed + accent).
Widgets reutilizaveis vao para `meapps_ui`, nunca copiados entre apps.

```bash
flutter analyze                       # na raiz
cd apps/meremind && flutter run -d chrome
```

## Novo app
1. `flutter create apps/<nome>`, adicionar `resolution: workspace` e a dependencia `meapps_ui`.
2. Adicionar a pasta em `workspace:` no `pubspec.yaml` da raiz.
3. Definir um `MeAppTheme` novo em `meapps_ui`.
