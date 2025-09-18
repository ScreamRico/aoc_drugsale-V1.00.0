# Rico's Drug Sale

> Street-level hustling with streak UI, smarter NPC buyers, tier-based payouts, and persistence for QB-Core servers.

## Features
- Kick off `/selldrugs` runs with an ox_lib session card, phone-call intro, and graceful cleanup when the clock expires.
- Dynamic buyer spawning with configurable ped pools, distance bands, concurrency caps, and visibility checks.
- Reputation system with fractional gains per drug, tier bonuses, and automatic persistence to JSON.
- `/drugdash` player dashboard and `/rep` menu that surface streak, totals, current tier, and next milestones.
- Admin-only `/drugsim` simulator to preview per-drug payout math and risk rolls after you tweak config values.
- Optional Discord webhooks and server events for big flips, reputation milestones, and custom dispatch integrations.
- Localised prompts via ox_lib, with English shipped and simple hooks for more languages.

## Requirements
- FiveM server on the *cerulean* runtime (`fxmanifest` target)
- [`qb-core`](https://github.com/qbcore-framework/qb-core)
- [`ox_lib` >= v2.44.5](https://overextended.dev/)
- [`ox_inventory`](https://github.com/overextended/ox_inventory)
- Items referenced in `Config.DrugData` (e.g. `coke_pure`, `meth_bag`, `black_money`) registered in your shared item table

## Installation
1. Drop the resource folder into your server resources, e.g. `resources/[local]/ricos_drugsale`.
2. Ensure dependencies start before this script (ox_lib must initialise first).
3. Add the resource to `server.cfg`:
   ```cfg
   ensure ox_lib
   ensure ox_inventory
   ensure qb-core
   ensure ricos_drugsale
   ```
4. Restart the server or run `refresh` then `ensure ricos_drugsale` via txAdmin.

The bundled JSON placeholders ship empty; they populate automatically the first time the resource runs.

## Commands & UI
- `/selldrugs` – start or cancel a selling session (8 minutes by default).
- `/rep` – view your stored reputation, tier perks, and next threshold.
- `/drugdash` – open the live dashboard showing streak, sales, totals, and hot product tips.
- `/drugsim` – admin-only simulator for payout averages and final risk odds.

## Configuration Highlights
| Key | Description | Default |
| --- | --- | --- |
| `Config.SessionDuration` | Seconds per selling session | `480` |
| `Config.SessionMoveRadius` | Max distance from the start point | `35.0` |
| `Config.BuyerSpawnInterval` | Seconds between buyer spawn attempts (min/max) | `{ min = 8, max = 14 }` |
| `Config.MaxConcurrentBuyers` | Active buyer limit | `3` |
| `Config.SessionPersistence.enabled` | Persist sessions to `data/sessions.json` | `true` |
| `Config.Webhook.bigSaleThreshold` | One-sale payout required before pinging Discord | `5000` |
| `Config.Debug` | Logs payout/risk breakdowns to server + player | `false` |

Each entry in `Config.DrugData` defines item metadata, payout ranges, risk odds, and `repGain` (fractional reputation you earn per sale). Reputation tiers are sorted by `min` and can be tuned to match your economy.

## Persistence & Data
- `data/reputation.json` stores reputation keyed by the player identifier (Steam/license/etc.).
- `data/sessions.json` tracks active sessions so players reconnecting mid-run resume seamlessly.
- Both files start as empty JSON objects in this release package and are filled during live gameplay.

## Troubleshooting
- **Buyers ignore you:** confirm the models in `Config.CustomPeds` exist and you’re not inside an interior/vehicle.
- **No payout:** check that the player holds one of the configured drugs and that `black_money` is registered.
- **Frequent busts:** tweak tier modifiers or enable `Config.Debug` to see roll breakdowns in-game.
- **Webhooks silent:** set `Config.Webhook.enabled = true` and provide a valid Discord URL.

## Support
Questions or feedback? Join [AOC Development Support](https://discord.gg/eMdD6SytX7) or DM **scream_rico** on Discord.

## Credits
- Script authored by **AOCDEV**
- Systems & documentation by the Rico community contributors

## License
MIT License – see `LICENSE` for details.
