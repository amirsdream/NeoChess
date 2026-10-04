# NeoChess

A polished desktop chess game for Windows, built with Godot 4.7. Play against
[Stockfish](https://stockfishchess.org), watch its five best lines update live
while it thinks, or play a friend on the same computer.

![NeoChess playing a game](docs/screenshot.png)

## Features

- **Full chess rules**: castling, en passant, promotion, check, checkmate,
  stalemate, threefold repetition, the fifty-move rule and insufficient material.
  The move generator is checked against the standard perft positions.
- **Play Stockfish 19** at any strength: levels 0 to 20, or cap it at an Elo
  rating from 1320 to 3190. The engine stays running between moves, and the
  engine card shows its name, depth and speed.
- **Live engine analysis**: Stockfish's top five lines stream in as they are
  found, with score, depth and the full variation. A plus always means good for
  *you*, whichever colour you play.
- **Eval bar**, player strips with captured pieces and material lead, a move
  list, undo, and a board you can flip.
- **Review and analyse any position.** Click a move in the list, or use the arrow
  keys, to see the board as it was. Stockfish analyses that position
  continuously, with its five best lines and the eval bar, until you move on.
  Then go back to the game, or continue from there.
- **Two ways to think**: a fixed time per move, or a real chess clock (1 to 30
  minutes per side) where Stockfish decides how long each move needs.
- **12 board themes and 12 piece sets.** Hover to preview, click to keep. The
  whole app takes its colours from the board you pick.
- **Pass and play** for two people on one computer. This needs no engine.
- **Import and export** with the standard formats: games as PGN and positions
  as FEN. Copy, paste, save, open, or drag a `.pgn` file onto the window (see
  [Importing and exporting games](#importing-and-exporting-games)).
- **Game library and opening book.** Every game you play is saved in a local
  SQLite database that you can search, review and export. Import big PGN
  databases, or download free ones of strong players, and see what was played in
  them after your moves (see [Game library](#game-library-and-opening-book)).
- Smooth piece movement, a last-move arrow, legal-move hints and keyboard
  shortcuts.

| Look and feel | Settings |
| --- | --- |
| ![Ocean board theme](docs/ocean.png) | ![Settings drawer](docs/settings.png) |

## Getting started

### Play

1. Download `NeoChess-<version>-windows-x64.zip` from the
   [latest release](https://github.com/amirsdream/NeoChess/releases/latest).
2. Unzip it anywhere.
3. Run `NeoChess.exe`.

There is no installer and nothing else to set up. Stockfish is already in the zip.

Release builds include Stockfish next to the exe. If you have only the exe, or
you build from source, NeoChess detects that the engine is missing and offers a
**Download Stockfish** button (see [The Stockfish engine](#the-stockfish-engine)).

**Requirements:** Windows 10 or 11 (64-bit). An internet connection is only
needed for the one-time engine download. NeoChess talks to the engine directly,
so nothing else (no PowerShell, no helper scripts) is involved. The code is
platform independent and also runs on Linux and macOS from source (see
[Linux and macOS](#linux-and-macos)).

### Controls

| Action | Mouse | Key |
| --- | --- | --- |
| Move a piece | Click it, then click where it goes | |
| New game (asks which side you want: White, Black or Random) | **New game** | `N` |
| Take back a move | **Undo** (in a game against Stockfish it takes back your move and the reply) | `U` |
| Flip the board | **Flip** | `F` |
| Open or close settings | **Settings** / **Done** | `S` |
| Cancel a selection, close settings | | `Esc` |
| Look at an earlier position and analyse it | Click a move in the **Moves** list | `Left` / `Right` |
| First position, latest position | **«** and **»** under **Moves** | `Home` / `End` |
| Continue the game from the position you are viewing | **Play from here** | |
| Copy the game as PGN | **Game** > **Copy game (PGN)** | `Ctrl+C` |
| Copy the position as FEN | **Game** > **Copy position (FEN)** | `Ctrl+Shift+C` |
| Paste a game or position | **Game** > **Paste game or position** | `Ctrl+V` |
| Open the game library | **Game** > **Game library…** | `L` |

### Reviewing a game

Click any move in the **Moves** list (or press `Left`) to see the position after
it. The header shows **Reviewing**, the board is read-only, and about a third of
a second after you stop clicking, Stockfish starts analysing that position at
full strength. Its five best lines and the eval bar update live and keep
going deeper until you leave the position, so a plus always means good for you.

- `Left` and `Right` step through the moves, `Home` jumps to the start and
  `End` (or clicking the last move) returns to the game.
- **Play from here** discards the moves after the position you are viewing and
  carries on from it. Against Stockfish you play the side that is to move.
- Undo is disabled while you review. New game and importing a game also leave
  the review.

### Importing and exporting games

NeoChess uses the formats every chess program understands, so games move freely
between NeoChess, Lichess, Chess.com, ChessBase, Stockfish GUIs and so on.

| Format | What it is | Use it for |
| --- | --- | --- |
| **PGN** (Portable Game Notation) | A whole game: player tags, moves in algebraic notation and the result | Saving, sharing and analysing games |
| **FEN** (Forsyth-Edwards Notation) | A single position on one line | Setting up a position to play from |

The **Game** menu in the header has:

- **Copy game (PGN)** and **Copy position (FEN)** put the text on the clipboard.
- **Save game as…** writes a `.pgn` file.
- **Paste game or position** reads the clipboard. NeoChess works out whether it
  is a PGN or a FEN.
- **Open game file…** reads a `.pgn`, `.fen` or `.txt` file. You can also drag
  a file onto the window.

Details:

- Exported games carry the standard seven tags (`Event`, `Site`, `Date`,
  `Round`, `White`, `Black`, `Result`). Games that did not start from the normal
  position also get `SetUp` and `FEN`, as the PGN standard asks.
- Import accepts comments, variations, `$` annotations, `0-0` style castling,
  Windows line endings and files with many games (the first game is loaded).
  Variations and comments are skipped, not kept.
- Only standard chess is supported. A game with another `Variant` tag, an illegal
  move or an invalid position is refused, and the message names the move.
- After an import you keep playing from the position. Against Stockfish you
  play the side that is to move.

### Game library and opening book

**Game > Game library…** (or `L`) opens your library: a SQLite database stored in
NeoChess's user data folder (`games.db`).

- **My games** collects your own games automatically: when one ends, and when
  you start a new game or load another one over an unfinished game (with at
  least two moves). Games you load from files are not saved again.
- **Search** by player, event or opening, filter by result, rating and year, and
  sort by date, rating or length. Searches run on a background thread and show
  100 games per page, so a library of half a million games stays responsive. Select a game and press **Review game** (or
  double-click) to step through it with Stockfish's analysis. **Export PGN…**
  writes the selected games to a file and **Delete** removes them.
- **Import games…** adds a `.pgn` file or a `.zip` of PGN files, also by
  dropping them on the window. Millions of games are fine: the file is read on a
  background thread (roughly 4,000 games a second), you can keep playing, and
  **Cancel** keeps what has been added. Importing a file twice adds nothing
  new. Other chess variants are skipped.
- **Download a database…** fetches a month of the free
  [Lichess Elite database](https://database.nikonoel.fr) (games of strong
  players, about 300,000 per month, CC0) and imports it.
  The much larger [Lichess open database](https://database.lichess.org) is
  published as `.pgn.zst`; unpack it first, then use **Import games…**.
- **Remove collection** deletes an imported database from the library. The
  original file is not touched.

The **Book** switch in the engine card shows what was played in the library
after the moves on the board: how many games, and how often White won, drew and
lost. Click a move to play it (when it is your turn), or look at any position in
a review. Choose one collection or all of them. The book follows the order of
the moves, so a position reached by a different move order is a separate line,
and it covers the first 12 moves of games from the standard start.

### Settings

- **Play**: opponent (Stockfish or pass and play), strength, and how long
  Stockfish thinks (fixed per move, or a chess clock). Switching the opponent
  starts a new game.
- **Look**: board theme, piece set and the last-move arrow.
- **Engine**: CPU threads, hash memory, move overhead and the engine file.

Your choices are saved automatically to the Godot user folder
(`%APPDATA%\Godot\app_userdata\NeoChess`).

## The Stockfish engine

NeoChess does not contain Stockfish in its source code. Stockfish is licensed
under the GPLv3, so the repository keeps it out and NeoChess finds or fetches
it at run time. It looks for `stockfish.exe` (`stockfish` on Linux and macOS) in this order:

1. The path saved in **Settings, Engine, Engine file**, if the file exists.
2. `bin\stockfish.exe` inside the project (development).
3. `stockfish.exe` or `bin\stockfish.exe` next to `NeoChess.exe`.
4. The copy NeoChess downloaded for you:
   `%APPDATA%\Godot\app_userdata\NeoChess\engine\stockfish.exe`.
5. On Linux and macOS only: a Stockfish installed on the system, such as
   `/usr/games/stockfish`, `/usr/bin/stockfish` or `/opt/homebrew/bin/stockfish`.

When none of these exist and you are playing Stockfish, a card appears in the
sidebar:

![Stockfish download card](docs/download.png)

- **Download Stockfish 19** fetches the official build for your system, for
  example [`stockfish-windows-x86-64-universal.zip`](https://github.com/official-stockfish/Stockfish/releases/tag/sf_19)
  from the Stockfish GitHub release (about 80 MB), unpacks the engine into your
  user folder, checks that it starts, and selects it. You can cancel while it
  downloads. The universal build picks the fastest instruction set your CPU
  supports.
- **Choose file** lets you point at a Stockfish you already have, for example a
  newer build from [stockfishchess.org/download](https://stockfishchess.org/download/).
- **Pass and play** works without any engine.

The same download button lives under **Settings, Engine**. Nothing is sent to
anyone except the request to GitHub, and nothing is installed outside the
NeoChess user folder.

### Verifying a download and code signing

Every release includes a `.sha256` file. To check the zip:

```powershell
(Get-FileHash .\NeoChess-1.0.0-windows-x64.zip -Algorithm SHA256).Hash.ToLower()
# compare with the contents of NeoChess-1.0.0-windows-x64.zip.sha256
```

Release builds are made by the public GitHub Actions workflow in this repository.
They are **not code-signed yet**, so Windows SmartScreen may show "Windows protected
your PC" the first time. Choose **More info, Run anyway**, or build it yourself from
source. Signing through the [SignPath Foundation](https://signpath.org) is prepared in
`release.yml` and `.signpath/` and switches on when the repository has the SignPath
settings (see [Contributing](#contributing)).
## Building from source

You need [Godot 4.7.2](https://godotengine.org/download) (the standard build,
not .NET) and, to export, its Windows export templates.

```powershell
git clone <this repository>
cd NeoChess

# Optional: get Stockfish into bin/ so the game has an engine straight away.
./dev/fetch_stockfish.ps1

# Run from the editor
godot --path . --editor
# or run the game directly
godot --path .
```

You can skip the fetch step and use the in-app download instead.

### Tests

```powershell
./tests/run_tests.ps1                  # everything
./tests/run_tests.ps1 -Filter uci      # one file
./tests/run_tests.ps1 -VerboseChecks   # list every passing check
```

The script finds Godot from `-Godot <path>`, then `$env:GODOT`, then `PATH`.
On Linux and macOS use `sh tests/run_tests.sh [filter]` (set `GODOT` to the binary).

| File | What it covers |
| --- | --- |
| `test_rules.gd` | Perft against the standard test positions, castling, en passant, pins, mate |
| `test_chess_extra.gd` | FEN, promotion, draws, repetition, castling rules, SAN, cloning |
| `test_pgn.gd` | PGN export and import (comments, variations, castling, promotion, errors), FEN validation |
| `test_uci.gd` | `go` commands, option clamping, parsing `info` and `option` lines |
| `test_engine_setup.gd` | Per-platform downloads and lookup, zip and tar.gz extraction, executable checks (no network) |
| `test_appearance.gd` | Every theme is complete and every palette meets contrast targets |
| `test_smoke.gd` | Loads the real scene and plays, undoes and restarts a game, imports and exports |
| `test_store.gd` | The SQLite library: reading PGN fast, saving, searching, the explorer, threads, damaged files |
| `test_library.gd` | The library in the app: saving games, the window, background imports (PGN, zip, cancel), the opening book |
| `test_engine.gd` | `UciEngine` against a real Stockfish: handshake, options, MultiPV, stop and replace, shutdown, and reviewing a game in the app; skipped if no engine is installed |

### Release build

```powershell
./dev/build.ps1 -Zip              # bundles Stockfish, writes dist/NeoChess-windows.zip
./dev/build.ps1 -NoEngine         # a small build that offers the in-app download
```

If you ship the engine, keep `Copying.txt`, `AUTHORS` and `STOCKFISH.txt` beside
it. `build.ps1` does this for you.

### Continuous integration and releases

GitHub Actions does the same work on a clean Windows machine:

- **CI** (`.github/workflows/ci.yml`) runs on every push to `main` and on pull
  requests. It installs Godot (checksum-verified), fetches Stockfish, runs the whole
  test suite, then builds the package and checks that the bundled engine starts. The
  build is kept as a 7 day artifact.
- **Release** (`.github/workflows/release.yml`) runs when you push a version tag. It
  repeats the tests, stamps the version into the exe, and publishes a GitHub release
  with `NeoChess-<version>-windows-x64.zip` and its `.sha256` file.

To ship a version:

```powershell
git tag v1.0.0
git push origin v1.0.0
```

You can also start **Release** by hand from the Actions tab to get the zip as an
artifact without publishing anything.

## How it works

```text
scenes/main.tscn        the single scene
scripts/main.gd         layout, game flow, settings, engine control
scripts/chess_game.gd   rules: moves, check, FEN, SAN, draws, perft
scripts/pgn.gd          PGN import and export
scripts/pgn_reader.gd   fast, forgiving PGN reader for big databases
scripts/game_store.gd   the SQLite library: games, collections, search, opening explorer
scripts/game_importer.gd background import of PGN files and zips
scripts/library_view.gd the game library window
scripts/book_query.gd   opening book lookups on a worker thread
scripts/database_downloader.gd  downloads a game database
addons/godot-sqlite/   SQLite for Godot (native library, MIT)
scripts/board_view.gd   board drawing, animation, eval bar, last-move arrow
scripts/uci_engine.gd   a running UCI engine: process, searches, analysis, shutdown
scripts/stockfish_uci.gd UCI commands and parsing of engine output (pure functions)
scripts/engine_setup.gd  engine lookup per platform, zip and tar.gz extraction, checks
scripts/engine_installer.gd  the download itself
scripts/appearance.gd   board and piece themes, app palette from a board
scripts/piece_art.gd    recolours the piece outlines per piece set
dev/                    fetch and build scripts
tests/                  headless test suite
```

NeoChess starts Stockfish once and keeps it running, talking to it over its
standard input and output with Godot's `OS.execute_with_pipe`. `UciEngine`
(`scripts/uci_engine.gd`) is a small, reusable API for any UCI engine:

```gdscript
var engine := UciEngine.new()
add_child(engine)
engine.info.connect(func(entry): print(entry["depth"], " ", entry["cp"], " ", entry["pv"]))
engine.best_move.connect(func(move): print("best: ", move))
engine.start("/usr/games/stockfish")
engine.search(fen, {"movetime": 500}, {"Threads": 2, "MultiPV": 3})
engine.search(fen, {"infinite": true})   # analysis; a new search replaces it
engine.stop()
```

- Reader threads feed a queue that the main thread drains each frame, so the
  window never blocks, and there are no temporary files or polling.
- Searches never overlap. Asking for a new one while the engine is busy sends
  `stop` and starts the new search only after the engine has answered, so lines
  from the old position cannot be mistaken for the new one.
- Options are read from the engine's own list (`option name ... type spin ...`),
  clamped to its limits, skipped if it does not have them, and sent only when
  they change. `ucinewgame` is sent when a game starts.
- It handles engines that never answer, that are not UCI engines at all, or that
  crash: the app shows a message instead of freezing. Engine processes are
  stopped when the app quits.

### Linux and macOS

The game logic, the engine API, the platform-aware lookup and the download (the
Linux and macOS releases are `.tar.gz`, unpacked by NeoChess itself) contain no
Windows-specific code. Stockfish publishes builds for Linux (x86-64, arm64,
riscv64) and macOS. Run it from source with Godot 4.7 and either install
Stockfish with your package manager or use the in-app download. Run the tests
with `sh tests/run_tests.sh`. Packaged Linux and macOS builds are not published
yet, and the platform paths have been tested through the unit tests and on
Windows only.
## Troubleshooting

- **"Stockfish was not found"**: use the Download button, or **Choose file**.
- **The download fails**: you will see the reason (offline, blocked, disk full).
  Try again, or download the zip from the release page yourself and choose the
  `.exe` inside it.
- **The engine seems slow or loses time on a clock**: raise *Move overhead*
  under Settings, Engine.
- **No live lines**: switch the *Live* toggle on in the Engine analysis card.

## Contributing

Issues and pull requests are welcome. Run `./tests/run_tests.ps1` before sending a
change; CI runs the same tests. Keep new code covered by a test where it can be.

Maintainers: to turn on code signing, apply for free open-source signing at
[signpath.org/apply](https://signpath.org/apply.html), add the `SIGNPATH_API_TOKEN`
repository secret, and set the repository variables `SIGNPATH_ORGANIZATION_ID`,
`SIGNPATH_PROJECT_SLUG` (default `NeoChess`) and `SIGNPATH_SIGNING_POLICY_SLUG`
(default `release-signing`). The next tagged release is then signed automatically.

## Credits and licenses

- NeoChess source code: [MIT](LICENSE). Third-party notices are in [THIRD_PARTY.md](THIRD_PARTY.md).
- [Stockfish](https://stockfishchess.org): GNU GPL v3, by the Stockfish
  developers. Downloaded or bundled as a separate program, never linked in.
- Chess piece drawings: the Cburnett set by Colin M. L. Burnett, triple-licensed
  under the GFDL, BSD and GPL. NeoChess recolours the outlines at run time. See
  [`pieces/CREDITS.txt`](pieces/CREDITS.txt).
- [godot-sqlite](https://github.com/2shady4u/godot-sqlite) by Marc Vincent (MIT)
  and [SQLite](https://sqlite.org) (public domain) store the game library. The
  native library `libgdsqlite` must stay next to `NeoChess.exe`.
- Game databases you download are the work of their publishers; the Lichess
  Elite database is by nikonoel and is made of lichess.org games (CC0).
- Built with [Godot Engine](https://godotengine.org) (MIT).
