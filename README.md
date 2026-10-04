# NeoChess

A polished desktop chess game for Windows and Linux, built with Godot 4.7. Play
against [Stockfish](https://stockfishchess.org), watch its five best lines update
live while it thinks, review any position of a game, and keep every game you play
in a searchable library with an opening book.

![NeoChess playing a game, with Stockfish's lines and the opening book](docs/images/game.png)

## Highlights

- **Full chess rules** and a move generator checked against the standard perft
  positions.
- **Stockfish 19 included.** Play at levels 0 to 20 or cap it at an Elo rating
  from 1320 to 3190, with a fixed time per move or a real chess clock.
- **Run the engine on your graphics card.** Switch to **Leela Chess Zero** in
  Settings, Engine and download it once (about 175 MB); it thinks with a neural
  network on any DirectX 12 GPU while Stockfish stays the processor engine.
- **Live engine analysis.** The top five lines stream in with score, depth and
  full variation. A plus always means good for *you*, whichever colour you play.
- **Review any position.** Click a move, or use the arrow keys, and Stockfish
  analyses that position until you move on, and draws its three best moves on the board as thick, medium and thin arrows. Switch **Live** off to stop it.
  Then carry on from there.
- **Game library.** Every game you play is saved in a local SQLite database.
  Search, filter, review and export them, import big PGN databases, or download
  free ones of strong players. Searching half a million games stays instant.
- **Opening names and book.** See which opening you are in (*C70 · Ruy Lopez: Morphy Defense*), where a game left the known lines, and what was played next in your library with how often White won, drew and lost.
- **12 board themes and 12 piece sets**, and the whole app takes its colours from
  the board you pick.
- **Pass and play** for two people on one computer (no engine needed), PGN and FEN
  import and export, drag and drop, and keyboard shortcuts.

| Review with the opening book | Game library |
| --- | --- |
| ![Reviewing a position with live lines and the opening book](docs/images/book.png) | ![The game library](docs/images/library.png) |

| Another theme | Settings |
| --- | --- |
| ![Ocean board theme](docs/images/ocean.png) | ![Settings](docs/images/settings-play.png) |

*The library in these pictures is made-up sample data.*

## Install

Download a zip from the
[latest release](https://github.com/amirsdream/NeoChess/releases/latest):

| Platform | File | Run |
| --- | --- | --- |
| Windows 10/11 (64-bit) | `NeoChess-<version>-windows-x64.zip` | `NeoChess.exe` |
| Linux (x86_64) | `NeoChess-<version>-linux-x64.zip` | `./NeoChess.x86_64` |

There is no installer and nothing else to set up: Stockfish and the database
library are in the zip. On Linux, if the binary is not executable after unzipping,
run `chmod +x NeoChess.x86_64 stockfish`. Windows may show a "protected your PC"
notice because releases are not code-signed yet. See
[verifying a download](docs/troubleshooting.md#verifying-a-download).

## Documentation

| Guide | What is in it |
| --- | --- |
| [Using NeoChess](docs/using-neochess.md) | Controls, playing, reviewing a game, settings |
| [Game library and opening book](docs/game-library.md) | Saving games, search, importing and downloading databases, PGN and FEN, the book |
| [The engines](docs/engine.md) | Stockfish and Leela Chess Zero (GPU): where NeoChess finds them, the in-app download, the `UciEngine` API, Linux and macOS |
| [Development](docs/development.md) | Building from source, tests, project layout, releases, code signing |
| [Troubleshooting](docs/troubleshooting.md) | Common problems and verifying a download |

## Build from source

You need [Godot 4.7.2](https://godotengine.org/download) (the standard build, not
.NET).

```powershell
git clone https://github.com/amirsdream/NeoChess.git
cd NeoChess
./dev/fetch_stockfish.ps1     # optional: puts Stockfish in bin/
godot --path .                # or add --editor to open the editor
./tests/run_tests.ps1         # headless test suite
```

More in [Development](docs/development.md).

## Credits and licenses

- NeoChess source code: [MIT](LICENSE). Third-party notices are in
  [THIRD_PARTY.md](THIRD_PARTY.md).
- [Stockfish](https://stockfishchess.org): GNU GPL v3, by the Stockfish
  developers. Bundled or downloaded as a separate program, never linked in.
- Chess piece drawings: the Cburnett set by Colin M. L. Burnett, triple-licensed
  under the GFDL, BSD and GPL. NeoChess recolours the outlines at run time. See
  [`pieces/CREDITS.txt`](pieces/CREDITS.txt).
- [godot-sqlite](https://github.com/2shady4u/godot-sqlite) by Marc Vincent (MIT)
  and [SQLite](https://sqlite.org) (public domain) store the game library.
- Game databases you download are the work of their publishers. The Lichess Elite
  database is by nikonoel and is made of lichess.org games (CC0).
- Built with [Godot Engine](https://godotengine.org) (MIT).
