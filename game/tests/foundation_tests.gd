extends SceneTree

## Test harness fondasi proyek (keputusan P-008).
## Harness menjalankan assertion nyata atas metadata versi, konfigurasi proyek,
## identitas export, struktur direktori, dan parsing seluruh skrip GDScript.
## Dijalankan headless dari root proyek game/:
## godot --headless --script res://tests/foundation_tests.gd
## Harness keluar dengan kode nol hanya jika seluruh pengujian lolos.


const APP_VERSION := preload("res://src/core/app_version.gd")
const PROJECT_FILE := "res://project.godot"
const PRESETS_FILE := "res://export_presets.cfg"
const MAIN_SCENE := "res://src/app/boot.tscn"
const EXPECTED_APPLICATION_ID := "com.ndolzz.astranusa"
const EXPECTED_GAME_NAME := "ASTRANUSA"
const EXPECTED_GODOT_FEATURE := "4.7"
const EXPECTED_RENDERER := "mobile"
const REQUIRED_DIRECTORIES := [
	"res://src",
	"res://src/core",
	"res://src/app",
	"res://assets",
	"res://tests",
	"res://tools",
]
const SCRIPT_SCAN_ROOTS := ["res://src", "res://tools", "res://tests"]


var _failures: Array[String] = []
var _checks := 0


func _initialize() -> void:
	_test_version_metadata()
	_test_project_configuration()
	_test_export_preset()
	_test_directory_structure()
	_test_script_parsing()
	if _failures.is_empty():
		print("FOUNDATION TESTS PASSED (%d checks)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: %s" % failure)
		printerr("FOUNDATION TESTS FAILED (%d checks, %d failed)" % [_checks, _failures.size()])
		quit(1)


func _test_version_metadata() -> void:
	var version := APP_VERSION.load_version()
	_check(version["valid"], "version.json harus valid (versionCode positif, versionName semver)")
	_check(APP_VERSION.is_valid_semver(str(version["name"])), "versionName harus semantic versioning")
	_check(int(version["code"]) > 0, "versionCode harus bilangan bulat positif")


func _test_project_configuration() -> void:
	var config := ConfigFile.new()
	if not _check(config.load(PROJECT_FILE) == OK, "project.godot harus dapat dibaca"):
		return
	_check(
		str(config.get_value("application", "config/name", "")) == EXPECTED_GAME_NAME,
		"Nama aplikasi harus %s" % EXPECTED_GAME_NAME
	)
	var features := config.get_value(
		"application", "config/features", PackedStringArray()
	) as PackedStringArray
	_check(
		EXPECTED_GODOT_FEATURE in features,
		"config/features harus memuat %s sesuai versi Godot terkunci" % EXPECTED_GODOT_FEATURE
	)
	_check(
		str(config.get_value("rendering", "renderer/rendering_method", "")) == EXPECTED_RENDERER,
		"Rendering method harus %s (D-003)" % EXPECTED_RENDERER
	)
	_check(
		int(config.get_value("display", "window/size/viewport_width", 0)) == 1280,
		"Viewport dasar lebar harus 1280"
	)
	_check(
		int(config.get_value("display", "window/size/viewport_height", 0)) == 720,
		"Viewport dasar tinggi harus 720"
	)
	_check(
		int(config.get_value("display", "window/handheld/orientation", -1)) == 0,
		"Orientasi harus landscape (P-010)"
	)
	_check(
		str(config.get_value("display", "window/stretch/mode", "")) == "canvas_items",
		"Stretch mode harus canvas_items (P-010)"
	)
	_check(
		str(config.get_value("display", "window/stretch/aspect", "")) == "expand",
		"Stretch aspect harus expand (P-010)"
	)
	_check(
		str(config.get_value("application", "run/main_scene", "")) == MAIN_SCENE,
		"Main scene harus %s" % MAIN_SCENE
	)
	_check(ResourceLoader.exists(MAIN_SCENE), "Berkas main scene harus tersedia")


func _test_export_preset() -> void:
	var presets := ConfigFile.new()
	if not _check(presets.load(PRESETS_FILE) == OK, "export_presets.cfg harus dapat dibaca"):
		return
	var version := APP_VERSION.load_version()
	var android_options := ""
	for section in presets.get_sections():
		if str(presets.get_value(section, "platform", "")) == "Android":
			android_options = section + ".options"
			break
	if not _check(not android_options.is_empty(), "Preset export Android harus tersedia"):
		return
	_check(
		str(presets.get_value(android_options, "package/unique_name", "")) == EXPECTED_APPLICATION_ID,
		"applicationId harus %s (P-003)" % EXPECTED_APPLICATION_ID
	)
	_check(
		int(presets.get_value(android_options, "version/code", 0)) == int(version["code"]),
		"version/code pada preset export harus sama dengan version.json (P-004)"
	)
	_check(
		str(presets.get_value(android_options, "version/name", "")) == str(version["name"]),
		"version/name pada preset export harus sama dengan version.json (P-004)"
	)
	_check(
		bool(presets.get_value(android_options, "architectures/arm64-v8a", false)),
		"Arsitektur arm64-v8a harus aktif pada preset export (P-009)"
	)
	_check(
		bool(presets.get_value(android_options, "architectures/armeabi-v7a", false)),
		"Arsitektur armeabi-v7a harus aktif pada preset export (P-009)"
	)


func _test_directory_structure() -> void:
	for directory in REQUIRED_DIRECTORIES:
		_check(DirAccess.open(directory) != null, "Direktori wajib harus tersedia: %s" % directory)


func _test_script_parsing() -> void:
	var script_paths: Array[String] = []
	for root in SCRIPT_SCAN_ROOTS:
		_collect_scripts(root, script_paths)
	_check(script_paths.size() > 0, "Skrip GDScript harus ditemukan pada direktori sumber")
	for path in script_paths:
		if path.get_file() == "foundation_tests.gd":
			# Harness ini tidak me-reload dirinya sendiri karena sedang dieksekusi.
			continue
		var resource: Resource = load(path)
		if not _check(resource != null, "Skrip harus dapat dimuat: %s" % path):
			continue
		if not _check(resource is GDScript, "Resource harus berupa GDScript: %s" % path):
			continue
		var script := resource as GDScript
		_check(script.reload() == OK, "Skrip harus lolos parsing tanpa error: %s" % path)


func _collect_scripts(dir_path: String, output: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			_collect_scripts(dir_path.path_join(entry), output)
		elif entry.ends_with(".gd"):
			output.append(dir_path.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()


func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(message)
	return condition
