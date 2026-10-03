extends SceneTree

# Shared base for the test scripts. Each test extends this file and overrides
# run(). Failures are printed; the process exits with code 1 if any check fails.

var failures := 0
var checks := 0
var verbose := false


func _init() -> void:
	verbose = "--verbose" in OS.get_cmdline_user_args()
	call_deferred("_start")


func _start() -> void:
	await run()
	var label: String = get_script().resource_path.get_file()
	print("%s: %d checks, %d failed" % [label, checks, failures])
	quit(1 if failures > 0 else 0)


func run() -> void:
	pass


func expect(name: String, got, expected) -> void:
	checks += 1
	if typeof(got) != typeof(expected) and not (_is_number(got) and _is_number(expected)):
		failures += 1
		print("FAIL %s: got %s (%s) expected %s (%s)" % [name, str(got), type_string(typeof(got)), str(expected), type_string(typeof(expected))])
	elif got != expected:
		failures += 1
		print("FAIL %s: got %s expected %s" % [name, str(got), str(expected)])
	elif verbose:
		print("ok   %s" % name)


func expect_true(name: String, condition: bool, detail: String = "") -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL %s %s" % [name, detail])
	elif verbose:
		print("ok   %s" % name)


func expect_near(name: String, got: float, expected: float, tolerance: float = 0.001) -> void:
	expect_true(name, absf(got - expected) <= tolerance, "(got %f expected %f)" % [got, expected])


func skip(message: String) -> void:
	print("SKIP %s" % message)


func _is_number(value) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
