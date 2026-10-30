class_name AppVersion
extends RefCounted

## Pembaca dan validator metadata versi aplikasi.
## Sumber kebenaran versi adalah res://version.json (keputusan P-004).


const VERSION_FILE := "res://version.json"
const SEMVER_PATTERN := "^[0-9]+\\.[0-9]+\\.[0-9]+$"


## Mengembalikan metadata versi dengan kunci "code" (int), "name" (String),
## dan "valid" (bool). Metadata tidak valid menghasilkan valid bernilai false.
static func load_version() -> Dictionary:
	var parsed := _read_json(VERSION_FILE)
	if parsed.is_empty():
		return {"code": 0, "name": "", "valid": false}
	var version_name := str(parsed.get("versionName", ""))
	var version_code := int(parsed.get("versionCode", 0))
	var is_valid := version_code > 0 and is_valid_semver(version_name)
	return {"code": version_code, "name": version_name, "valid": is_valid}


## Memeriksa apakah sebuah string mengikuti semantic versioning MAJOR.MINOR.PATCH.
static func is_valid_semver(value: String) -> bool:
	var regex := RegEx.new()
	if regex.compile(SEMVER_PATTERN) != OK:
		push_error("Pola semantic versioning gagal dikompilasi.")
		return false
	return regex.search(value) != null


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Berkas versi tidak ditemukan: %s" % path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("Berkas versi bukan JSON yang valid: %s" % path)
		return {}
	if not parsed is Dictionary:
		push_error("Berkas versi harus berupa objek JSON: %s" % path)
		return {}
	return parsed
