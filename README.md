# FFoundryCon

App Flutter companion para Foundry VTT (D&D 5e) — hoja de personaje, tiradas,
D-pad de tokens y chat en vivo, incluso sin la tab del GM abierta.

Parte de un sistema de 4 componentes ([detalle completo](https://github.com/joselicht90/foundry-data-reader/blob/main/CLAUDE.md)):

| Proyecto | Qué es |
|---|---|
| [foundry-data-reader](https://github.com/joselicht90/foundry-data-reader) | Server HTTP/WS que expone la API de Foundry (Docker en la Pi) |
| `foundry-data-reader/foundry-module` | Módulo Foundry "roll-listener" |
| [foundry-gm-headless](https://github.com/joselicht90/foundry-gm-headless) | Cliente GM headless (Playwright) para que el reader tenga siempre datos live |
| **FFoundryCon** (este repo) | App Flutter companion móvil |

## Stack

Flutter 3.35.2 (Dart 3.9) vía **FVM**, Riverpod (estado + DI), `dio`, patrón
repositorio, `json_serializable` + `build_runner`, Material 3 dark.

## Setup

```bash
fvm flutter pub get
fvm dart run build_runner build   # tras tocar un modelo @JsonSerializable
```

### VS Code + FVM

`.vscode/settings.json` necesita **ambas** claves (la segunda evita "SDK
undefined" en la extensión Dart):

```json
{
  "dart.flutterSdkPath": ".fvm/flutter_sdk",
  "dart.sdkPath": ".fvm/flutter_sdk/bin/cache/dart-sdk"
}
```

## Correr

```bash
fvm flutter run
```

Al abrir, la app pide la **URL del reader** (por defecto
`https://reader.r4spi.com`, expuesto vía Cloudflare Tunnel desde la
Raspberry Pi). Flujo: Setup (URL) → World select → User select → Actor
select → hoja de Foundry.

⚠️ Requiere un GM logueado en Foundry (real o vía `foundry-gm-headless`)
para tiradas/acciones en vivo; sin eso el reader devuelve timeout en
`/api/actors`.

## Análisis / tests

```bash
fvm flutter analyze && fvm flutter test
```

## Estructura

```
lib/
  core/          # network (dio), storage, logging, theme, notifications
  models/        # DTOs (@JsonSerializable): actor, world, user, chat, roll...
  repositories/   # foundry_repository.dart (llamadas al reader)
  controllers/    # Notifiers Riverpod: chat, session, token, actor, combat...
  features/       # setup → world → user → gm/player (pantallas)
```
