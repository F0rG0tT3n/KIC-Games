# KIC Bejeweled

A separate, playable singleplayer game with the internal `kic_bejeweled` ID,
`Games/KICBejeweled` module directory and `kic-bejeweled-*` artwork paths. The current
mode picker offers **Normal** and **Roguelike** on every new run, including restarts
and replays. Normal has Bombs, Zaps and Orbs with no timer, Energy, levels or cards.
Roguelike keeps the existing Arcane Rush Energy survival and powers. Reopening an
active run resumes its mode without asking again. The picker blocks play until
selection and offers Back to Launcher to cancel.
Existing saves automatically migrate scores, result history and recent-game
entries to the new ID. If both IDs already have records, the higher best in each
ruleset is retained. Standard Bejeweled keeps its own records and `/bejeweled` command.
Open it in Singleplayer or with `/kicbejeweled`. The `share` argument immediately sends
its best score to party (`/p`), raid (`/raid`) or instance (`/i`) chat as appropriate.
Outside a group, it sends to `/say`. Instance groups use `/i` even when they are
five-player parties; ordinary raids use `/raid`. Sharing preserves the
current pause state. Score fields use plain hyphens instead of pipe characters.

Standard Bejeweled remains `bejeweled`, with its original engine and rules.
KIC Bejeweled does not migrate or overwrite Bejeweled or Tetris records.

## Rules and placement

The board has eight rows, eight columns and seven normal colors. Click adjacent
pieces or use the same directional drag gesture as standard Bejeweled.
**Hint (3/3)** provides three manual hints per run, with the same vertical tile
bounce as standard Bejeweled. There are no automatic hints; restart resets the
allowance while pause/reopen preserves it. Invalid
normal swaps animate back without counting a move. A board with no legal swaps
ends either mode. Energy depletion also ends Roguelike runs.

| Pattern | Created special | Activation |
| --- | --- | --- |
| Exactly four in a straight line | Bomb | Centered 3x3 explosion |
| Five or more in a straight line | Color Orb | Swap with a gem to clear that color |
| Intersecting horizontal and vertical runs of at least three (T, L or cross) | Lightning | Entire row and column |

Intersecting runs form one connected pattern. Priority is Orb, Lightning, Bomb,
ordinary clear. Adjacent but nonintersecting patterns remain independent; two
separate triples never create Lightning. Every affected cell is handled once.

The moved piece's destination receives the special if it belongs to that pattern.
Otherwise, including every cascade, use the topmost matched row, then its leftmost
matched cell. Other independent patterns use the same deterministic fallback.
New specials survive the entire creation phase, even if an explosion also reaches
their cell. Existing specials in the match activate before replacements appear.

Bombs and Lightning keep their normal color and can participate in matches.
Orbs have no normal color and cannot form ordinary matches. An Orb hit by another
special targets the most numerous normal color on the current board; ties choose
the lowest color index. This secondary Orb behavior is deterministic.

## Roguelike: Energy, drafts and powers

Runs begin at 70 / 100 Energy. Base drain is 4 Energy per second while the
board is interactive; pausing, hiding the game, drafts and swap/clear/fall/reshuffle
animations suspend drain. The survival counter measures this interactive time.
Score restores Energy immediately after each clear wave: 0.08 per point, up to
42 base Energy across one entire swap, plus power bonuses. Cascade waves share
that budget, including when a draft interrupts the cascade.

Reaching full Energy pauses the chain and offers three distinct powers. Choose
one to add a stack and gain an Ascension level, or choose **Reshuffle All Gems**
to rearrange existing pieces without gaining a power or level. A reshuffle chosen
mid-cascade waits for a settled board. It preserves every gem and special, avoids
automatic matches and guarantees a legal swap when successful.

After either choice, Energy resets to 50% of maximum, modified by owned powers.
There are 75 powers: 69 repeatable upgrades and six unique relics. Effects have
bounded clear/spawn budgets; stacks beyond effect caps can provide overflow
bonuses. Drain increases with Ascension and tradeoff powers. Second Wind can
rescue depletion once per run. Powers and active runs do not persist across reloads.

Streak Keeper uses the current accepted swap's speed for its first wave and
cascades. Invalid swaps preserve streak/timing state. Gem Magnet recolors only
eligible normal gems that differ from the attuned color, retaining a settled,
playable board.

## Direct combinations

Any adjacent special pair is a valid move. Orb + normal is also always valid.
Combination centers use the player's destination **after the swap**, with edges
clipped to the board. Reversing a swap can therefore change its blast center.

| Pair | Effect |
| --- | --- |
| Bomb + Bomb | 5x5 explosion |
| Bomb + Lightning | Three complete rows and three complete columns |
| Lightning + Lightning | Three complete rows and three complete columns |
| Orb + normal | Clear that normal color and consume the Orb |
| Orb + Bomb | Convert every piece of the Bomb's color to Bombs, then detonate them |
| Orb + Lightning | Convert every piece of the Lightning's color to Lightning, then activate them |
| Orb + Orb | Clear the entire board, then refill |

Direct combinations consume their inputs instead of creating replacements from
ordinary matches on that swap. Remaining matches are evaluated after gravity and
refill. Conversion keeps the target color, includes existing colored specials,
and awards activation bonuses rather than match-creation bonuses.

Each clear is planned using a queue with at most 64 occupied cells. A special
activates at most once per phase, with no recursive explosions. The full affected
area animates before the engine commits the clear. Gravity/refill runs afterward;
new matches continue as cascades until the board settles. Hints and no-moves
completion include all valid Orb/special swaps. Input remains locked throughout
the swap, clear and falling animations.

## Scoring

| Event | Points before cascade multiplier |
| --- | ---: |
| Each removed cell, once per resolution phase | 50 |
| Bomb creation / activation | 100 / 150 |
| Lightning creation / activation | 200 / 250 |
| Orb creation / activation | 300 / 400 |
| Direct special + special combination | 500 |
| Orb + Orb board-clear bonus | 1,000 |
| Major chain: at least three special activations in one phase | 250 once |

Multiply the sum by the cascade number: the initial phase is x1, the next match
after refill is x2, and so on. Bonuses add together. A cell retaining a newly
created special is not counted as removed; it earns the creation bonus instead.
Scores cap at 2,147,483,647, as in the existing game. For example, creating one
Bomb from four gems at x1 removes three cells: `3 * 50 + 100 = 250` points.

Roguelike best scores use `KICGamesDB.kic_bejeweled.arcaneRush.best`.
Normal best scores use `KICGamesDB.kic_bejeweled.best`, retaining existing untimed
records. The two rulesets are never compared or overwritten by the other mode.
The picker displays both bests. Gameplay, sharing, the launcher and Results use
the current mode, or the last selected mode after stopping/reloading, and identify
that mode in record text. Completed match summaries identify Normal or Roguelike.
Completed/interrupted history
uses the framework's existing bounded results array with the new game ID, retaining
the current SavedVariables schema and character filtering. Active runs are not
saved across UI reloads, matching standard Bejeweled.

## Integration and architecture

- `Games/KICBejeweled/Engine.lua` owns all KIC Bejeweled matching, special creation,
  combinations, scoring and resolution. It reuses the original opening-board
  generator, exchange and no-moves state helper through inheritance; refill
  delegates to the original engine unless color-distribution powers are active.
  `Roguelite.lua` owns powers, drafts, Energy and post-move generators, while
  `RogueliteUI.lua` integrates those rules with the shared lifecycle and renderer.
  `Modes.lua` owns the new-run picker and mode selection. Normal leaves the
  engine's roguelite state unset, so all power, Energy and draft effects are disabled.
  The original `Games/Bejeweled/Engine.lua` is unchanged.
- The existing Bejeweled UI methods are shared as functions, with separate module
  state, frames, result-window names and texture arrays. Small optional presentation
  hooks handle KIC Bejeweled art, labels, overlays, score feedback and resolution audio.
  The directional drag/hit-testing algorithm and timing are unchanged.
- The existing module registration/lifecycle code is a small parameterized factory.
  Each invocation captures its own controller, game ID, title and command, retaining
  pause, restart, stop, finish, group-chat sharing and best-score behavior.
- Launcher, Recent Games, Featured Game, Results, Continue Game, graphics changes,
  effects settings and the existing interface scale apply to KIC Bejeweled.
- The exact supplied `kic-bejeweled-hero.tga` (1024x512) and
  `kic-bejeweled-card.tga` (256x256) were copied from the provided artwork archive
  to the runtime media folder. The hero uses left-side text. Existing art is unchanged.
- Bomb, Lightning and Orb markers use registered transparent TGA overlays with
  a backdrop, additive glow and small secondary label. Markers follow underlying
  gem/spec icons during swaps, falls and drags. Reshuffles hide all static layers
  while permutation sprites represent the board, then restore normal rendering.
  Upgrade cards share nine category illustrations plus a reshuffle illustration.
- `Games/KICBejeweled/Effects.lua` renders expanding fiery Bomb shockwaves,
  Lightning discharges along the affected rows/columns, and descending cyan/violet
  Orb bolts to every targeted color cell. Orb + Orb strikes all 64 cells. Full
  special clear durations are 0.65s for Bomb, 0.6s for Lightning and 0.85s for Orb,
  so impacts precede removal. Off keeps the original 0.3s clear; Subtle reduces
  strength/detail. A pool capped at 1,024 native textures is reused, clipped to the
  board and cleaned up on restart/stop. No timers, gameplay RNG calls or new audio.
- Creation, activation, combination and major-chain events map to existing audited
  match sound categories. Only the highest-priority sound plays per phase. Resolution
  audio uses the existing Bejeweled event owner to preserve class/spec mappings,
  resolution throttling and stop-previous-sound behavior. Other lifecycle sounds use
  the KIC Bejeweled registration. Every sound goes through `Games.Audio:Play`, preserving
  Master routing, independent volume, 65% headroom and mute. `Audio.lua` and the
  Options UI are unchanged; no new audio IDs or direct sound calls were added.

## Changed files

Added:

- `KIC-Games/Games/KICBejeweled/Engine.lua`
- `KIC-Games/Games/KICBejeweled/UI.lua`
- `KIC-Games/Games/KICBejeweled/Effects.lua`
- `KIC-Games/Games/KICBejeweled/Module.lua`
- `KIC-Games/Media/KICUI/kic-bejeweled-hero.tga`
- `KIC-Games/Media/KICUI/kic-bejeweled-card.tga`
- `tests/kic_bejeweled.lua`
- `tests/kic_bejeweled_effects.lua`
- `KIC-BEJEWELED.md`

Updated:

- `KIC-Games/Games/Bejeweled/UI.lua` and `Module.lua`: shared presentation/lifecycle hooks.
- `KIC-Games/Artwork.lua`, `KIC-Games/KIC-Games.toc`: art registration and load order.
- `KIC-Games/Launcher.lua`, `KIC-Games/UI.lua`: artwork, layout, pause and resume integration.
- `KIC-Games/ResultsUI.lua`, `KIC-Games/Settings.lua`: KIC Bejeweled statistics and shared cosmetics.
- `tests/framework.lua`: third-game expectations and reusable isolated-client harness.
- `tests/artwork.py`: two additional runtime assets and optional archive byte comparison.
- `README.md`, `CHANGELOG.md`: discovery and implementation notes.

## Verification

Run from the repository root:

```powershell
lua tests/kic_bejeweled.lua
lua tests/kic_bejeweled_effects.lua
lua tests/kic_bejeweled_migration.lua
lua tests/kic_bejeweled_modes.lua
lua tests/roguelite_integration.lua
lua tests/bejeweled_hints.lua
lua tests/share_best.lua
lua tests/framework.lua
lua tests/bejeweled.lua
lua tests/tetris.lua
python tests/artwork.py
python tests/options_assets.py
```

The KIC Bejeweled suite covers pattern priority/placement, creation protection, all seven
Orb targets, every combination in both swap directions and at corners, activation
footprints, dense chains, duplicate prevention, gravity, randomized complete cascades,
invalid swaps, drag suppression, both graphics modes, scale, lifecycle, isolated
scores/history/reload, artwork routing, audio hooks, volume, mute and throttling.
The original framework suite includes its audit regressions.

All roguelite suites run from the repository root:

```powershell
Get-ChildItem tests -Filter roguelite_*.lua | ForEach-Object { lua $_.FullName }
```

The root integration suite exercises real addon startup, special-bearing reshuffles,
static-layer cleanup, layout at 75%/100%/150%, separate score persistence and all
record surfaces, first-wave streak scoring, invalid swaps and safe Gem Magnet
recoloring. Artwork validation covers 47 runtime TGAs and TOC load order.

Only mocked Lua clients and asset checks were run; no live WoW validation is claimed.
An offline preview of the real mocked UI marker and effect geometry was inspected.
In Retail, verify special readability and the shockwave/lightning/storm rendering, title/art
placement, swap/fall/chain animation, cursor behavior at 75%-150% scale, class/spec
graphics changes, perceived sound volume and throttling, and pause/reopen/restart/
stop/completion including reload persistence. No remote push or release ZIP.
