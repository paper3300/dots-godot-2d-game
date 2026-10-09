# Verification record

Date: 2026-10-09 UTC. Engine: installed Godot 4.6.3 stable, standard GDScript build, Compatibility renderer.

## Passed in checkpoint 004

- Headless import with no script/resource errors.
- Main-scene startup reaches `Briar & Bone ready.` with no errors.
- 137 deterministic rule checks, including:
  - One accepted action → one enemy/status phase; invalid actions consume none.
  - Dead enemies do not act; death stops further input.
  - Brace duration, Hew interrupt/cooldown, dash collision, bleed timing, and treatment.
  - Archer telegraph, wall occlusion, and symmetric nearby sight lines throughout the ruin.
  - Full-pack rejected loot retention, item/equipment conservation, trading, and water refill economics.
  - Contract acceptance, gated relic retrieval, return reward, and repeat-reward prevention.
  - Save/load of inventory, injury, enemies, doors, quest and reward; malformed/version-incompatible saves rejected without mutation.
  - Safe arrival when a return tile is occupied.
  - Deterministic command replay.
- Automated complete adventure using actual movement/combat/interaction commands without stat boosts or inventory deletion: 248 turns including final inn rest, survived at rank 3, 174 crowns. The bot took the upgrade caches and used starting/recovered healing supplies.

- A second direct-contract playthrough without purchases or optional caches also survived: 177 turns, 64 HP, starting sword and leather armor. Optional equipment is not required to complete the contract.
- 39 headless UI-flow checks: title/help return, nonstarted-save protection, menu/skill cancellation, input-repeat suppression, new/load confirmation, and death recovery. Phase004 adds item-detail close/no-op behavior, explicit Use/Equip/Drop, re-pickup conservation, quest-drop protection, and double-tap map leakage prevention.
- Phase003 independent review: 57,992 seeded randomized assertions across 40 short runs: replay after JSON round-trip, accepted/invalid turn accounting, HP/energy/pack bounds, and actor occupancy. An independent reviewer also reran 37 focused checks.
- Phase004 expanded replay fuzz includes dropping and re-pickup: 58,436 assertions passed across 40 runs.
- A separate phase004 transaction suite passed 15,181 assertions across 2,700 seeded transitions, including conservation across backpack/equipment/all ground piles, legacy-save flags, malformed drop metadata, and a rapid Back-to-pack regression using the actual drawn button registry. It is included as `tests/fuzz_drop_transactions.gd`.
- An independently reproduced Back double-tap previously leaked into map auto-walking. The closing pointer guard now covers Back/Close as well as item actions; the reproduction passes without queued movement or turns.
- Actual cloud-desktop Godot playability review (including final K-save → move → L-load restoration): Korean title, help, contract, shop, pack, and HUD all fit with no missing glyphs; purchase/pack use, forest combat/loot, save and menu/L restore operated correctly. Saved money, location, and purchased quantity restored.
- A complete bundled-font glyph coverage check passed for both runtime scripts, including the inventory multiplication symbol; no runtime glyph relies on OS fallback.
- Phase004 removed the three intentional integer-division editor warnings. Native004b item-modal QA passed in Korean and English: legible descriptions, no-op treatment, rapid Back/Use/Equip/Drop clicks, exact turn costs, retained equipment, complete re-pickup, and dropped-stack save/load.
- The independent UI review found F9 colliding with the embedded editor's pause hotkey; primary load is now L. Primary save is K to avoid browser refresh. Loaded inventory counts are rendered as integers.
- Matching official-template exports: Windows x86_64, Linux x86_64, and non-threaded Web all completed with no export errors/warnings. The Linux release executable also starts headlessly without source.

- Native Linux003 manual full loop passed: Warden defeat, relic pickup, return, and 90-crown reward at turn 189; repeated hand-in did not duplicate rewards. Death/save protection/load and a real process quit/relaunch at the relic state passed. The run used the found sword, no shop purchases or stat edits, and ended at 54/70 HP.
- Two cosmetic state mismatches found in that run are corrected in 004: the taken relic is now an empty plinth, and recovered/completed board wording matches quest state.
- Final004 native spot-check loaded the real completed003 save with turn 224, 70 HP, and 169 crowns unchanged. The completed board explicitly acknowledges the paid reward and free inn; the cleared dungeon shows an empty relic plinth, and interacting does not recollect it or consume a turn.

## Review corrections already applied

Independent read-only review found and implementation corrected: no-op well advancing a turn; malformed top-level save values mutating state; unvalidated object IDs; occupied arrival overlap; asymmetric line-of-sight; dictionary-order-dependent loot selection; title/help returning into gameplay without starting a run.

## Pending / not claimed

- Full native Windows execution is untested; no Windows/Wine runtime is available in this environment. The executable is unsigned.
- Web export is complete, and its JavaScript passes syntax validation. Private-hosting infrastructure, asset integrity, lossless WASM transport, and WASM compilation were verified separately on checkpoint003. Actual hosted game/input/touch testing remains blocked by ChatGPT sign-in in the QA browser; Android playback is unverified.
- Audio is synthesized in code. Headless tests disable playback; the graphical cloud environment uses a dummy audio driver, so audible output is unverified.
- Human completion time, mobile, gamepad, and accessibility/screen-reader behavior are not validated.

Run `sh scripts/smoke-test.sh` for an isolated repeat of import, rules, UI flow, and startup. Run `FULL_TESTS=1 sh scripts/smoke-test.sh` to include the longer seeded replay and item-conservation tests. The UI tests refuse to overwrite a pre-existing player save when run outside the isolated runner. The script rejects any Godot `ERROR:` or `SCRIPT ERROR:` even if the engine exits with code zero.
