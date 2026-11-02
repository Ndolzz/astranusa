extends SceneTree

## Suite LG: pengujian LogService (CONFIG-INPUT-LOG-SPEC bagian 6, kasus
## LG-01 s.d. LG-08; CORE-FRAMEWORK-IMPLEMENTATION-TEST-SPEC bagian 2).
## Setiap kasus memakai direktori user:// tersendiri agar berkas satu kasus
## tidak mencemari kasus lain; layanan diinstansiasi langsung dari skripnya
## tanpa bergantung pada autoload sebagai bukti isolasi (bagian 15 nomor 1).
## Jalankan headless dari root proyek game/:
## godot --headless --script res://tests/core_log_tests.gd


const LOG_SERVICE_PATH := "res://src/core/log_service.gd"
const TestLib := preload("res://tests/core_test_lib.gd")
const AUTO_LINES := 160
const ROTATION_FILL_BYTES := 600000


func _initialize() -> void:
	var lib := TestLib.new("core_log_tests")
	_lg_01_level_filtering(lib)
	_lg_02_line_format(lib)
	_lg_03_explicit_flush_and_limit(lib)
	_lg_04_buffer_prune_marker(lib)
	_lg_05_rotation_three_files(lib)
	_lg_06_writes_only_in_logs_dir(lib)
	_lg_07_init_failure_fatal(lib)
	_lg_08_fileless_mode(lib)
	var failures := lib.report()
	quit(1 if failures > 0 else 0)


func _new_service() -> Variant:
	var script: Variant = load(LOG_SERVICE_PATH)
	return script.new()


func _read_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var content := file.get_as_text()
	file.close()
	return content


func _write_file(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(content)
	file.close()


func _remove_dir_with_files(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for entry in dir.get_files():
		dir.remove(entry)
	var parent := DirAccess.open("user://")
	if parent != null:
		parent.remove(dir_path.trim_prefix("user://").trim_suffix("/"))


func _lg_01_level_filtering(lib) -> void:
	var svc: Variant = _new_service()
	var init_result: Dictionary = svc.initialize("user://logs-lg01/", "WARN")
	lib.assert_status(init_result, "ok", "LG-01", "inisialisasi sukses dengan tingkat WARN")
	svc.debug("SuiteLG", "baris debug")
	svc.info("SuiteLG", "baris info")
	svc.warn("SuiteLG", "baris warn")
	svc.error("SuiteLG", "baris error")
	lib.assert_status(svc.flush(), "ok", "LG-01", "siraman eksplisit berhasil")
	var content := _read_file("user://logs-lg01/astranusa.log")
	lib.assert_false(content.contains("baris debug"), "LG-01", "DEBUG tersaring pada tingkat WARN")
	lib.assert_false(content.contains("baris info"), "LG-01", "INFO tersaring pada tingkat WARN")
	lib.assert_true(content.contains("baris warn"), "LG-01", "WARN lolos penyaringan")
	lib.assert_true(content.contains("baris error"), "LG-01", "ERROR selalu lolos penyaringan")
	svc.set_level("DEBUG")
	lib.assert_eq(svc.current_level(), "DEBUG", "LG-01", "set_level menerima tingkat sah")
	svc.debug("SuiteLG", "debug setelah setel")
	lib.assert_status(svc.flush(), "ok", "LG-01", "siraman kedua berhasil")
	content = _read_file("user://logs-lg01/astranusa.log")
	lib.assert_true(
		content.contains("debug setelah setel"), "LG-01", "DEBUG lolos setelah set_level"
	)
	svc.set_level("TIDAK_SAH")
	lib.assert_eq(
		svc.current_level(), "DEBUG", "LG-01", "set_level tidak sah ditolak tanpa efek"
	)
	svc.free()


func _lg_02_line_format(lib) -> void:
	var svc: Variant = _new_service()
	svc.initialize("user://logs-lg02/", "DEBUG")
	svc.info("SuiteLG", "pesan berformat")
	svc.flush()
	var lines := _read_file("user://logs-lg02/astranusa.log").split("\n")
	var line: String = lines[0] if lines.size() > 0 else ""
	var parts := line.split(" ")
	lib.assert_eq(parts[0].length(), 19, "LG-02", "cap waktu ISO-8601 UTC 19 karakter")
	lib.assert_true(parts[0].contains("T"), "LG-02", "cap waktu memuat pemisah tanggal-waktu")
	lib.assert_eq(parts[1], "INFO", "LG-02", "tingkat tercantum pada kolom kedua")
	lib.assert_eq(parts[2], "[SuiteLG]", "LG-02", "modul tercantum dalam kurung siku")
	lib.assert_eq(parts[3], "pesan", "LG-02", "pesan menyusul setelah modul")
	svc.free()


func _lg_03_explicit_flush_and_limit(lib) -> void:
	var svc: Variant = _new_service()
	svc.initialize("user://logs-lg03/", "DEBUG")
	svc.info("SuiteLG", "satu baris awal")
	var early := _read_file("user://logs-lg03/astranusa.log")
	lib.assert_eq(early, "", "LG-03", "buffer menahan baris sebelum siraman")
	lib.assert_status(svc.flush(), "ok", "LG-03", "flush eksplisit menyiram buffer")
	svc.info("SuiteLG", "baris kedua")
	var after := _read_file("user://logs-lg03/astranusa.log")
	lib.assert_false(after.contains("baris kedua"), "LG-03", "baris baru menunggu siraman berikut")
	var written := 0
	while written < AUTO_LINES:
		svc.info("SuiteLG", "baris otomatis %d" % written)
		written += 1
	var content := _read_file("user://logs-lg03/astranusa.log")
	lib.assert_true(
		content.contains("baris otomatis 0"), "LG-03", "siraman otomatis menulis baris antrean awal"
	)
	lib.assert_true(
		content.contains("baris kedua"), "LG-03", "siraman otomatis menyiram seluruh antrean"
	)
	lib.assert_true(
		content.length() > 4096, "LG-03", "batas buffer 4 KB memicu siraman otomatis"
	)
	svc.free()


func _lg_04_buffer_prune_marker(lib) -> void:
	var svc: Variant = _new_service()
	svc.initialize("user://logs-lg04/", "DEBUG")
	svc.info("SuiteLG", "baris sebelum kegagalan")
	_remove_dir_with_files("user://logs-lg04/")
	lib.assert_status(svc.flush(), "error", "LG-04", "siraman gagal setelah berkas hilang")
	lib.assert_eq(svc.file_mode_status(), "fileless", "LG-04", "mode tanpa berkas aktif")
	var written := 0
	while written < AUTO_LINES:
		svc.info("SuiteLG", "baris pangkas %d" % written)
		written += 1
	var buffer: Variant = svc._buffer
	var marker_seen := false
	for line in buffer:
		if str(line).contains("baris terpangkas"):
			marker_seen = true
	lib.assert_true(marker_seen, "LG-04", "penanda pemangkasan tercantum pada buffer")
	lib.assert_true(
		int(svc._total_pruned) > 0, "LG-04", "jumlah baris terpangkas tercatat"
	)
	svc.free()


func _lg_05_rotation_three_files(lib) -> void:
	var dir_path := "user://logs-lg05/"
	DirAccess.make_dir_recursive_absolute(dir_path)
	_write_file(dir_path + "astranusa.log", "a".repeat(ROTATION_FILL_BYTES))
	_write_file(dir_path + "astranusa.log.1", "isi log satu")
	_write_file(dir_path + "astranusa.log.2", "isi log dua")
	var svc: Variant = _new_service()
	var init_result: Dictionary = svc.initialize(dir_path, "DEBUG")
	lib.assert_status(init_result, "ok", "LG-05", "inisialisasi pada berkas aktif pra-isi")
	svc.info("SuiteLG", "baris pasca rotasi")
	var result: Dictionary = svc.flush()
	lib.assert_status(result, "ok", "LG-05", "siraman berhasil setelah rotasi")
	lib.assert_true(bool(result["rotated"]), "LG-05", "rotasi terjadi saat batas 512 KB terlampaui")
	var active := _read_file(dir_path + "astranusa.log")
	lib.assert_true(active.contains("baris pasca rotasi"), "LG-05", "berkas aktif baru memuat catatan")
	var rolled := _read_file(dir_path + "astranusa.log.1")
	lib.assert_eq(rolled.length(), ROTATION_FILL_BYTES, "LG-05", "isi aktif lama bergulir ke .log.1")
	lib.assert_eq(
		_read_file(dir_path + "astranusa.log.2"),
		"isi log satu",
		"LG-05",
		".log.1 lama bergulir ke .log.2"
	)
	var dir := DirAccess.open(dir_path)
	lib.assert_not_null(dir, "LG-05", "direktori rotasi dapat dibuka")
	if dir == null:
		return
	lib.assert_eq(dir.get_files().size(), 3, "LG-05", "maksimum tiga berkas setelah rotasi")
	lib.assert_false(
		_read_file(dir_path + "astranusa.log.2").contains("isi log dua"),
		"LG-05",
		"berkas terlama terhapus saat rotasi"
	)
	svc.free()


func _lg_06_writes_only_in_logs_dir(lib) -> void:
	var dir_path := "user://logs-lg06/"
	var svc: Variant = _new_service()
	svc.initialize(dir_path, "DEBUG")
	svc.info("SuiteLG", "penulisan hanya di direktori log")
	svc.flush()
	lib.assert_file_exists(
		dir_path + "astranusa.log", "LG-06", "berkas aktif berada di dalam direktori log"
	)
	lib.assert_false(
		FileAccess.file_exists("user://astranusa.log"),
		"LG-06",
		"tidak ada penulisan pada akar user://"
	)
	lib.assert_false(
		FileAccess.file_exists("user://saves/astranusa.log"),
		"LG-06",
		"tidak ada penulisan pada user://saves/"
	)
	lib.assert_false(
		DirAccess.dir_exists_absolute("res://logs/"), "LG-06", "tidak ada penulisan pada res://"
	)
	svc.free()


func _lg_07_init_failure_fatal(lib) -> void:
	_write_file("user://lg07-blocker", "bukan direktori")
	var svc: Variant = _new_service()
	var result: Dictionary = svc.initialize("user://lg07-blocker/anak/", "DEBUG")
	lib.assert_status(result, "fatal", "LG-07", "kegagalan inisialisasi direktori fatal boot")
	svc.free()
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.remove("lg07-blocker")


func _lg_08_fileless_mode(lib) -> void:
	var dir_path := "user://logs-lg08/"
	var svc: Variant = _new_service()
	var init_result: Dictionary = svc.initialize(dir_path, "DEBUG")
	lib.assert_status(init_result, "ok", "LG-08", "inisialisasi sukses sebelum kegagalan")
	svc.info("SuiteLG", "baris sebelum kegagalan")
	_remove_dir_with_files(dir_path)
	lib.assert_status(svc.flush(), "error", "LG-08", "kegagalan penulisan melaporkan status error")
	lib.assert_eq(svc.file_mode_status(), "fileless", "LG-08", "mode tanpa berkas dapat ditanyai")
	svc.warn("SuiteLG", "baris tanpa berkas")
	lib.assert_status(svc.flush(), "fileless", "LG-08", "siraman berikutnya tanpa berkas")
	svc.error("SuiteLG", "baris galat tetap dicerminkan")
	lib.assert_eq(
		svc.file_mode_status(), "fileless", "LG-08", "layanan tetap berjalan tanpa berkas"
	)
	svc.free()
