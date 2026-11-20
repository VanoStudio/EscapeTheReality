extends SceneTree

const M1Test = preload("res://tests/m1_test.gd")

func _init() -> void:
	print("=== RUNNING TEST SUITE ===")
	var passed: int = 0
	var failed: int = 0
	
	# Ensure GameState autoload exists in root for headless test runs
	var game_state = root.get_node_or_null("GameState")
	if game_state == null:
		var game_state_script = load("res://scripts/autoload/GameState.gd")
		game_state = game_state_script.new()
		game_state.name = "GameState"
		root.add_child(game_state)
	
	# M0 dummy test
	var dummy_err: String = test_dummy()
	if dummy_err == "":
		print("[PASS] test_dummy")
		passed += 1
	else:
		print("[FAIL] test_dummy - " + dummy_err)
		failed += 1
		
	# M1 test suite
	var m1_results: Dictionary = M1Test.run_all_tests(game_state)
	passed += m1_results["passed"]
	failed += m1_results["failed"]
	
	print("=== RESULTS: %d PASSED, %d FAILED ===" % [passed, failed])
	if failed > 0:
		quit(1)
	else:
		quit(0)

func test_dummy() -> String:
	if 1 + 1 != 2:
		return "Basic math failed"
	return ""
