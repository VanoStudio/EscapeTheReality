extends SceneTree

func _init() -> void:
	print("=== RUNNING TEST SUITE ===")
	var passed: int = 0
	var failed: int = 0
	
	var tests: Array[Callable] = [
		Callable(self, "test_dummy")
	]
	
	for test in tests:
		var test_name: String = test.get_method()
		var result: String = test.call()
		if result == "":
			print("[PASS] " + test_name)
			passed += 1
		else:
			print("[FAIL] " + test_name + " - " + result)
			failed += 1
			
	print("=== RESULTS: %d PASSED, %d FAILED ===" % [passed, failed])
	if failed > 0:
		quit(1)
	else:
		quit(0)

func test_dummy() -> String:
	if 1 + 1 != 2:
		return "Basic math failed"
	return ""
