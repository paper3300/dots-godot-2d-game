# Design decisions

## Identity and scope

Briar & Bone is an original small tactical adventure. Its provisional setting is Briarhaven, the old road, and the Sunken Priory. A stolen bell gives the outward-and-return journey a clear purpose. No material was extracted from another game.

The intended first-run experience is 15–25 minutes, not yet a measured human-play statistic. Completion means accepting the contract, recovering its guarded relic, returning to the village, receiving the reward once, and being able to rest/save or explore the remaining rooms.

## Deliberate simplifications

- Four-way movement avoids diagonal corner ambiguities.
- Three handcrafted persistent maps; six connected rooms. No procedural generation.
- Four enemy roles: wolf, robber, telegraphing archer, telegraphing elite.
- Guaranteed melee hits make health costs predictable. There are no hidden accuracy rolls.
- Three fixed active skills and automatic rank growth, rather than a large skill tree.
- One scalar injury count and pain, rather than an anatomical body-part simulation.
- Eight inventory stacks, one item type per slot, plus a quest pouch. No shape packing or durability.
- Sword and body armor slots. The shield is the visual source of Brace, not a separately swappable item.
- Food/water limit long outings; no fatigue or psychiatric system.
- One save slot; save anywhere. This is intentionally more forgiving than a bed-only or permadeath system.
- Minimal synthesized effects; no external music or copyrighted audio.

## Turn contract

RunState is the only owner of turn advancement. A successful move, attack, wait, door opening, treatment, equipment swap, ground pickup, or cache/relic interaction advances one turn. Invalid commands, menus, trading, and contract dialogue advance none. Inn rest is an explicit 30-turn out-of-combat recovery service.

Order: validate → player action → pre-existing bleeding/needs → living enemies in stable order → cooldown/recovery → reveal. Newly inflicted bleeding does not tick immediately. Brace covers its cast turn and the next enemy turn. Hew interrupts the enemy response in its cast turn. Animation never triggers rules.

Enemies do not act after death. Player death halts the remainder of the enemy phase. A movement command cannot open a door and cross it in the same turn. Mouse walking stops on detected danger, failure, map transition, or cancellation.

## Persistence and invariants

- World state includes opened doors/caches, dead enemies, ground loot, fog exploration, quest/reward state, and player conditions.
- Save files include a schema version. They are parsed/validated before live state changes.
- Numeric JSON representation may change integers to floating-point variants, but gameplay state is compared after JSON normalization in tests.
- Quest rewards are granted once. The quest item is consumed upon hand-in.
- Full inventory never deletes rejected ground loot. Equipment swaps preserve displaced equipment or reject the swap.
- Water refill is capped at three carried flasks and cannot be sold, preventing a free-resource money loop.
- Map arrival searches for a free tile if the preferred spawn is occupied.
- Reciprocal line traces eliminate one-way visibility at Bresenham tie cases.
- Loot item priority and UI inventory order are deterministic across saving/loading.

## Known limitations

- UI is custom-drawn, with keyboard shortcuts and pointer buttons; it does not implement screen-reader semantics or controller navigation.
- Only Korean and English. Existing log entries stay in the language used when they were written.
- Text is designed for a 1280×800 viewport; small windows are scaled rather than reflowed.
- No remappable keys, multi-slot saves, cloud-save sync, or gamepad controls.
- No continuous movement from held keys. Repeated deliberate presses are required in combat.
- No published performance measurements or accessibility certification.
- Desktop visual QA, export status, and concrete evidence belong in TESTING.md; source startup alone does not prove a platform's rendered build works.
