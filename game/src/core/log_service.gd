extends Node

## LogService: pencatatan bertingkat dengan buffer memori dan log bergulir
## pada user://logs/ (LOGGING-SYSTEM-DESIGN; CONFIG-INPUT-LOG-SPEC bagian 4).
## Empat tingkat DEBUG, INFO, WARN, ERROR dengan penyaringan pada antarmuka
## (CFR-FR-029); antarmuka pencatatan hanya bekerja memori tanpa I/O langsung
## (CFR-NFR-005); siraman batch dipicu batas buffer 4 KB, pause, penutupan
## normal, dan flush() eksplisit; pemangkasan baris terlama dengan penanda
## saat siraman tidak mungkin; rotasi maksimum tiga berkas pada 512 KB
## (CFR-FR-030, keputusan OJ-4); kegagalan penulisan pasca boot memasukkan
## mode tanpa berkas yang dapat ditanyai (CFR-FR-031); kegagalan inisialisasi
## fatal boot (CFR-FR-002). Log hanya ditulis ke user://logs/ dan tidak
## pernah ke res:// maupun user://saves/ (requirement bagian 14 nomor 3).


const LEVEL_DEBUG := "DEBUG"
const LEVEL_INFO := "INFO"
const LEVEL_WARN := "WARN"
const LEVEL_ERROR := "ERROR"

const FILE_NAME := "astranusa.log"
const BUFFER_LIMIT_BYTES := 4096
const ROTATE_LIMIT_BYTES := 524288
const PRUNE_MARKER_FORMAT := "... %d baris terpangkas ..."
const MODULE_NAME := "LogService"

const LEVEL_ORDER := {
	LEVEL_DEBUG: 0,
	LEVEL_INFO: 1,
	LEVEL_WARN: 2,
	LEVEL_ERROR: 3,
}


var _level := LEVEL_INFO
var _initialized := false
var _file_mode := "ok"
var _logs_dir := "user://logs/"
var _active_path := ""
var _buffer: Array[String] = []
var _buffer_bytes := 0
var _total_pruned := 0


func initialize(logs_dir: String, base_level: String) -> Dictionary:
	_apply_level(base_level)
	_logs_dir = _normalize_dir(logs_dir)
	_active_path = _logs_dir + FILE_NAME
	var dir_err := DirAccess.make_dir_recursive_absolute(_logs_dir)
	if dir_err != OK and not DirAccess.dir_exists_absolute(_logs_dir):
		_mirror_line(
			"Inisialisasi gagal: direktori %s tidak dapat dibuat (%d)." % [_logs_dir, dir_err]
		)
		return {"status": "fatal"}
	if not FileAccess.file_exists(_active_path):
		var probe := FileAccess.open(_active_path, FileAccess.WRITE)
		if probe == null:
			_mirror_line("Inisialisasi gagal: berkas %s tidak dapat dibuat." % _active_path)
			return {"status": "fatal"}
		probe.close()
	_initialized = true
	_file_mode = "ok"
	return {"status": "ok"}


func debug(module: String, message: String) -> void:
	_record(LEVEL_DEBUG, module, message)


func info(module: String, message: String) -> void:
	_record(LEVEL_INFO, module, message)


func warn(module: String, message: String) -> void:
	_record(LEVEL_WARN, module, message)


func error(module: String, message: String) -> void:
	_record(LEVEL_ERROR, module, message)


func set_level(level: String) -> void:
	if not LEVEL_ORDER.has(level):
		push_error("LogService: set_level ditolak, tingkat tidak sah (%s)." % level)
		_mirror_line("LogService: set_level ditolak, tingkat tidak sah (%s)." % level)
		return
	_level = level


func current_level() -> String:
	return _level


func flush() -> Dictionary:
	if not _initialized:
		return {"status": "error", "rotated": false}
	if _file_mode == "fileless":
		return {"status": "fileless", "rotated": false}
	if _buffer.is_empty():
		return {"status": "ok", "rotated": false}
	var rotated := false
	if _active_size() > ROTATE_LIMIT_BYTES:
		rotated = _rotate_files()
		if not rotated:
			_mirror_line("Rotasi log gagal; dicoba ulang pada siraman berikutnya.")
	var file := FileAccess.open(_active_path, FileAccess.READ_WRITE)
	if file == null:
		_enter_fileless()
		return {"status": "error", "rotated": false}
	file.seek_end()
	for line in _buffer:
		file.store_line(line)
	file.close()
	_buffer.clear()
	_buffer_bytes = 0
	return {"status": "ok", "rotated": rotated}


func file_mode_status() -> String:
	return _file_mode


func _record(level: String, module: String, message: String) -> void:
	if LEVEL_ORDER[level] < LEVEL_ORDER[_level]:
		return
	var line := "%s %s [%s] %s" % [
		Time.get_datetime_string_from_system(true), level, module, message
	]
	_store(level, line)


func _store(level: String, line: String) -> void:
	_mirror(level, line)
	if not _initialized:
		return
	_buffer.append(line)
	_buffer_bytes += line.length() + 1
	if _buffer_bytes <= BUFFER_LIMIT_BYTES:
		return
	flush()
	if _file_mode == "fileless":
		_prune_oldest()


func _prune_oldest() -> void:
	var pruned := 0
	while _buffer_bytes > BUFFER_LIMIT_BYTES and not _buffer.is_empty():
		var oldest: String = _buffer.pop_front()
		_buffer_bytes -= oldest.length() + 1
		pruned += 1
	if pruned <= 0:
		return
	_total_pruned += pruned
	var marker := PRUNE_MARKER_FORMAT % _total_pruned
	_buffer.push_front(marker)
	_buffer_bytes += marker.length() + 1
	_mirror_line(marker)


func _mirror(level: String, line: String) -> void:
	if OS.is_debug_build() or level == LEVEL_ERROR:
		print(line)


func _mirror_line(line: String) -> void:
	print(line)


func _apply_level(level: String) -> void:
	if LEVEL_ORDER.has(level):
		_level = level
		return
	push_error("LogService: tingkat tidak sah (%s); tingkat aktif dipertahankan." % level)
	_mirror_line("LogService: tingkat tidak sah (%s); tingkat aktif dipertahankan." % level)


func _normalize_dir(logs_dir: String) -> String:
	if logs_dir.ends_with("/"):
		return logs_dir
	return logs_dir + "/"


func _active_size() -> int:
	if not FileAccess.file_exists(_active_path):
		return 0
	var file := FileAccess.open(_active_path, FileAccess.READ)
	if file == null:
		return 0
	var size := file.get_length()
	file.close()
	return size


func _rotate_files() -> bool:
	var dir := DirAccess.open(_logs_dir)
	if dir == null:
		return false
	var rolled := FILE_NAME + ".1"
	var rolled_old := FILE_NAME + ".2"
	if dir.file_exists(rolled_old):
		dir.remove(rolled_old)
	if dir.file_exists(rolled):
		if dir.rename(rolled, rolled_old) != OK:
			return false
	if dir.rename(FILE_NAME, rolled) != OK:
		return false
	var active := FileAccess.open(_active_path, FileAccess.WRITE)
	if active == null:
		return false
	active.close()
	return true


func _enter_fileless() -> void:
	if _file_mode == "fileless":
		return
	_file_mode = "fileless"
	_mirror_line(
		"Mode tanpa berkas: penulisan log gagal; catatan dicerminkan ke keluaran standar."
	)
