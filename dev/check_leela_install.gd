extends SceneTree

# Developer check of the real Leela download: runs the installer against the
# network, then plays one search with the installed copy. It writes into the
# user data folder (engine/leela), so remove that folder afterwards if you want
# to see the download card again.
#
#   godot --headless --path . -s dev/check_leela_install.gd

const Rules = preload("res://scripts/chess_game.gd")

var result := {"done": false, "path": "", "error": ""}
var bests: Array = []
var failure := ""


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	var installer := LeelaInstaller.new()
	root.add_child(installer)
	var last := {"step": ""}
	installer.finished.connect(func(path: String, error: String) -> void:
		result = {"done": true, "path": path, "error": error}
	)
	installer.progress.connect(func(received: int, total: int) -> void:
		if installer.step_text != last_step:
			last_step = installer.step_text
			print(last_step)
		if randi() % 40 == 0:
			print("   ", EngineSetup.progress_text(received, total))
	)
	installer.start()
	while not bool(result["done"]):
		await process_frame
		OS.delay_msec(20)
	print("finished: path='%s' error='%s'" % [result["path"], result["error"]])
	if str(result["error"]) != "":
		quit(1)
		return
	print("network present: ", LeelaSetup.has_network())
	var engine := UciEngine.new()
	root.add_child(engine)
	engine.best_move.connect(func(m: String) -> void: bests.append(m))
	engine.failed.connect(func(m: String) -> void: failure = m)
	engine.start(str(result["path"]))
	var game := Rules.new()
	var settings := StockfishUci.engine_settings({"multipv": 3, "threads": 2})
	settings.merge(LeelaSetup.uci_settings(str(result["path"])), true)
	print("settings: ", settings)
	engine.search(game.to_fen(), {"movetime": 1500}, settings)
	var waited := 0
	while bests.is_empty() and failure == "" and waited < 6000:
		await process_frame
		OS.delay_msec(20)
		waited += 1
	print("engine: ", engine.engine_name, "  best: ", bests, "  failure: ", failure)
	engine.shutdown()
	quit(0 if not bests.is_empty() else 1)
