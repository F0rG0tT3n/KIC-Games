# Bejeweled Deluxe

A separate, playable singleplayer game registered as `bejeweled_deluxe`.
Open it in Singleplayer or with `/kicbejeweleddeluxe`. The `share` argument drafts
its best score in chat, following the existing game behavior.

Standard Bejeweled remains `bejeweled`, with its original engine and rules.
Deluxe does not rename, migrate or overwrite Bejeweled or Tetris records.

## Rules and placement

The board has eight rows, eight columns and seven normal colors. Click adjacent
pieces or use the same directional drag gesture as standard Bejeweled. Invalid
normal swaps animate back without counting a move. There is no timer.

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

Best scores use `KICGamesDB.bejeweled_deluxe.best`. Completed/interrupted history
uses the framework's existing bounded results array with the new game ID, retaining
the current SavedVariables schema and character filtering. Active runs are not
saved across UI reloads, matching standard Bejeweled.

## Integration and architecture

- `Games/BejeweledDeluxe/Engine.lua` owns all Deluxe matching, special creation,
  combinations, scoring and resolution. It reuses only the original opening-board
  generator, exchange, gravity/refill and no-moves state helper through inheritance.
  The original `Games/Bejeweled/Engine.lua` is unchanged.
- The existing Bejeweled UI methods are shared as functions, with separate module
  state, frames, result-window names and texture arrays. Small optional presentation
  hooks handle Deluxe art, labels, overlays, score feedback and resolution audio.
  The directional drag/hit-testing algorithm and timing are unchanged.
- The existing module registration/lifecycle code is a small parameterized factory.
  Each invocation captures its own controller, game ID, title and command, retaining
  pause, restart, stop, finish, chat drafting and best-score behavior.
- Launcher, Recent Games, Featured Game, Results, Continue Game, graphics changes,
  effects settings and the existing interface scale apply to Deluxe.
- The exact supplied `bejeweled-deluxe-hero.tga` (1024x512) and
  `bejeweled-deluxe-card.tga` (256x256) were copied from the provided artwork archive
  to the runtime media folder. The hero uses left-side text. Existing art is unchanged.
- Bombs have an orange/red flame treatment; Lightning has a cyan/white bolt; Orbs
  have seven colored facets over a circular energy glow. Persistent labels identify
  all three. Overlays follow animated icons and drag ghosts. Bombs/Lightning retain
  the original gem or spec spell icon underneath. No generated replacement artwork.
- Creation, activation, combination and major-chain events map to existing audited
  match sound categories. Only the highest-priority sound plays per phase. Resolution
  audio uses the existing Bejeweled event owner to preserve class/spec mappings,
  resolution throttling and stop-previous-sound behavior. Other lifecycle sounds use
  the Deluxe registration. Every sound goes through `Games.Audio:Play`, preserving
  Master routing, independent volume, 65% headroom and mute. `Audio.lua` and the
  Options UI are unchanged; no new audio IDs or direct sound calls were added.

## Changed files

Added:

- `KIC-Games/Games/BejeweledDeluxe/Engine.lua`
- `KIC-Games/Games/BejeweledDeluxe/UI.lua`
- `KIC-Games/Games/BejeweledDeluxe/Module.lua`
- `KIC-Games/Media/KICUI/bejeweled-deluxe-hero.tga`
- `KIC-Games/Media/KICUI/bejeweled-deluxe-card.tga`
- `tests/bejeweled_deluxe.lua`
- `BEJEWELED-DELUXE.md`

Updated:

- `KIC-Games/Games/Bejeweled/UI.lua` and `Module.lua`: shared presentation/lifecycle hooks.
- `KIC-Games/Artwork.lua`, `KIC-Games/KIC-Games.toc`: art registration and load order.
- `KIC-Games/Launcher.lua`, `KIC-Games/UI.lua`: artwork, layout, pause and resume integration.
- `KIC-Games/ResultsUI.lua`, `KIC-Games/Settings.lua`: Deluxe statistics and shared cosmetics.
- `tests/framework.lua`: third-game expectations and reusable isolated-client harness.
- `tests/artwork.py`: two additional runtime assets and optional archive byte comparison.
- `README.md`, `CHANGELOG.md`: discovery and implementation notes.

## Verification

Run from the repository root:

```powershell
lua tests/bejeweled_deluxe.lua
lua tests/framework.lua
lua tests/bejeweled.lua
lua tests/tetris.lua
python tests/artwork.py
python tests/options_assets.py
```

The Deluxe suite covers pattern priority/placement, creation protection, all seven
Orb targets, every combination in both swap directions and at corners, activation
footprints, dense chains, duplicate prevention, gravity, randomized complete cascades,
invalid swaps, drag suppression, both graphics modes, scale, lifecycle, isolated
scores/history/reload, artwork routing, audio hooks, volume, mute and throttling.
The original framework suite includes its audit regressions.

Final automated results:

- Deluxe: 116,024 engine and integration assertions passed.
- Framework: 3,726 assertions passed, including audit regressions.
- Original Bejeweled: 68,272 assertions passed.
- Tetris: 44,303 engine and icon assertions passed.
- Artwork: 34 runtime TGAs passed dimensions, encoding, registry and TOC checks;
  both Deluxe files matched the supplied archive bytes exactly.
- Options assets: all 40 spec profiles, icons and audited sound mappings passed.
- StyLua checks and `git diff --check` passed.

Only mocked Lua clients and asset checks were run; no live WoW validation is claimed.
In Retail, verify special readability and the circular native glow, title/art
placement, swap/fall/chain animation, cursor behavior at 75%-150% scale, class/spec
graphics changes, perceived sound volume and throttling, and pause/reopen/restart/
stop/completion including reload persistence. No remote push or release ZIP.
