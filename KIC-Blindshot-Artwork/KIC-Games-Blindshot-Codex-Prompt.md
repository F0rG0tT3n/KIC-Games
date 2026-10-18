# KIC-Games – Implement KIC Blindshot

Implement a new fully playable party multiplayer game inside the existing KIC-Games World of Warcraft Retail addon.

## Goal
Add a new game called **KIC Blindshot**.
This is a fast party minigame for 2–5 players while waiting between dungeons.

Core fantasy:
- each round, every alive player secretly chooses a new position on a floating platform
- each player also secretly chooses an aim direction
- players do **not** see each other during the aiming phase
- when everyone locks in, or the round timer expires, all players are revealed
- everyone fires **simultaneously**
- dead players are eliminated
- the platform shrinks before the next round
- last surviving player wins

## Important scope rules
- Multiplayer only for now
- No singleplayer
- One weapon only
- No classes / abilities / pickups / AI / multiple weapons yet
- Keep it simple, fair, and replayable
- Reuse the existing KIC-Games framework, UI style, lobby flow, and addon communication patterns

## Installed artwork
These files are already present and must be used:
- `Media/KICUI/Blindshot/blindshot-hero.tga` — large launcher / gameplay left panel art
- `Media/KICUI/Blindshot/blindshot-card.tga` — small launcher game card art

Reference-only visuals:
- `KIC-Blindshot-Artwork/blindshot-ui-mockup.png`
- `KIC-Blindshot-Artwork/blindshot-hero-preview.png`
- `KIC-Blindshot-Artwork/blindshot-card-preview.png`

Register the art through the existing Artwork / registry conventions already used by other KIC-Games modules.
Do not regenerate substitute art if the files already exist.

## Integration requirements
Before coding, inspect and reuse the existing systems for:
- game registry / launcher integration
- multiplayer lobby creation and join flow
- party-only addon communication
- host-authoritative state sync
- ready flow
- results tracking
- Play / Resume / Back to Launcher behavior
- Theme.lua / Artwork.lua patterns

Do not create a separate networking architecture if the addon already has the required transport.
Do not redesign unrelated games.

## Game identity
- Game ID: `blindshot`
- Display name: `Blindshot`
- Category: `multiplayer`
- Subtitle: `HIDE / AIM / FIRE`
- Supported players: 2 to 5 players in the same PARTY group

## Lobby flow
Implement the standard KIC-Games multiplayer flow:
1. A player hosts the game from the multiplayer section.
2. Other party members see the lobby and can join.
3. Joined players have a ready toggle.
4. The host can start only when the minimum player count is met and all players are ready.
5. After start, the game enters round 1.

Requirements:
- host-authoritative lobby state
- party-only communication
- no whisper traffic
- no visible party chat spam
- handle join / leave / ready / unready cleanly
- if someone leaves during lobby, the player list updates correctly
- if the host leaves, end the lobby / match cleanly unless the framework already supports host transfer

## Match structure
A match is a sequence of rounds.
Each round has these phases:
1. `PREPARE`
2. `AIM`
3. `REVEAL`
4. `RESOLVE`
5. `ROUND_END`
6. `MATCH_END`

### Round flow
- Determine current arena radius
- Each alive player chooses a position inside the platform
- Each alive player chooses an aim direction
- Each alive player presses **Lock In**
- During AIM, a player sees only their own marker and aim line
- Other players remain hidden during AIM
- When all players lock in, or the timer expires, reveal everyone
- All shots resolve simultaneously from the same locked state
- Mark deaths
- If more than one player survives, shrink the arena and begin next round
- If one player survives, they win
- If everyone dies in the same volley, end in a draw

## Arena
Use an angled top-down floating arena.
The platform should visually shrink each round.

Recommended shrink schedule:
- Round 1: 1.00
- Round 2: 0.82
- Round 3: 0.68
- Round 4: 0.56
- Round 5+: 0.46 minimum floor or continue with a documented schedule

Players must choose positions within the legal circle.
Add minimum spacing so players cannot spawn directly on top of each other.

## Weapon
Implement exactly one weapon for v1.
Use a clean, readable instant straight-line shot:
- one shot per player per round
- line / beam in the chosen direction
- resolved simultaneously
- a player killed in that volley still fires if they locked in
- one shot may hit multiple players if they stand in line

Keep the hit rule deterministic and easy to test.

## UI layout
Match the existing KIC-Games premium dark neon fantasy UI.
Use the standard 3-column layout.

### Left panel
Show:
- Blindshot hero art
- title: `KIC BLINDSHOT`
- subtitle: `HIDE / AIM / FIRE`
- concise rules
- current phase hint
- buttons depending on state:
  - Ready
  - Lock In
  - Leave Match
  - Back to Launcher

### Center panel
Main arena view.
Requirements:
- circular platform clearly visible
- current valid radius visible
- player can click to place position
- player can drag or otherwise set aim direction
- local player marker and aim line shown during AIM
- enemies hidden during AIM
- after reveal, show all players and all shot lines
- show simultaneous firing clearly
- keep animations readable and short

### Right panel
Show:
- round number
- players alive
- participant list
- ready / locked status
- local state / dead or alive
- short event log / last round summary
- winner or draw at the end

## Input / timers
Recommended interaction:
- click arena to choose your position
- move mouse or drag to set aim direction
- press Lock In

Add an aim timer, for example 15 seconds.
If time expires:
- if the player chose a valid position and direction, auto-lock it
- otherwise use a documented fallback

## Multiplayer / authority
Use a host-authoritative model.
Clients submit hidden round actions to the host.
The host validates and stores them.
The host only reveals all chosen positions / aim directions at the reveal step.

Handle:
- stale messages
- duplicate messages
- wrong match IDs
- dead players trying to act
- player leave during match
- UI close / reopen
- `/reload` recovery if reasonably supported by current architecture

## Results tracking
Track at least:
- matches played
- wins
- draws
- rounds played
- eliminations dealt
- rounds survived (optional)

Do not break results for other games.

## Code structure
Keep it modular. Recommended files:
- `Games/Blindshot/Module.lua`
- `Games/Blindshot/Session.lua`
- `Games/Blindshot/UI.lua`
- `Games/Blindshot/Simulation.lua` or `Rules.lua`

Avoid a giant monolithic file.
Keep simulation logic separate from rendering and separate from network state handling.

## Testing
Add useful tests or local simulation helpers for:
- 2-player flow
- 5-player flow
- simultaneous kill
- one winner
- draw
- arena shrink schedule
- legal placement validation
- hidden action submission
- timeout behavior
- player leave during lobby
- player leave during match

Do not claim live multiplayer validation unless actually tested.

## Final deliverables
At the end, provide:
- summary of implemented features
- added / modified files
- how the lobby works
- how simultaneous resolution works
- tests run
- known limitations
- live party test instructions

Final goal: a polished, playable **KIC Blindshot** multiplayer party minigame inside KIC-Games, with host / join / ready flow, hidden aiming, simultaneous firing, shrinking platform rounds, and one weapon.
