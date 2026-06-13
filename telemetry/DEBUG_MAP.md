# Dusa Debug Map — Live Diagnostic Dashboard

A browser-based monitor for the Dusa ecosystem's structured logs and **diagnostic
codes**. It lives inside `dusa_bridge` (the ecosystem's central telemetry hub) so it
is decoupled from any single resource and survives their restarts.

## Why this exists

When a customer hit an error like *"could not acquire lift control"* we could not
diagnose it without manually adding `print()` calls and shipping a new build. Root cause:

- The default debug level is `ERROR`, so `DEBUG`/`INFO` logs are suppressed on customer
  servers. Devs were forced to add raw `print()` debug lines.
- Failure points did not emit a **stable code** you could look up.
- There was no surface to filter/aggregate/export those logs.

The debug map fixes all three:

1. **`diag(code)`** emits a stable, catalogued code that **always** prints to the
   console (regardless of debug level):
   `[DIAG:LIFT_OWNERSHIP_TIMEOUT] Lift entity ownership could not be acquired | Data: {...}`
   The customer copies that line; you look the code up below.
2. A **problem catalog** maps every code → meaning → likely cause → remediation.
3. A **dashboard** filters by code/level/category/side/player, live-tails, and exports a
   one-click report.

## Opening the dashboard

```
http://<server-ip>:30120/dusa_bridge/debug
```

Local dev: `http://localhost:30120/dusa_bridge/debug`. The page polls its own API
(relative paths) so any IP/port works. It is a **local dev tool** — for production
exposure set `TelemetryConfig.DebugMap.Token` and append `?token=...` to the URL.

Buttons: **Rapor kopyala** (copy report JSON to clipboard) / **.json indir** (download) —
this is how a customer hands you a diagnostic snapshot. **Temizle** wipes the buffer.

## Emitting a diagnostic (in dusa_mechanic)

```lua
-- Server  (server/debug/logging.lua)
MechanicLogger.diag('LIFT_OWNERSHIP_TIMEOUT', { entity = entity, waitedMs = waited })

-- Client  (client/debug/main.lua) — relayed to the server, then to the dashboard
ClientDebug.diag('TOW_OWNERSHIP_TIMEOUT', { target = target, budgetMs = 1000 })
```

`diag()` looks the code up in `MechanicDiagnostics.REGISTRY`
(`dusa_mechanic/config/diagnostics.lua`), picks the catalogued severity/category, and
forces emission past the level/category filters. Keep player-facing `notify()` calls —
`diag()` is for the dev console + dashboard only.

## Diagnostic code reference (tag → problem)

| Code | Category | Sev | Meaning |
|------|----------|-----|---------|
| `LIFT_OWNERSHIP_TIMEOUT` | LIFT | ERROR | Lift entity ownership could not be acquired |
| `LIFT_NOT_NETWORKED` | LIFT | ERROR | Lift entity not networked, cinematic disabled |
| `LIFT_ID_UNREADABLE` | LIFT | WARN | Lift id missing from prop statebag |
| `LIFT_PROP_NOT_FOUND` | LIFT | WARN | Lift prop entity not found for lift id |
| `LIFT_PROP_SPAWN_FAILED` | LIFT | ERROR | Lift prop entity creation failed |
| `LIFT_MODEL_INVALID` | LIFT | ERROR | Lift model could not be resolved |
| `TOW_OWNERSHIP_TIMEOUT` | TOW | ERROR | Tow target vehicle ownership timeout (was "no_target") |
| `TOW_BED_SPAWN_TIMEOUT` | TOW | ERROR | Flatbed bed prop missing after spawn |
| `TOW_BED_OWNERSHIP_DESYNC` | TOW | WARN | Flatbed/bed entity owners diverged |
| `TOW_NPC_SPAWN_FAILED` | TOW | WARN | Tow job NPC failed to spawn |
| `DAMAGE_PLATE_LOCK_TIMEOUT` | DAMAGE | ERROR | Per-plate damage lock timed out |
| `DAMAGE_APPLY_THREW` | DAMAGE | ERROR | Damage apply raised an error |
| `SERVICE_VEHICLE_DATA_MISSING` | SERVICING | ERROR | Vehicle data missing during servicing recovery |
| `DYNO_ANIM_DICT_TIMEOUT` | DYNO | WARN | Dyno anim dictionary failed to load |
| `DYNO_MODEL_INVALID` | DYNO | ERROR | Dyno prop model invalid/missing |
| `DYNO_SPAWN_FAILED` | DYNO | ERROR | Dyno prop spawn/freeze failed |
| `TUNING_PREVIEW_INIT_FAILED` | TUNING | ERROR | Tuning preview failed to initialise |
| `TUNING_MODS_FETCH_FAILED` | TUNING | WARN | Available tuning mods could not be fetched |
| `ECU_INVALID_CURVE` | ECU | WARN | ECU flash rejected — invalid curve data |
| `ECU_UNOWNED_VEHICLE` | ECU | INFO | ECU tuning attempted on unowned vehicle |
| `TRANSMISSION_HPATTERN_NOT_READY` | HPATTERN | WARN | H-pattern commit aborted — client not ready |
| `DB_NOT_READY` | DATABASE | ERROR | Database not ready during startup sync |
| `DB_QUERY_FAILED` | DATABASE | ERROR | A DB query returned nil / failed |
| `ITEM_NOT_REGISTERED` | ITEMS | ERROR | A required inventory item is not registered |
| `VEH_CONTROL_TIMEOUT` | VEHICLE | ERROR | Network control of a vehicle could not be acquired |

Full causes + remediation live in `dusa_mechanic/config/diagnostics.lua` and show on the
dashboard's "Aktif Problemler" panel (click a card to expand).

## Adding a new diagnostic code

1. Add an entry to `MechanicDiagnostics.REGISTRY` in
   `dusa_mechanic/config/diagnostics.lua`.
2. Emit it from the failure point with `MechanicLogger.diag` / `ClientDebug.diag`
   (globals only — escrow-safe).
3. Regenerate the fallback snapshot
   `dusa_bridge/telemetry/catalog/diagnostics.json` to mirror the registry (the live
   export wins when `dusa_mechanic` is started; the snapshot is the standalone fallback).

## Architecture

```
dusa_mechanic                              dusa_bridge (telemetry/)
  config/diagnostics.lua  --getDiagnosticsCatalog()-->  server/catalog.lua
  MechanicLogger.diag() / ClientDebug.diag()
        |  (routes through Logger.log, force=true)
        v
  Logger.log() / clientLog relay / onResourceError
        |  exports.dusa_bridge:ingestLog(entry)   (guarded + pcall)
        v
                                          server/logstore.lua  (ring buffer + agg)
                                          server/http.lua      (SetHttpHandler)
                                          web/debug.html       (dashboard)
```

Config: `TelemetryConfig.DebugMap` in `telemetry/shared/config.lua`
(`Enabled`, `BufferSize`, `PageLimit`, `ReportEntries`, `Token`).

### Session scoping (only the current script session)

The dashboard always shows just the **current** session:

- When a producer (e.g. `dusa_mechanic`) **restarts**, `dusa_bridge` detects its
  `onResourceStart` and wipes the buffer, bumping a `gen` counter. Open dashboards see
  the `gen` change and drop their stale rows automatically.
- When `dusa_bridge` itself restarts, the in-memory buffer is empty by definition; open
  dashboards detect the `seq` reset and re-sync from zero.
- The **Clear** button does the same on demand.

So you never have to manually clear between test runs — `ensure dusa_mechanic` gives you a
clean slate.

The ingest into dusa_bridge reuses the **existing** `isDusaBridgeTelemetryAvailable()`
guard in `dusa_mechanic/server/debug/logging.lua` — the same non-invasive pattern as the
`dusa_tablet:addExternalLog` forward. If `dusa_bridge` is stopped, nothing breaks.
