# Backend Development Plan

> Master TODO. Project-specific tasks live in their own files:
> - [today.md](daily_logs/today.md) — today's focus
> - [gas-ebb-dashboard.md](gas-ebb-dashboard.md) — Gas EBB Planned Outages Dashboard
> - [trade-files.md](trade-files.md) — Trade Files
>
> Tags: `TODO` | `DOING` | `BLOCKED` | `DONE` | `QUESTION`

---

## Current Focus

- Gas EBB → Planned Outages Dashboard — see [gas-ebb-dashboard.md](gas-ebb-dashboard.md)

---

## Next Up

### ICE Scripts

- [ ] TODO Refactor ICE Python Scripts to use `symbols/` folder

### Trade Files

- [ ] TODO How to flag when a trade is a broker deal for Kapil — see [trade-files.md](trade-files.md)

---

## Backlog

_Nothing currently in backlog._

---

## Blocked

_Nothing currently blocked._

---

## Done

- [x] DONE Refactor Gas EBB scrapes — 135 pipelines across 15 source families (adapters + YAML configs + Prefect flows)

---

## Open Questions

_No open questions._

---

## Priority Recommendations

| # | Task | Why |
|---|------|-----|
| 1 | Gas EBB Dashboard — verify & harden scrapers | Nothing downstream works until the data pipeline is solid. |
| 2 | ICE symbols refactor | Quick structural cleanup that unblocks cleaner ICE pipeline work. |
