class_name BookQuery
extends Node

# Looks up the opening book (what was played after a line of moves) on a
# worker thread with its own database connection, so large libraries never
# freeze the window. Asking again while a lookup runs keeps only the latest
# question.

signal answered(key: String, rows: Array)

var db_path := ""
var busy := false

var _thread: Thread
var _next := {}
var _active_key := ""


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


# key identifies the question (it is returned with the answer).
func ask(key: String, line: PackedStringArray, source_ids: Array) -> void:
	_next = {"key": key, "line": line, "sources": source_ids}
	if not busy:
		_launch()


func _launch() -> void:
	if _next.is_empty():
		return
	var job := _next
	_next = {}
	busy = true
	_active_key = str(job["key"])
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	_thread = Thread.new()
	_thread.start(_work.bind(job, db_path))


func _work(job: Dictionary, path: String) -> void:
	var rows: Array = []
	var store := GameStore.new()
	if store.open(path):
		rows = store.explorer(job["line"] as PackedStringArray, job["sources"] as Array)
		store.close()
	_finish.call_deferred(str(job["key"]), rows)


func _finish(key: String, rows: Array) -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	busy = false
	if _next.is_empty():
		answered.emit(key, rows)
	else:
		_launch()
