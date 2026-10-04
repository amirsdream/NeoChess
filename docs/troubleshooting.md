# Troubleshooting

- [Engine problems](#engine-problems)
- [Game library problems](#game-library-problems)
- [Verifying a download](#verifying-a-download)

## Engine problems

- **"Stockfish was not found"**: use the **Download** button on the card, or
  **Choose file** (see [Finding the engine](engine.md#finding-the-engine)).
- **The download fails**: you will see the reason (offline, blocked, disk full).
  Try again, or download the zip from the
  [Stockfish release page](https://github.com/official-stockfish/Stockfish/releases/tag/sf_19)
  yourself and choose the `.exe` inside it.
- **The engine seems slow or loses time on a clock**: raise *Move overhead* under
  **Settings, Engine**.
- **No live lines**: switch the **Live** toggle on in the Engine analysis card.
  While you review a game, Live also decides whether Stockfish analyses the
  position you are viewing.

## Game library problems

- **"The game library is not available"**: the database library
  (`libgdsqlite.windows.template_release.x86_64.dll`) must sit next to
  `NeoChess.exe`. Unzip the whole release, not just the exe.
- **"Move 1. Event: is not a move"** or games that look like tag lines: your
  library holds games read wrongly by an early build. Open the library with the
  current version, which removes them once, then import the file again.
- **Review says a move is not legal**: that game is damaged in the library.
  Delete it there and import the file again.
- **An import added nothing**: the file was probably imported before (games are
  recognised and skipped), or it holds a chess variant. A file of some other
  kind is refused with a message.
- **The book is empty**: it needs games. Import a database or
  [download one](game-library.md#downloading-a-database), and pick a collection
  that has games for this opening.
- **Want to start over**: close NeoChess and delete `games.db` (and `games.db-wal`
  and `games.db-shm` if present) in `%APPDATA%\Godot\app_userdata\NeoChess`.

## Verifying a download

Every release includes a `.sha256` file. To check the zip:

```powershell
(Get-FileHash .\NeoChess-1.1.0-windows-x64.zip -Algorithm SHA256).Hash.ToLower()
# compare with the contents of NeoChess-1.1.0-windows-x64.zip.sha256
```

Release builds are made by the public GitHub Actions workflow in this repository
and are **not code-signed yet**. Windows SmartScreen may show "Windows protected
your PC" the first time. Choose **More info, Run anyway**, or build it yourself
from source (see [Development](development.md)). Code signing is prepared and
described under [Code signing](development.md#code-signing).
