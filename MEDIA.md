# Media layout

Runtime artwork lives in the installable addon's `KIC-Games/Media/` directory:

```text
Media/
  2048/           hero, card
  Battleships/    optional battleships-hero.tga, battleships-card.tga
  Bejeweled/       hero, card, Pieces/gem-1.tga ... gem-7.tga
  KICBejeweled/    hero, card, Specials/, Upgrades/
  Tetris/         hero, card, Pieces/block.tga
  Chess/          hero, card, Pieces/, Squares/
  Blindshot/      hero, card
  Minesweeper/    hero, card
  Shared/         launcher backgrounds, logo, crest and sidebar
    Icons/        shared gameplay icons and ornaments
    Navigation/   launcher navigation icons
```

All 74 supplied runtime textures and two optional Battleships assets are registered centrally in `Artwork.lua`. Existing keys
are unchanged; game code requests those keys rather than constructs file paths.
Both Bejeweled games reuse the original gems in `Bejeweled/Pieces/`, so the same
images are not duplicated in the KIC Bejeweled folder.
The shared hero footer fade is also registered here; revised hero banners contain
their own wordmarks and retain the current launcher presentation.
Battleships expects a 1024×512 hero and 256×256 card; see [BATTLESHIPS.md](BATTLESHIPS.md).
Those two files may be absent until supplied. If present, the artwork checker validates
their formats and dimensions just like the other assets.

The repository-level `Media/` folder holds supplied source artwork outside the
installable addon, organized into game and Shared folders. Minesweeper's PNG
originals are in `Media/Minesweeper/`; its runtime folder contains only TGAs.
Unused PUG concepts are preserved under `Media/Concepts/Pug/`. Blindshot's
originals remain in `KIC-Blindshot-Artwork/Sources/` and the KIC Bejeweled source
archive remains unchanged.

Generation and normalization tools in `tools/` write to the appropriate runtime
game or Shared folder. `python tests/artwork.py` checks registry paths, folder
ownership, exact path casing, TGA formats, dimensions, transparency and supplied
source hashes. It also rejects unregistered textures and source files inside
the runtime Media directory.

Restart WoW after changing texture paths to refresh its file cache. When deploying
a separate copy of the addon, replace its old installable folder to avoid leaving
obsolete files behind.
