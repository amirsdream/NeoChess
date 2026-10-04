extends SceneTree

# Developer benchmark: godot --headless --path . --script dev/bench_import.gd -- <file.zip|file.pgn>
# Imports into user://bench.db and prints timings. Not part of the test suite.

var importer: GameImporter
var started := 0
var db_path := "user://bench.db"


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: -- <file>")
		quit(2)
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(db_path))
	importer = GameImporter.new()
	root.add_child(importer)
	importer.finished.connect(_done)
	started = Time.get_ticks_msec()
	importer.start(args[0], "bench", ProjectSettings.globalize_path(db_path))
	var timer := Timer.new()
	timer.wait_time = 2.0
	root.add_child(timer)
	timer.timeout.connect(_tick)
	timer.start()


func _tick() -> void:
	print(importer.counters())


func _done(result: Dictionary) -> void:
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	print("done in %.1fs: %s" % [seconds, result])
	var store := GameStore.new()
	store.open(ProjectSettings.globalize_path(db_path))
	var t := Time.get_ticks_msec()
	var line := PackedStringArray(["e4"])
	print("explorer e4: ", store.explorer(line, []).slice(0, 4), " in %d ms" % (Time.get_ticks_msec() - t))
	t = Time.get_ticks_msec()
	print("search Carlsen: ", store.count({"text": "Carlsen"}), " in %d ms" % (Time.get_ticks_msec() - t))
	t = Time.get_ticks_msec()
	print("deep line: ", store.explorer(PackedStringArray(["e4", "e5", "Nf3", "Nc6", "Bb5", "a6"]), []).slice(0, 3), " in %d ms" % (Time.get_ticks_msec() - t))
	for sort in ["date", "oldest", "rating", "length"]:
		t = Time.get_ticks_msec()
		var page := store.search({"sort": sort}, 100, 0)
		var deep := store.search({"sort": sort}, 100, 200000)
		print("sort %s: first page %d ms, page 2000 %d ms (%d rows)" % [sort, Time.get_ticks_msec() - t, Time.get_ticks_msec() - t, page.size() + deep.size()])
	t = Time.get_ticks_msec()
	store.search({"text": "magnus", "result": "1-0"}, 100, 0)
	print("text+result search: %d ms" % (Time.get_ticks_msec() - t))
	t = Time.get_ticks_msec()
	store.count({})
	print("count all: %d ms" % (Time.get_ticks_msec() - t))
	store.close()
	quit()
