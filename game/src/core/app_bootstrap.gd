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
const FATAL_PLAYER_MESSAGE := (
	"Terjadi masalah saat memulai ASTRANUSA.\nSilakan mulai ulang aplikasi."
)


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

	var log_service: Variant = _service("LogService")
	if log_service == null:
		return _fatal_boot(2, "LogService tidak tersedia sebagai autoload.")
	var log_result: Dictionary = log_service.initialize(LOGS_DIR, _base_log_level())
	var log_status := str(log_result.get("status", ""))
	if log_status != "ok":
		return _fatal_boot(2, "LogService gagal diinisialisasi (status: %s)." % log_status)
	log_service.info(MODULE_NAME, "Langkah 2 selesai: LogService siap.")

	var config_service: Variant = _service("ConfigService")
	if config_service == null:
		return _fatal_boot(3, "ConfigService tidak tersedia sebagai autoload.")
	var config_result: Dictionary = config_service.initialize(log_service)
	var config_status := str(config_result.get("status", ""))
	if config_status != "ok":
		return _fatal_boot(3, "ConfigService gagal memuat nilai default (status: %s)." % config_status)
	log_service.info(MODULE_NAME, "Langkah 3 selesai: konfigurasi dasar dimuat.")

	var event_bus: Variant = _service("EventBus")
	if event_bus == null:
		return _fatal_boot(4, "EventBus tidak tersedia sebagai autoload.")
	for registration in _app_event_registrations():
		var reg_result: Dictionary = event_bus.register_event(
			registration["name"], registration["mode"], registration["owner"], registration["keys"]
		)
		var reg_status := str(reg_result.get("status", ""))
		if reg_status != "ok":
			return _fatal_boot(
				4, "Registrasi event %s gagal (status: %s)." % [registration["name"], reg_status]
			)
	log_service.info(MODULE_NAME, "Langkah 4 selesai: EventBus siap dan register diaudit.")

	var save_service: Variant = _service("SaveService")
	if save_service == null:
		return _fatal_boot(5, "SaveService tidak tersedia sebagai autoload.")
	var probe_script: Variant = _resolve_script("SaveSpaceProbe", SAVE_SPACE_PROBE_PATH)
	if probe_script == null:
		return _fatal_boot(5, "Kelas SaveSpaceProbe tidak ditemukan.")
	var version := APP_VERSION.load_version()
	var save_result: Dictionary = save_service.initialize(
		log_service, probe_script.new(), str(version["name"])
	)
	var save_status := str(save_result.get("status", ""))
	if save_status != "ok":
		return _fatal_boot(5, "SaveService gagal diinisialisasi (status: %s)." % save_status)
	log_service.info(MODULE_NAME, "Langkah 5 selesai: store dimuat dan pemulihan selesai.")

	var apply_result: Dictionary = config_service.apply_player_settings()
	if str(apply_result.get("status", "")) != "ok":
		_degraded.append("ConfigService")
		log_service.warn(
			MODULE_NAME,
			"Langkah 6 terdegradasi: pengaturan pemain memakai nilai default (%s)."
			% str(apply_result.get("status", ""))
		)
	else:
		log_service.info(MODULE_NAME, "Langkah 6 selesai: pengaturan pemain diterapkan.")

	if not _boot_step_audio(log_service, config_service):
		return _boot_result(BOOT_FATAL)
	if not _boot_step_input(log_service):
		return _boot_result(BOOT_FATAL)

	var router_service: Variant = _service("SceneRouter")
	if router_service == null:
		return _fatal_boot(9, "SceneRouter tidak tersedia sebagai autoload.")
	var app_state_script: Variant = _resolve_script("AppState", APP_STATE_PATH)
	var loader_script: Variant = _resolve_script("CoreResourceLoader", RESOURCE_LOADER_PATH)
	if app_state_script == null or loader_script == null:
		return _fatal_boot(9, "Pustaka murni SceneRouter tidak ditemukan.")
	_app_state = app_state_script.new()
	var router_result: Dictionary = router_service.initialize(
		log_service, event_bus, _app_state, loader_script.new()
	)
	var router_status := str(router_result.get("status", ""))
	if router_status != "ok":
		return _fatal_boot(9, "SceneRouter gagal diinisialisasi (status: %s)." % router_status)
	log_service.info(MODULE_NAME, "Langkah 9 selesai: route awal dinyatakan.")

	var ready_result: Dictionary = _app_state.mark_ready()
	if str(ready_result.get("status", "")) != "ok":
		return _fatal_boot(10, "Transisi status BOOT ke READY ditolak.")
	_boot_ms = Time.get_ticks_msec() - _boot_start_ms
	_booted = true
	var ready_emit: Dictionary = event_bus.emit(EVENT_APP_READY_NAME, {"boot_ms": _boot_ms})
	if str(ready_emit.get("status", "")) != "ok":
		log_service.warn(MODULE_NAME, "Pancaran app.ready ditolak: %s" % str(ready_emit))
	log_service.info(MODULE_NAME, "Boot siap dalam %d ms." % _boot_ms)
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


func _boot_step_audio(log_service: Variant, config_service: Variant) -> bool:
	var audio_service: Variant = _service("AudioService")
	if audio_service == null:
		_degraded.append("AudioService")
		log_service.warn(MODULE_NAME, "Langkah 7 terdegradasi: AudioService tidak tersedia.")
		return true
	var result: Dictionary = audio_service.initialize(log_service, config_service)
	var status := str(result.get("status", ""))
	if status == "ok":
		log_service.info(MODULE_NAME, "Langkah 7 selesai: volume kategori diterapkan.")
		return true
	if status == "fatal":
		_fatal_boot(7, "AudioService melaporkan kegagalan fatal: dependensi kritis null.")
		return false
	_degraded.append("AudioService")
	log_service.warn(
		MODULE_NAME, "Langkah 7 terdegradasi: audio berjalan tanpa perangkat (%s)." % status
	)
	return true


func _boot_step_input(log_service: Variant) -> bool:
	var input_service: Variant = _service("InputService")
	if input_service == null:
		_degraded.append("InputService")
		log_service.warn(MODULE_NAME, "Langkah 8 terdegradasi: InputService tidak tersedia.")
		return true
	var result: Dictionary = input_service.initialize(BUILTIN_ACTION_CONFIG, log_service)
	var status := str(result.get("status", ""))
	if status == "ok":
		log_service.info(
			MODULE_NAME, "Langkah 8 selesai: %d aksi terdaftar." % int(result.get("actions", 0))
		)
		return true
	_degraded.append("InputService")
	log_service.warn(MODULE_NAME, "Langkah 8 terdegradasi: façade input tanpa aksi (%s)." % status)
	return true


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
	get_tree().create_timer(FATAL_QUIT_DELAY_SEC).timeout.connect(
		func() -> void:
			get_tree().quit(1)
	)


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
