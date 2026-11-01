class_name CoreTestLib
extends RefCounted

## Pustaka assertion dan pelaporan bersama untuk seluruh suite pengujian core
## SDD-02 (CORE-FRAMEWORK-IMPLEMENTATION-TEST-SPEC bagian 3). Setiap suite
## membuat satu instansi, menegaskan hasil per kasus, lalu memanggil report()
## untuk menentukan kode keluar proses headless.


var _suite_name := ""
var _failures: Array[String] = []
var _checks := 0


func _init(suite_name: String) -> void:
	_suite_name = suite_name


func assert_true(condition: bool, case_id: String, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [case_id, message])


func assert_false(condition: bool, case_id: String, message: String) -> void:
	assert_true(not condition, case_id, message)


func assert_eq(actual: Variant, expected: Variant, case_id: String, message: String) -> void:
	_checks += 1
	if actual != expected:
		_failures.append(
			"[%s] %s (diharapkan: %s, diperoleh: %s)"
			% [case_id, message, str(expected), str(actual)]
		)


func assert_not_null(value: Variant, case_id: String, message: String) -> void:
	assert_true(value != null, case_id, message)


func assert_between(
	value: float, low: float, high: float, case_id: String, message: String
) -> void:
	_checks += 1
	if value < low or value > high:
		_failures.append(
			"[%s] %s (diharapkan di rentang %s..%s, diperoleh: %s)"
			% [case_id, message, str(low), str(high), str(value)]
		)


func assert_file_exists(path: String, case_id: String, message: String) -> void:
	assert_true(FileAccess.file_exists(path), case_id, "%s: %s" % [message, path])


func assert_status(
	result: Dictionary, expected: String, case_id: String, message: String
) -> void:
	assert_eq(str(result.get("status", "")), expected, case_id, message)


func report() -> int:
	if _failures.is_empty():
		print("%s PASSED (%d checks)" % [_suite_name.to_upper(), _checks])
		return 0
	for failure in _failures:
		printerr("FAIL: %s" % failure)
	printerr(
		"%s FAILED (%d checks, %d gagal)" % [_suite_name.to_upper(), _checks, _failures.size()]
	)
	return _failures.size()
