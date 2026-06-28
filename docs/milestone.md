# MVP Milestones — Batch 2 (Depth & Replayability)

Batch 1 (see `deprecated-nebula-conquest-revised-prd.md` §18.2, Milestones 1–6)
proved the core loop: flight feels good, auto-fire combat is readable, planets
can be captured, a basic enemy faction reacts, prestige/respawn economy works,
and the homebase shield + victory/defeat conditions close a full match.

This batch turns that proven prototype into a game worth replaying. The goal is
**meaningful choices**: which ship to fly, how to spend prestige, how to retrofit
for support, and how each faction/planet plays differently — without breaking the
"learn in 10 minutes" promise.

Follow `conventions.md` for every milestone (static typing, `class_name`,
signal-first, data-driven resources, simulation/presentation split, per-milestone
sandbox scene under `tests/`).

---

## Milestone 7: Deployment & Ship Purchase Loop

Goal:

- the stubbed purchase/upgrade menu becomes a real spend-prestige decision

Tasks:

- replace the `PlayerHUD` purchase/upgrade stub with a working deployment menu
- list buyable ships with prestige cost, role summary, and affordability state
- spend prestige on respawn/redeploy; fall back to a free T1 ship when broke
- choose deployment loadout (ship + ability) before respawning at homebase
- persist the player's current ship selection in `GameState`
- emit `EventBus` signals for purchase/deploy so HUD and audio can react

Success Criteria:

- player can spend prestige to deploy a stronger ship after a kill streak
- going broke never softlocks: the free fallback ship is always available
- the choice between "save prestige" and "redeploy now" feels meaningful

---

## Milestone 8: Full Ship Roster (4 Classes)

Goal:

- the four archetypes from `ship-classes.md` are all playable

Tasks:

- author `ShipData` + scenes for Scout, Striker, Dreadnaught, Carrier
- give each class distinct stats (speed, hull/shield, weapon, target range)
- implement Carrier drone deployment (launch / auto-attack / recall)
- expose all four classes in the deployment menu with tuned prestige costs
- add a sandbox `tests/` scene that spawns one of each for balance checks

Success Criteria:

- each class has an obvious, distinct playstyle and counter
- no single class is the strictly correct purchase at every prestige level
- Carrier drones read clearly and do not overwhelm the combat UI

---

## Milestone 9: Refits & Engineer Retrofit

Goal:

- ships have a short progression that rewards survival

Tasks:

- add Mk I → Mk II → Mk III refit tiers per class (data-driven, `ShipData`)
- gate refits behind prestige spend at the homebase deployment menu
- implement the Engineer Retrofit option (Repair Beam / Repair Drones)
- Engineer bonuses: +repair speed, +structure build, +planet capture speed
- show refit/retrofit state on the ship and in the HUD

Success Criteria:

- upgrading feels like a reward, not a mandatory grind
- Engineer Retrofit trades combat power for clearly useful utility
- a retrofitted support ship changes how a fight or capture plays out

---

## Milestone 10: Abilities & Planet Modifiers

Goal:

- moment-to-moment combat and the map both gain tactical depth

Tasks:

- expand the ability set per class (e.g. Cloak, Missile Barrage, Siege Mode,
  Fighter Launch) as `AbilityData` resources with cooldowns
- wire ability input, cooldown UI, and `EventBus` feedback
- add planet type modifiers via `PlanetData` (income, capture speed, defenses)
- visually distinguish planet types and surface their bonus in the capture UI

Success Criteria:

- ability timing rewards skilled play without being mandatory spam
- different planets are worth contesting for different reasons
- the map presents readable strategic priorities, not uniform targets

---

## Milestone 11: Third Faction & AI Strategy

Goal:

- the map feels like a contested war, not a 1v1 duel

Tasks:

- add the third faction (data, art hooks, homebase, defenses)
- support 3-way planet ownership and majority/victory math for N factions
- upgrade AI: expand, defend threatened planets, retreat when outgunned
- let AI buy refits/abilities using the same economy as the player
- balance pass on starting prestige, income, and bounties for 3 factions

Success Criteria:

- AI factions expand and fight each other without player involvement
- planet control shifts dynamically over a full match
- no faction snowballs uncontested from a single early lead

---

## Milestone 12: Netcode Prep & Match Polish

Goal:

- the simulation is ready for a future server/client split and ships feel finished

Tasks:

- audit systems for the simulation/presentation split required by `conventions.md`
- route all cross-system state changes through `EventBus` / `GameState`
- make procedural/system setup seed-driven and reproducible
- add match flow polish: countdown, score readout, restart/return-to-menu
- pass through audio, damage feedback, and victory/defeat presentation

Success Criteria:

- gameplay logic has no hard dependency on visuals/UI
- a match can be configured by seed and replays identically
- a full match — deploy, fight, capture, win/lose, restart — feels complete

---

## Batch 2 Success Test

This batch is successful if a player can say:

> "I have real choices — which ship I fly, how I spend prestige, how I retrofit,
> and which planets I fight for — and every match plays out differently."

That is the target for Batch 2.
