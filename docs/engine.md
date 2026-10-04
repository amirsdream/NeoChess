# The Stockfish engine

NeoChess plays and analyses with [Stockfish](https://stockfishchess.org), the
strongest open-source chess engine. It runs Stockfish as a separate program and
talks to it over the standard UCI protocol.

- [Finding the engine](#finding-the-engine)
- [Download card](#download-card)
- [Licensing](#licensing)
- [The UciEngine API](#the-uciengine-api)
- [Linux and macOS](#linux-and-macos)

## Finding the engine

Release zips include `stockfish.exe` next to `NeoChess.exe`, so nothing needs to
be set up. Otherwise NeoChess looks for `stockfish.exe` (`stockfish` on Linux and
macOS) in this order:

1. The path saved in **Settings, Engine, Engine file**, if the file exists.
2. `bin\stockfish.exe` inside the project (development).
3. `stockfish.exe` or `bin\stockfish.exe` next to `NeoChess.exe`.
4. The copy NeoChess downloaded for you:
   `%APPDATA%\Godot\app_userdata\NeoChess\engine\stockfish.exe`.
5. On Linux and macOS only: a Stockfish installed on the system, such as
   `/usr/games/stockfish`, `/usr/bin/stockfish` or `/opt/homebrew/bin/stockfish`.

## Download card

When none of these exist and you play Stockfish, a card appears in the sidebar:

![Stockfish download card](images/download.png)

- **Download Stockfish 19** fetches the official build for your system, for
  example [`stockfish-windows-x86-64-universal.zip`](https://github.com/official-stockfish/Stockfish/releases/tag/sf_19)
  from the Stockfish GitHub release (about 80 MB). It unpacks the engine into
  your user folder, checks that it starts, and selects it. You can cancel while it
  downloads. The universal build picks the fastest instruction set your CPU
  supports.
- **Choose file** lets you point at a Stockfish you already have, for example a
  newer build from [stockfishchess.org/download](https://stockfishchess.org/download/).
- **Pass and play** works without any engine.

The same download button lives under **Settings, Engine**. Nothing is sent to
anyone except the request to GitHub, and nothing is installed outside the
NeoChess user folder.

## Licensing

Stockfish is licensed under the GPLv3, so the source repository keeps it out and
fetches it separately (`dev/fetch_stockfish.ps1`). Release zips ship it as a
separate program with its `Copying.txt`, `AUTHORS` and `STOCKFISH.txt` beside it.
Keep those files if you redistribute the engine. It is never linked into NeoChess.

## The UciEngine API

NeoChess starts Stockfish once and keeps it running, talking to it with Godot's
`OS.execute_with_pipe`. `UciEngine` (`scripts/uci_engine.gd`) is a small, reusable
API for any UCI engine:

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
  clamped to its limits, skipped if it does not have them, and sent only when they
  change. `ucinewgame` is sent when a game starts.
- It handles engines that never answer, that are not UCI engines at all, or that
  crash: the app shows a message instead of freezing. Engine processes are
  stopped when the app quits.

The pure functions that build UCI commands and parse `info` lines are in
`scripts/stockfish_uci.gd`, and the platform lookup and download are in
`scripts/engine_setup.gd` and `scripts/engine_installer.gd`.

## Linux and macOS

The game logic, the engine API, the platform-aware lookup and the download (the
Linux and macOS releases are `.tar.gz`, unpacked by NeoChess itself) contain no
Windows-specific code. Stockfish publishes builds for Linux (x86-64, arm64,
riscv64) and macOS. Run NeoChess from source with Godot 4.7 and either install
Stockfish with your package manager or use the in-app download. The SQLite
library ships for Linux and macOS too (`addons/godot-sqlite/bin`). Run the tests
with `sh tests/run_tests.sh`.

Packaged Linux and macOS builds are not published yet, and the platform paths
have been tested through the unit tests and on Windows only.
