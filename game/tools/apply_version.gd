extends SceneTree

## Menyinkronkan metadata versi dari res://version.json ke res://export_presets.cfg
## sebelum export APK dijalankan oleh CI (APK-COMPATIBILITY-SPEC bagian 7).
## Dijalankan headless dari root proyek game/:
## godot --headless --script res://tools/apply_version.gd
## Variabel lingkungan ASTRANUSA_DEBUG_KEYSTORE (opsional) berisi path keystore
## debug yang dipasang pada opsi keystore/debug preset export.


const VERSION_FILE := "res://version.json"
const PRESETS_FILE := "res://export_presets.cfg"
const APPLICATION_ID := "com.ndolzz.astranusa"
const KEYSTORE_ENV := "ASTRANUSA_DEBUG_KEYSTORE"
const KEYSTORE_USER := "androiddebugkey"
const KEYSTORE_PASSWORD := "android"
const ANDROID_PLATFORM := "Android"
const APP_VERSION := preload("res://src/core/app_version.gd")


func _initialize() -> void:
	quit(_apply())


func _apply() -> int:
	var version := APP_VERSION.load_version()
	if not version["valid"]:
		push_error("Metadata versi tidak valid; sinkronisasi preset dibatalkan.")
		return 1
	var presets := ConfigFile.new()
	if presets.load(PRESETS_FILE) != OK:
		push_error("Gagal membaca export_presets.cfg.")
		return 1
	var android_section := _find_android_section(presets)
	if android_section.is_empty():
		push_error("Preset export Android tidak ditemukan.")
		return 1
	var options := android_section + ".options"
	if str(presets.get_value(options, "package/unique_name", "")) != APPLICATION_ID:
		push_error("applicationId tidak sesuai nilai yang dikunci: %s" % APPLICATION_ID)
		return 1
	presets.set_value(options, "version/code", int(version["code"]))
	presets.set_value(options, "version/name", str(version["name"]))
	var keystore_path := OS.get_environment(KEYSTORE_ENV)
	if not keystore_path.is_empty():
		presets.set_value(options, "keystore/debug", keystore_path)
		presets.set_value(options, "keystore/debug_user", KEYSTORE_USER)
		presets.set_value(options, "keystore/debug_password", KEYSTORE_PASSWORD)
	if presets.save(PRESETS_FILE) != OK:
		push_error("Gagal menulis export_presets.cfg.")
		return 1
	print(
		"Preset export tersinkron: versionCode=%d versionName=%s" % [version["code"], version["name"]]
	)
	return 0


func _find_android_section(presets: ConfigFile) -> String:
	for section in presets.get_sections():
		if str(presets.get_value(section, "platform", "")) == ANDROID_PLATFORM:
			return section
	return ""
