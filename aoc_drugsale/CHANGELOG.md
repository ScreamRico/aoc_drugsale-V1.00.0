# Changelog

## 1.0.0 (2025-09-17)
- Replaced client/server sale flow with tier-aware alert/reject/aggression logic and fractional reputation gains per drug.
- Added reputation tiers, configurable bonuses, `/drugsim` admin simulator, and debug logging toggle for payout tuning.
- Persist active sessions in `data/sessions.json` and auto-resume players after reconnect or restart.
- Introduced streak-focused session card, `/drugdash` dashboard, hot product tips, and localized messaging.
- Wired optional Discord webhooks and alert events for big sales, milestones, and dispatch integration.
- Expanded configuration docs, instructions, and support contact details in the README.
