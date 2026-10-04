# Third-party notices

NeoChess itself is MIT licensed (see `LICENSE`). It uses or downloads the following.

| Component | License | How it is used |
| --- | --- | --- |
| [Stockfish](https://stockfishchess.org) 19 | GPL v3 | Separate program. Downloaded at run time, or bundled beside `NeoChess.exe` in release zips with its `Copying.txt` and `AUTHORS`. Not linked into NeoChess. Source: https://github.com/official-stockfish/Stockfish |
| Cburnett chess piece drawings (`pieces/`) by Colin M. L. Burnett | GFDL, BSD or GPL (your choice) | Recolored outlines drawn at run time. See `pieces/CREDITS.txt`. |
| [Godot Engine](https://godotengine.org) 4.7 | MIT | The game engine, embedded in `NeoChess.exe`. Godot's own third-party notices apply: https://godotengine.org/license |
| [godot-sqlite](https://github.com/2shady4u/godot-sqlite) 4.9 (`addons/godot-sqlite/`) | MIT | GDExtension that gives Godot access to SQLite. The native library (`libgdsqlite*.dll`) ships beside `NeoChess.exe`. [SQLite](https://sqlite.org) itself is in the public domain. |
| [Lichess Elite database](https://database.nikonoel.fr) by nikonoel | CC0 (games from lichess.org) | Optional download of game files. Nothing is bundled. |
