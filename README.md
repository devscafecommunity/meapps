# MeApps

Suite de apps simples do dia a dia em Flutter, **local first**.

```
packages/meapps_ui   design system partilhado (tokens, MeAppTheme, widgets)
apps/meremind        calendario + notas + lembretes
```

Pub workspace: `flutter pub get` na raiz resolve tudo.

## Regra de ouro
Todas as apps partilham o mesmo visual; so muda o `MeAppTheme` (seed + accent).
Widgets reutilizaveis vao para `meapps_ui`, nunca copiados entre apps.

```bash
flutter analyze                       # na raiz
cd apps/meremind && flutter run -d chrome
tool/web_assets.sh                    # após atualizar drift/sqlite3
```

## Web
As apps guardam os dados com Drift (SQLite). Na web isso precisa de
`sqlite3.wasm` e `drift_worker.js` na pasta `web/` de cada app; o
`tool/web_assets.sh` gera-os para todas as apps a partir das versões do
`pubspec.lock` (o worker é compilado aqui, o wasm vem do release oficial do
`sqlite3`).

## Novo app
1. `flutter create apps/<nome>`, adicionar `resolution: workspace` e a dependencia `meapps_ui`.
2. Adicionar a pasta em `workspace:` no `pubspec.yaml` da raiz.
3. Definir um `MeAppTheme` novo em `meapps_ui`.
4. Abrir a base com `driftDatabase(name: ..., web: DriftWebOptions(...))`
   como as outras apps e correr `tool/web_assets.sh`.
