# Development

- [Building from source](#building-from-source)
- [Tests](#tests)
- [Project layout](#project-layout)
- [Release build](#release-build)
- [Continuous integration and releases](#continuous-integration-and-releases)
- [Screenshots](#screenshots)
- [Code signing](#code-signing)
- [Contributing](#contributing)

## Building from source

You need [Godot 4.7.2](https://godotengine.org/download) (the standard build, not
.NET) and, to export, the export templates for your target platform.

```powershell
git clone https://github.com/amirsdream/NeoChess.git
cd NeoChess

# Optional: get Stockfish into bin/ so the game has an engine straight away.
./dev/fetch_stockfish.ps1

# Run from the editor
godot --path . --editor
# or run the game directly
godot --path .
```

You can skip the fetch step and use the in-app [download](engine.md#download-card)
instead. The first time you open the project, run `godot --headless --import` (or
open it in the editor) so the `class_name` scripts are registered.

## Tests

```powershell
./tests/run_tests.ps1                  # everything
./tests/run_tests.ps1 -Filter uci      # one file
./tests/run_tests.ps1 -VerboseChecks   # list every passing check
```

The script finds Godot from `-Godot <path>`, then `$env:GODOT`, then `PATH`. On
Linux and macOS use `sh tests/run_tests.sh [filter]` (set `GODOT` to the binary).

| File | What it covers |
| --- | --- |
| `test_rules.gd` | Perft against the standard test positions, castling, en passant, pins, mate |
| `test_chess_extra.gd` | FEN, promotion, draws, repetition, castling rules, SAN, cloning |
| `test_pgn.gd` | PGN export and import (comments, variations, castling, promotion, errors), FEN validation |
| `test_uci.gd` | `go` commands, option clamping, parsing `info` and `option` lines |
| `test_engine_setup.gd` | Per-platform downloads and lookup, zip and tar.gz extraction, executable checks (no network) |
| `test_appearance.gd` | Every theme is complete and every palette meets contrast targets |
| `test_smoke.gd` | Loads the real scene and plays, undoes and restarts a game, imports and exports |
| `test_store.gd` | The SQLite library: reading PGN fast, saving, searching, the explorer, threads, damaged files and library upgrades |
| `test_library.gd` | The library in the app: saving games, the window, background imports (PGN, zip, cancel), the opening book |
| `test_engine.gd` | `UciEngine` against a real Stockfish: handshake, options, MultiPV, stop and replace, shutdown, reviewing a game and the Live switch; skipped if no engine is installed |

## Project layout

```text
scenes/main.tscn          the single scene
scripts/main.gd           layout, game flow, settings, engine control
scripts/chess_game.gd     rules: moves, check, FEN, SAN, draws, perft
scripts/pgn.gd            PGN import and export
scripts/pgn_reader.gd     fast, forgiving PGN reader for big databases
scripts/game_store.gd     the SQLite library: games, collections, search, opening explorer
scripts/game_importer.gd  background import of PGN files and zips
scripts/library_view.gd   the game library window
scripts/book_query.gd     opening book lookups on a worker thread
scripts/database_downloader.gd  downloads a game database
scripts/result_bar.gd     the win/draw/loss bar in the opening book
scripts/board_view.gd     board drawing, animation, eval bar, last-move arrow
scripts/uci_engine.gd     a running UCI engine: process, searches, analysis, shutdown
scripts/stockfish_uci.gd  UCI commands and parsing of engine output (pure functions)
scripts/engine_setup.gd   engine lookup per platform, zip and tar.gz extraction, checks
scripts/engine_installer.gd  the download itself
scripts/appearance.gd     board and piece themes, app palette from a board
scripts/piece_art.gd      recolours the piece outlines per piece set
addons/godot-sqlite/      SQLite for Godot (native libraries, MIT)
dev/                      fetch, build, screenshot and benchmark scripts
docs/                     this documentation and its pictures
tests/                    headless test suite
```

### The library under the hood

- `GameStore` keeps `sources` (collections) and `games`. A game is unique per
  collection by a hash of its players, date, result and moves.
- Each game stores its first 24 plies as `opening_line`, which is how the book
  looks up positions by move order.
- Sort orders match database indexes (`date`, `MAX(white_elo, black_elo)`,
  `plies`), so a page of 100 comes straight from an index instead of sorting
  every row. Text search is a table scan.
- Searches, imports and book lookups run on worker threads that each open their
  own connection (WAL mode) and hand results to the main thread with
  `call_deferred`. A newer request replaces an older one.
- `PRAGMA user_version` holds the schema version. Opening an older library
  upgrades it; a newer one is refused.

### Pitfalls worth knowing

- In exported (release) builds a string literal such as `"\ufeff"` compiled to an
  empty string, which made `begins_with` always true and dropped the first
  character of every PGN line. Build such characters at run time with
  `char(0xFEFF)`.
- `StreamPeerGZIP` needs a zlib header, so it cannot read raw deflate data.
- `godot --headless --import` is needed after adding a `class_name` script.

## Release build

```powershell
./dev/build.ps1 -Zip                         # host OS: Windows or Linux, with Stockfish
./dev/build.ps1 -Target Windows -Zip         # Windows package
./dev/build.ps1 -Target Linux -Zip           # Linux package
./dev/build.ps1 -NoEngine                    # a small build that offers the in-app download
```

If you ship the engine, keep `Copying.txt`, `AUTHORS` and `STOCKFISH.txt` beside
it. `build.ps1` does this for you. The export also places the SQLite library next
to the binary (`libgdsqlite.*.template_release.x86_64.dll` or `.so`). Close a
running build before exporting, or the export cannot replace it.

To check a build, run `NeoChess.exe -- --check-library=report.txt` (or
`./NeoChess.x86_64 -- --check-library=report.txt` on Linux). It writes a line
saying whether the library works and whether the PGN readers behave in a release
build, then quits.

## Continuous integration and releases

GitHub Actions does the same work on clean Windows and Linux runners:

- **CI** (`.github/workflows/ci.yml`) runs on every push to `main` and on pull
  requests. It installs Godot (checksum-verified), fetches Stockfish, runs the
  whole test suite on Windows and Linux, then builds both packages and checks
  that the bundled engine starts. The builds are kept as 7 day artifacts.
- **Release** (`.github/workflows/release.yml`) runs when you push a version tag.
  It repeats the tests, stamps the version into the Windows exe, and publishes a
  GitHub release with `NeoChess-<version>-windows-x64.zip`,
  `NeoChess-<version>-linux-x64.zip`, and their `.sha256` files.

To ship a version:

```powershell
git tag v1.2.0
git push origin v1.2.0
```

You can also start **Release** by hand from the Actions tab to get the zips as
artifacts without publishing anything.

## Screenshots

The pictures in `docs/images` are made by the game itself:

```powershell
./dev/screenshots.ps1
```

It runs NeoChess with the hidden `--shot` switch (sample game, sample engine
lines, then it saves a picture and quits) and a made-up sample library from
`dev/make_demo_library.gd`, so no personal games appear. It opens real windows for
a few seconds, so it needs a desktop session. Useful switches, after `--`:

| Switch | Shows |
| --- | --- |
| `--shot` | Required. Sample game, saves `.tools/preview.png` |
| `--board=N` | Board theme number (0 Walnut, 2 Ocean, …) |
| `--review` | Reviewing a position with analysis |
| `--book`, `--library=<db>` | The opening book, using that database |
| `--library` | The library window |
| `--settings` (`--play`) | Settings, Look page (or Play page) |
| `--newgame` | The choose-a-side card |
| `--setup` | The Stockfish download card |

## Code signing

Release builds are made by the public GitHub Actions workflow in this repository.
They are **not code-signed yet**, so Windows SmartScreen may show "Windows
protected your PC". Signing through the [SignPath Foundation](https://signpath.org)
is prepared in `release.yml` and `.signpath/` and switches on when the repository
has the SignPath settings.

Maintainers: apply for free open-source signing at
[signpath.org/apply](https://signpath.org/apply.html), add the `SIGNPATH_API_TOKEN`
repository secret, and set the repository variables `SIGNPATH_ORGANIZATION_ID`,
`SIGNPATH_PROJECT_SLUG` (default `NeoChess`) and `SIGNPATH_SIGNING_POLICY_SLUG`
(default `release-signing`). The next tagged release is then signed automatically.

## Contributing

Issues and pull requests are welcome. Run `./tests/run_tests.ps1` before sending a
change; CI runs the same tests. Keep new code covered by a test where it can be.
Commit messages follow [Conventional Commits](https://www.conventionalcommits.org)
(`feat:`, `fix:`, `docs:`, `test:`, `chore:`).
