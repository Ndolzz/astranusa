extends Node

## AppBootstrap: orkestrator siklus hidup aplikasi (INITIALIZATION-LIFECYCLE-DESIGN).
## Menjalankan urutan boot sepuluh langkah secara eksplisit (CFR-FR-001),
## mengklasifikasikan kegagalan layanan kritis dan sekunder (CFR-FR-002),
## menjalankan penutupan normal (CFR-FR-003), dan memetakan notifikasi Android
## (CFR-INT-101 s.d. CFR-INT-104). Layanan diakses melalui nama autoload;
## pengujian menyuntikkan stub melalui _inject_services sesuai
## CORE-FRAMEWORK-IMPLEMENTATION-TEST-SPEC bagian 4.


const BOOT_READY := "ready"
const BOOT_FATAL := "fatal"

const LOGS_DIR := "user://logs/"
const LOG_LEVEL_DEBUG_BUILD := "INFO"
const LOG_LEVEL_RELEASE := "WARN"

const SAVE_SPACE_PROBE_PATH := "res://src/core/save_space_probe.gd"
const APP_STATE_PATH := "res://src/core/app_state.gd"
const RESOURCE_LOADER_PATH := "res://src/core/resource_loader.gd"

const APP_VERSION := preload("res://src/core/app_version.gd")

## Data action map bawaan internal pada SDD-02 (keputusan SP-6, P-028): dua aksi
## UI tanpa sumber berkas; sumber berkas konfigurasi menyusul SDD-03 tanpa
## mengubah antarmuka initialize InputService.
const BUILTIN_ACTION_CONFIG := {
	"ui_confirm": {"events": [{"type": "key", "code": KEY_ENTER}]},
	"ui_cancel": {"events": [{"type": "key", "code": KEY_ESCAPE}]},
}

## Nama event final SDD-02 (EVENT-BUS-SPEC bagian 3); konstanta kanonik berada
## pada core_events.gd dan dirujuk AppBootstrap sejak tahap implementasi EventBus.
const EVENT_APP_PAUSED_NAME := "app.paused"
const EVENT_APP_RESUMED_NAME := "app.resumed"
const EVENT_APP_READY_NAME := "app.ready"

const SHUTDOWN_FLUSH_DEADLINE_MS := 500
const FATAL_QUIT_DELAY_SEC := 3.0

const MODULE_NAME := "AppBootstrap"
const STATE_BOOT := "BOOT"
const STATE_READY := "READY"
const FATAL_PLAYER_MESSAGE := "Terjadi masalah saat memulai ASTRANUSA. Mohon mulai ulang."


var _booted := false
var _boot_failed := false
var _boot_ms := -1
var _boot_start_ms := 0
var _paused := false
var _shutdown_done := false
var _degraded: Array[String] = []
var _test_mode := false
var _services := {}
var _app_state: Variant = null
var _log_service: Variant = null
var _config_service: Variant = null
var _event_bus: Variant = null


func _ready() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	# Boot otomatis hanya pada jalur aplikasi normal: ketika suite headless
	# dijalankan dengan --script, tidak ada scene utama sehingga boot tidak
	# pernah terpicu dan suite mengendalikan inisialisasi secara eksplisit.
	if _booted or _boot_failed:
		set_process(false)
		return
	if get_tree().current_scene != null:
		set_process(false)
		initialize()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			handle_pause()
		NOTIFICATION_APPLICATION_RESUMED:
			handle_resume()
		NOTIFICATION_WM_CLOSE_REQUEST:
			handle_close_request()


func _inject_services(services: Dictionary) -> void:
	# Jalur suntikan stub untuk pengujian; bukan antarmuka publik layanan.
	_services = services
	_test_mode = true


## Menjalankan urutan inisialisasi sepuluh langkah; mengembalikan status boot.
func initialize() -> Dictionary:
	if _booted or _boot_failed:
		push_error("initialize() AppBootstrap hanya boleh dipanggil sekali (CFR-FR-001).")
		return _boot_result(BOOT_FATAL)
	_boot_start_ms = Time.get_ticks_msec()
	_degraded.clear()
	var failure: Dictionary = _run_boot_sequence()
	if int(failure["step"]) > 0:
		return _fatal_boot(int(failure["step"]), str(failure["detail"]))
	_boot_ms = Time.get_ticks_msec() - _boot_start_ms
	_booted = true
	var ready_emit: Dictionary = _event_bus.emit(EVENT_APP_READY_NAME, {"boot_ms": _boot_ms})
	if str(ready_emit.get("status", "")) != "ok":
		_log_service.warn(MODULE_NAME, "Pancaran app.ready ditolak: %s" % str(ready_emit))
	_log_service.info(MODULE_NAME, "Boot siap dalam %d ms." % _boot_ms)
	return _boot_result(BOOT_READY)


func is_ready() -> bool:
	return current_app_state() == STATE_READY


func degraded_services() -> Array[String]:
	return _degraded.duplicate()


func current_app_state() -> String:
	if _app_state == null:
		return STATE_BOOT
	return str(_app_state.current_state())


## Penutupan normal (CFR-FR-003): siram antrean tulis dengan tenggat,
## hentikan seluruh audio, catat status, siram buffer log, lalu keluar.
func request_shutdown() -> void:
	if _shutdown_done:
		return
	_shutdown_done = true
	var log_service: Variant = _service("LogService")
	var save_service: Variant = _service("SaveService")
	var audio_service: Variant = _service("AudioService")
	if save_service != null:
		_flush_save_queue_with_deadline(save_service, log_service)
	if audio_service != null:
		audio_service.pause_all()
	if log_service != null:
		log_service.info(MODULE_NAME, "Penutupan normal: antrean disiram, audio dihentikan.")
		log_service.flush()
	if not _test_mode and is_inside_tree():
		get_tree().quit()


## Penanganan NOTIFICATION_APPLICATION_PAUSED (CFR-INT-101).
func handle_pause() -> void:
	if _paused:
		return
	_paused = true
	var event_bus: Variant = _service("EventBus")
	if event_bus != null and _booted:
		event_bus.emit(EVENT_APP_PAUSED_NAME, {})
	var input_service: Variant = _service("InputService")
	if input_service != null:
		input_service.set_paused(true)
	var audio_service: Variant = _service("AudioService")
	if audio_service != null:
		audio_service.pause_all()
	var save_service: Variant = _service("SaveService")
	if save_service != null:
		save_service.flush()
	var log_service: Variant = _service("LogService")
	if log_service != null:
		log_service.flush()


## Penanganan NOTIFICATION_APPLICATION_RESUMED (CFR-INT-102); status dan route
## diperiksa konsisten, tidak dibangun ulang.
func handle_resume() -> void:
	if not _paused:
		return
	_paused = false
	var event_bus: Variant = _service("EventBus")
	if event_bus != null and _booted:
		event_bus.emit(EVENT_APP_RESUMED_NAME, {})
	var input_service: Variant = _service("InputService")
	if input_service != null:
		input_service.set_paused(false)
	var audio_service: Variant = _service("AudioService")
	if audio_service != null:
		audio_service.resume_all()
	_check_resume_consistency()


## Penanganan NOTIFICATION_WM_CLOSE_REQUEST (CFR-INT-104).
func handle_close_request() -> void:
	request_shutdown()


func _run_boot_sequence() -> Dictionary:
	# Urutan langkah 2 s.d. 10 sesuai INITIALIZATION-LIFECYCLE-DESIGN bagian 3.2;
	# setiap langkah mengembalikan {"step", "detail"} dengan step 0 berarti sukses.
	var steps: Array[Callable] = [
		_boot_step_log,
		_boot_step_config,
		_boot_step_events,
		_boot_step_save,
		_boot_step_settings,
		_boot_step_audio,
		_boot_step_input,
		_boot_step_navigation,
	]
	for step in steps:
		var failure: Dictionary = step.call()
		if int(failure["step"]) > 0:
			return failure
	return _boot_step_ok()


func _boot_step_ok() -> Dictionary:
	return {"step": 0, "detail": ""}


func _boot_step_log() -> Dictionary:
	_log_service = _service("LogService")
	if _log_service == null:
		return {"step": 2, "detail": "LogService tidak tersedia sebagai autoload."}
	var log_result: Dictionary = _log_service.initialize(LOGS_DIR, _base_log_level())
	var log_status := str(log_result.get("status", ""))
	if log_status != "ok":
		return {"step": 2, "detail": "LogService gagal diinisialisasi (status: %s)." % log_status}
	_log_service.info(MODULE_NAME, "Langkah 2 selesai: LogService siap.")
	return _boot_step_ok()


func _boot_step_config() -> Dictionary:
	_config_service = _service("ConfigService")
	if _config_service == null:
		return {"step": 3, "detail": "ConfigService tidak tersedia sebagai autoload."}
	var config_result: Dictionary = _config_service.initialize(_log_service)
	var config_status := str(config_result.get("status", ""))
	var config_detail := "ConfigService gagal memuat nilai default (status: %s)." % config_status
	if config_status != "ok":
		return {"step": 3, "detail": config_detail}
	_log_service.info(MODULE_NAME, "Langkah 3 selesai: konfigurasi dasar dimuat.")
	return _boot_step_ok()


func _boot_step_events() -> Dictionary:
	_event_bus = _service("EventBus")
	if _event_bus == null:
		return {"step": 4, "detail": "EventBus tidak tersedia sebagai autoload."}
	for registration in _app_event_registrations():
		var reg_result: Dictionary = _event_bus.register_event(
			registration["name"], registration["mode"], registration["owner"], registration["keys"]
		)
		var reg_status := str(reg_result.get("status", ""))
		var reg_detail := "Registrasi event %s gagal (status: %s)." % [registration["name"], reg_status]
		if reg_status != "ok":
			return {"step": 4, "detail": reg_detail}
	_log_service.info(MODULE_NAME, "Langkah 4 selesai: EventBus siap dan register diaudit.")
	return _boot_step_ok()


func _boot_step_save() -> Dictionary:
	var save_service: Variant = _service("SaveService")
	if save_service == null:
		return {"step": 5, "detail": "SaveService tidak tersedia sebagai autoload."}
	var probe_script: Variant = _resolve_script("SaveSpaceProbe", SAVE_SPACE_PROBE_PATH)
	if probe_script == null:
		return {"step": 5, "detail": "Kelas SaveSpaceProbe tidak ditemukan."}
	var version := APP_VERSION.load_version()
	var save_result: Dictionary = save_service.initialize(
		_log_service, probe_script.new(), str(version["name"])
	)
	var save_status := str(save_result.get("status", ""))
	var save_detail := "SaveService gagal diinisialisasi (status: %s)." % save_status
	if save_status != "ok":
		return {"step": 5, "detail": save_detail}
	_log_service.info(MODULE_NAME, "Langkah 5 selesai: store dimuat dan pemulihan selesai.")
	return _boot_step_ok()


func _boot_step_settings() -> Dictionary:
	var apply_result: Dictionary = _config_service.apply_player_settings()
	if str(apply_result.get("status", "")) != "ok":
		var detail := str(apply_result.get("status", ""))
		_degraded.append("ConfigService")
		_log_service.warn(MODULE_NAME, "Langkah 6 terdegradasi: pengaturan pemain default (%s)." % detail)
	else:
		_log_service.info(MODULE_NAME, "Langkah 6 selesai: pengaturan pemain diterapkan.")
	return _boot_step_ok()


func _boot_step_audio() -> Dictionary:
	var audio_service: Variant = _service("AudioService")
	if audio_service == null:
		_degraded.append("AudioService")
		_log_service.warn(MODULE_NAME, "Langkah 7 terdegradasi: AudioService tidak tersedia.")
		return _boot_step_ok()
	var result: Dictionary = audio_service.initialize(_log_service, _config_service)
	var status := str(result.get("status", ""))
	if status == "fatal":
		return {"step": 7, "detail": "AudioService fatal: dependensi kritis null."}
	if status != "ok":
		_degraded.append("AudioService")
		_log_service.warn(MODULE_NAME, "Langkah 7 terdegradasi: audio tanpa perangkat (%s)." % status)
		return _boot_step_ok()
	_log_service.info(MODULE_NAME, "Langkah 7 selesai: volume kategori diterapkan.")
	return _boot_step_ok()


func _boot_step_input() -> Dictionary:
	var input_service: Variant = _service("InputService")
	if input_service == null:
		_degraded.append("InputService")
		_log_service.warn(MODULE_NAME, "Langkah 8 terdegradasi: InputService tidak tersedia.")
		return _boot_step_ok()
	var result: Dictionary = input_service.initialize(BUILTIN_ACTION_CONFIG, _log_service)
	var status := str(result.get("status", ""))
	var action_count := int(result.get("actions", 0))
	if status == "ok":
		_log_service.info(MODULE_NAME, "Langkah 8 selesai: %d aksi terdaftar." % action_count)
	else:
		_degraded.append("InputService")
		_log_service.warn(MODULE_NAME, "Langkah 8 terdegradasi: façade input tanpa aksi (%s)." % status)
	return _boot_step_ok()


func _boot_step_navigation() -> Dictionary:
	var router_service: Variant = _service("SceneRouter")
	if router_service == null:
		return {"step": 9, "detail": "SceneRouter tidak tersedia sebagai autoload."}
	var app_state_script: Variant = _resolve_script("AppState", APP_STATE_PATH)
	var loader_script: Variant = _resolve_script("CoreResourceLoader", RESOURCE_LOADER_PATH)
	if app_state_script == null or loader_script == null:
		return {"step": 9, "detail": "Pustaka murni SceneRouter tidak ditemukan."}
	_app_state = app_state_script.new()
	var router_result: Dictionary = router_service.initialize(
		_log_service, _event_bus, _app_state, loader_script.new()
	)
	var router_status := str(router_result.get("status", ""))
	var router_detail := "SceneRouter gagal diinisialisasi (status: %s)." % router_status
	if router_status != "ok":
		return {"step": 9, "detail": router_detail}
	_log_service.info(MODULE_NAME, "Langkah 9 selesai: route awal dinyatakan.")
	var ready_result: Dictionary = _app_state.mark_ready()
	if str(ready_result.get("status", "")) != "ok":
		return {"step": 10, "detail": "Transisi status BOOT ke READY ditolak."}
	return _boot_step_ok()


func _check_resume_consistency() -> void:
	var log_service: Variant = _service("LogService")
	if log_service == null:
		return
	if not is_ready():
		log_service.warn(MODULE_NAME, "Resume: status aplikasi tidak READY; tidak dibangun ulang.")
		return
	var router_service: Variant = _service("SceneRouter")
	if router_service != null and str(router_service.current_route()) == "":
		log_service.warn(MODULE_NAME, "Resume: route aktif kosong; konsistensi diperiksa.")


func _flush_save_queue_with_deadline(save_service: Variant, log_service: Variant) -> void:
	var deadline := Time.get_ticks_msec() + SHUTDOWN_FLUSH_DEADLINE_MS
	while Time.get_ticks_msec() <= deadline:
		var result: Dictionary = save_service.flush()
		if str(result.get("status", "")) == "ok":
			return
		if log_service != null:
			log_service.warn(MODULE_NAME, "Siraman penutupan parsial: %s" % str(result))
	if log_service != null:
		log_service.warn(MODULE_NAME, "Tenggat siraman antrean tulis terlampaui; penutupan dilanjutkan.")


func _fatal_boot(step: int, detail: String) -> Dictionary:
	var log_service: Variant = _service("LogService")
	if log_service != null:
		log_service.error(MODULE_NAME, "Boot fatal pada langkah %d: %s" % [step, detail])
	push_error("Boot fatal pada langkah %d: %s" % [step, detail])
	_boot_failed = true
	if not _test_mode:
		_show_fatal_overlay()
	return _boot_result(BOOT_FATAL)


func _show_fatal_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "FatalMessageLayer"
	var label := Label.new()
	label.text = FATAL_PLAYER_MESSAGE
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	layer.add_child(label)
	get_tree().root.add_child(layer)
	get_tree().create_timer(FATAL_QUIT_DELAY_SEC).timeout.connect(_quit_after_fatal)


func _quit_after_fatal() -> void:
	get_tree().quit(1)


func _boot_result(status: String) -> Dictionary:
	return {"status": status, "degraded": _degraded.duplicate(), "boot_ms": _boot_ms}


func _app_event_registrations() -> Array[Dictionary]:
	var no_keys: Array[String] = []
	var boot_keys: Array[String] = ["boot_ms"]
	return [
		{"name": EVENT_APP_PAUSED_NAME, "mode": "immediate", "owner": MODULE_NAME, "keys": no_keys},
		{
			"name": EVENT_APP_RESUMED_NAME,
			"mode": "immediate",
			"owner": MODULE_NAME,
			"keys": no_keys.duplicate(),
		},
		{"name": EVENT_APP_READY_NAME, "mode": "deferred", "owner": MODULE_NAME, "keys": boot_keys},
	]


func _service(name: String) -> Variant:
	if _test_mode and _services.has(name):
		return _services[name]
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null(name)


func _resolve_script(name: String, path: String) -> Variant:
	if _test_mode and _services.has(name) and _services[name] is Script:
		return _services[name]
	var script: Variant = load(path)
	if script is Script:
		return script
	return null


func _base_log_level() -> String:
	return LOG_LEVEL_DEBUG_BUILD if OS.is_debug_build() else LOG_LEVEL_RELEASE
