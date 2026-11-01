extends SceneTree

## Suite CB: pengujian AppBootstrap dan siklus hidup inisialisasi
## (CORE-FRAMEWORK-IMPLEMENTATION-TEST-SPEC bagian 5, kasus CB-01 s.d. CB-08).
## Seluruh layanan disuntikkan sebagai stub sesuai tabel suntikan (bagian 4)
## sehingga urutan boot, klasifikasi kegagalan, penutupan normal, dan handler
## siklus hidup teruji terisolasi tanpa layanan sungguhan.
## Jalankan headless dari root proyek game/:
## godot --headless --script res://tests/core_boot_tests.gd
## Catatan: CB-04 (idempotensi boot lewat stempel waktu store) dijalankan
## bersama suite SaveService pada tahap implementasi SaveService.


const BOOTSTRAP_PATH := "res://src/core/app_bootstrap.gd"
const TestLib := preload("res://tests/core_test_lib.gd")
const MAX_SANE_BOOT_MS := 60000


class StubLog extends RefCounted:
	var init_status := "ok"
	var init_level := ""
	var flush_calls := 0

	func initialize(_logs_dir: String, base_level: String) -> Dictionary:
		init_level = base_level
		return {"status": init_status}

	func debug(_module: String, _message: String) -> void:
		pass

	func info(_module: String, _message: String) -> void:
		pass

	func warn(_module: String, _message: String) -> void:
		pass

	func error(_module: String, _message: String) -> void:
		pass

	func flush() -> Dictionary:
		flush_calls += 1
		return {"status": "ok", "rotated": false}


class StubConfig extends RefCounted:
	var init_status := "ok"
	var apply_status := "ok"

	func initialize(_logger: Variant) -> Dictionary:
		return {"status": init_status}

	func apply_player_settings() -> Dictionary:
		return {"status": apply_status, "applied": 3}


class StubBus extends RefCounted:
	var register_status := "ok"
	var registrations: Array[Dictionary] = []
	var emits: Array[Dictionary] = []

	func register_event(
		_event_name: String,
		_mode: String,
		_owner: String,
		_required_keys: Array[String]
	) -> Dictionary:
		registrations.append({"name": _event_name, "mode": _mode, "keys": _required_keys})
		return {"status": register_status}

	func emit(event_name: String, payload: Dictionary) -> Dictionary:
		emits.append({"name": event_name, "payload": payload})
		return {"status": "ok"}


class StubSave extends RefCounted:
	var init_status := "ok"
	var flush_calls := 0
	var probe_seen: Variant = null

	func initialize(_logger: Variant, space_probe: Variant, _app_version: String) -> Dictionary:
		probe_seen = space_probe
		return {"status": init_status}

	func flush() -> Dictionary:
		flush_calls += 1
		return {"status": "ok", "written": [], "deferred": []}


class StubAudio extends RefCounted:
	var init_status := "ok"
	var pause_all_calls := 0
	var resume_all_calls := 0

	func initialize(_logger: Variant, _config: Variant) -> Dictionary:
		return {"status": init_status}

	func pause_all() -> void:
		pause_all_calls += 1

	func resume_all() -> void:
		resume_all_calls += 1


class StubInput extends RefCounted:
	var init_status := "ok"
	var paused_flags: Array[bool] = []
	var config_seen: Variant = null

	func initialize(action_config: Dictionary, _logger: Variant) -> Dictionary:
		config_seen = action_config
		return {"status": init_status, "actions": 2}

	func set_paused(paused: bool) -> void:
		paused_flags.append(paused)


class StubRouter extends RefCounted:
	var init_status := "ok"
	var state_seen: Variant = null

	func initialize(
		_logger: Variant, _bus: Variant, app_state: Variant, _loader: Variant
	) -> Dictionary:
		state_seen = app_state
		return {"status": init_status}

	func current_route() -> String:
		return "boot"


class StubAppState extends RefCounted:
	var _ready_now := false

	func current_state() -> String:
		return "READY" if _ready_now else "BOOT"

	func mark_ready() -> Dictionary:
		_ready_now = true
		return {"status": "ok"}


class StubAppStateReject extends RefCounted:
	func current_state() -> String:
		return "BOOT"

	func mark_ready() -> Dictionary:
		return {"status": "rejected"}


class StubProbe extends RefCounted:
	func free_space_bytes() -> int:
		return 1073741824


class StubLoader extends RefCounted:
	var _placeholder := 0


func _initialize() -> void:
	var lib := TestLib.new("core_boot_tests")
	_cb_01_sequence(lib)
	_cb_02_failure_classification(lib)
	_cb_03_normal_shutdown(lib)
	_cb_05_pause_resume(lib)
	_cb_06_close_request(lib)
	_cb_07_boot_time(lib)
	_cb_08_app_ready_event(lib)
	var failures := lib.report()
	quit(1 if failures > 0 else 0)


func _ok_services() -> Dictionary:
	return {
		"LogService": StubLog.new(),
		"ConfigService": StubConfig.new(),
		"EventBus": StubBus.new(),
		"SaveService": StubSave.new(),
		"AudioService": StubAudio.new(),
		"InputService": StubInput.new(),
		"SceneRouter": StubRouter.new(),
		"SaveSpaceProbe": StubProbe,
		"AppState": StubAppState,
		"CoreResourceLoader": StubLoader,
	}


func _make_boot(services: Dictionary) -> Node:
	var script: Variant = load(BOOTSTRAP_PATH)
	var bootstrap := script.new() as Node
	# gdlint:ignore = private-method-call — jalur suntikan stub (TEST-SPEC bagian 4).
	bootstrap._inject_services(services)
	return bootstrap


func _break_service(services: Dictionary, what: String) -> void:
	match what:
		"log":
			services["LogService"].init_status = "error"
		"config":
			services["ConfigService"].init_status = "invalid"
		"bus_register":
			services["EventBus"].register_status = "duplicate"
		"save":
			services["SaveService"].init_status = "error"
		"audio_fatal":
			services["AudioService"].init_status = "fatal"
		"router":
			services["SceneRouter"].init_status = "error"
		"state_ready":
			services["AppState"] = StubAppStateReject


func _emitted(bus: StubBus, event_name: String) -> Array:
	var payloads: Array = []
	for entry in bus.emits:
		if str(entry["name"]) == event_name:
			payloads.append(entry["payload"])
	return payloads


func _cb_01_sequence(lib) -> void:
	var services := _ok_services()
	var bus: StubBus = services["EventBus"]
	var save: StubSave = services["SaveService"]
	var boot := _make_boot(services)
	var result: Dictionary = boot.initialize()
	lib.assert_status(result, "ready", "CB-01", "urutan boot sepuluh langkah berstatus ready")
	lib.assert_true(boot.is_ready(), "CB-01", "is_ready() benar setelah boot sukses")
	lib.assert_eq(boot.current_app_state(), "READY", "CB-01", "status aplikasi READY setelah boot")
	lib.assert_eq(
		boot.degraded_services().size(), 0, "CB-01", "tidak ada layanan terdegradasi pada jalur normal"
	)
	lib.assert_true(
		result["boot_ms"] >= 0 and typeof(result["boot_ms"]) == TYPE_INT,
		"CB-01", "boot_ms tercatat sebagai bilangan bulat non-negatif"
	)
	lib.assert_eq(
		bus.registrations.size(), 3, "CB-01", "tiga event aplikasi diregistrasi ke EventBus"
	)
	lib.assert_eq(
		str(bus.registrations[0]["mode"]), "immediate", "CB-01", "app.paused bermode immediate"
	)
	lib.assert_eq(
		str(bus.registrations[1]["mode"]), "immediate", "CB-01", "app.resumed bermode immediate"
	)
	lib.assert_eq(
		str(bus.registrations[2]["mode"]), "deferred", "CB-01", "app.ready bermode deferred"
	)
	lib.assert_eq(
		str(bus.registrations[2]["name"]), "app.ready", "CB-01", "register ketiga adalah app.ready"
	)
	lib.assert_true(
		save.probe_seen is StubProbe, "CB-01", "SaveSpaceProbe dikonstruksi dari kelas tersuntik"
	)
	var second: Dictionary = boot.initialize()
	lib.assert_status(
		second, "fatal", "CB-01", "initialize() kedua ditolak sebagai pelanggaran kontrak"
	)
	lib.assert_true(
		boot.is_ready(), "CB-01", "status READY terjaga setelah inisialisasi ulang ditolak"
	)


func _cb_02_failure_classification(lib) -> void:
	var services := _ok_services()
	var audio: StubAudio = services["AudioService"]
	audio.init_status = "degraded"
	var input: StubInput = services["InputService"]
	input.init_status = "degraded"
	var boot := _make_boot(services)
	var result: Dictionary = boot.initialize()
	lib.assert_status(
		result, "ready", "CB-02", "boot tetap ready ketika layanan sekunder terdegradasi"
	)
	lib.assert_eq(
		boot.degraded_services(),
		["AudioService", "InputService"],
		"CB-02",
		"daftar layanan terdegradasi urut dan sesuai"
	)

	var missing := _ok_services()
	missing.erase("AudioService")
	var boot_missing := _make_boot(missing)
	var missing_result: Dictionary = boot_missing.initialize()
	lib.assert_status(
		missing_result, "ready", "CB-02", "layanan sekunder yang absen tidak menghentikan boot"
	)
	lib.assert_eq(
		boot_missing.degraded_services(),
		["AudioService"],
		"CB-02",
		"layanan sekunder yang absen dilaporkan terdegradasi"
	)

	var fatal_labels := {
		"log": "LogService gagal diinisialisasi",
		"config": "ConfigService gagal memuat nilai dasar",
		"bus_register": "registrasi event ditolak",
		"save": "SaveService gagal diinisialisasi",
		"audio_fatal": "AudioService melaporkan fatal",
		"router": "SceneRouter gagal diinisialisasi",
		"state_ready": "transisi READY ditolak",
	}
	for what in fatal_labels:
		var case_services := _ok_services()
		_break_service(case_services, what)
		var case_boot := _make_boot(case_services)
		var case_result: Dictionary = case_boot.initialize()
		lib.assert_status(
			case_result, "fatal", "CB-02", "boot fatal ketika %s" % fatal_labels[what]
		)
		lib.assert_false(
			case_boot.is_ready(), "CB-02", "boot gagal tidak dianggap siap (%s)" % fatal_labels[what]
		)
		lib.assert_eq(
			case_boot.current_app_state(),
			"BOOT",
			"CB-02",
			"status tetap BOOT (%s)" % fatal_labels[what]
		)


func _cb_03_normal_shutdown(lib) -> void:
	var services := _ok_services()
	var boot := _make_boot(services)
	boot.initialize()
	boot.request_shutdown()
	var save: StubSave = services["SaveService"]
	var audio: StubAudio = services["AudioService"]
	var log: StubLog = services["LogService"]
	lib.assert_true(
		save.flush_calls >= 1, "CB-03", "antrean tulis SaveService disiram saat penutupan"
	)
	lib.assert_true(audio.pause_all_calls == 1, "CB-03", "seluruh audio dihentikan saat penutupan")
	lib.assert_true(log.flush_calls >= 1, "CB-03", "buffer LogService disiram saat penutupan")
	boot.request_shutdown()
	lib.assert_eq(
		audio.pause_all_calls, 1, "CB-03", "penutupan ganda tidak mengulang efek penutupan"
	)


func _cb_05_pause_resume(lib) -> void:
	var services := _ok_services()
	var bus: StubBus = services["EventBus"]
	var input: StubInput = services["InputService"]
	var audio: StubAudio = services["AudioService"]
	var save: StubSave = services["SaveService"]
	var log: StubLog = services["LogService"]
	var boot := _make_boot(services)
	boot.initialize()
	boot.handle_pause()
	lib.assert_eq(
		_emitted(bus, "app.paused").size(), 1, "CB-05", "app.paused dipancarkan sekali saat jeda"
	)
	lib.assert_eq(input.paused_flags, [true], "CB-05", "InputService menerima status jeda")
	lib.assert_eq(audio.pause_all_calls, 1, "CB-05", "AudioService menjeda seluruh suara")
	lib.assert_true(save.flush_calls >= 1, "CB-05", "antrean tulis disiram saat jeda")
	lib.assert_true(log.flush_calls >= 1, "CB-05", "buffer log disiram saat jeda")
	boot.handle_pause()
	lib.assert_eq(
		_emitted(bus, "app.paused").size(), 1, "CB-05", "jeda ganda idempoten tanpa pancaran ganda"
	)
	lib.assert_eq(
		input.paused_flags, [true], "CB-05", "jeda ganda idempoten pada InputService"
	)
	boot.handle_resume()
	lib.assert_eq(
		_emitted(bus, "app.resumed").size(), 1, "CB-05", "app.resumed dipancarkan sekali saat lanjut"
	)
	lib.assert_eq(
		input.paused_flags, [true, false], "CB-05", "InputService menerima status lanjut"
	)
	lib.assert_eq(audio.resume_all_calls, 1, "CB-05", "AudioService melanjutkan seluruh suara")
	boot.handle_resume()
	lib.assert_eq(
		_emitted(bus, "app.resumed").size(), 1, "CB-05", "lanjut ganda idempoten"
	)


func _cb_06_close_request(lib) -> void:
	var services := _ok_services()
	var boot := _make_boot(services)
	boot.initialize()
	boot.handle_close_request()
	var save: StubSave = services["SaveService"]
	var audio: StubAudio = services["AudioService"]
	lib.assert_true(
		save.flush_calls >= 1, "CB-06", "permintaan tutup menyiram antrean tulis"
	)
	lib.assert_true(
		audio.pause_all_calls == 1, "CB-06", "permintaan tutup menghentikan seluruh audio"
	)
	boot.handle_close_request()
	lib.assert_eq(
		audio.pause_all_calls, 1, "CB-06", "permintaan tutup ganda tidak mengulang efek"
	)


func _cb_07_boot_time(lib) -> void:
	var services := _ok_services()
	var boot := _make_boot(services)
	var result: Dictionary = boot.initialize()
	lib.assert_between(
		float(result["boot_ms"]), 0.0, MAX_SANE_BOOT_MS, "CB-07", "boot_ms berada pada rentang sehat"
	)
	lib.assert_true(
		boot.is_ready(), "CB-07", "boot selesai dalam waktu sehat"
	)


func _cb_08_app_ready_event(lib) -> void:
	var services := _ok_services()
	var bus: StubBus = services["EventBus"]
	var input: StubInput = services["InputService"]
	var boot := _make_boot(services)
	var result: Dictionary = boot.initialize()
	lib.assert_eq(
		boot.current_app_state(), "READY", "CB-08", "status READY sebelum event diperiksa"
	)
	var builtin_seen: Variant = input.config_seen
	var cancel_events: Array = builtin_seen.get("ui_cancel", {}).get("events", [])
	var cancel_key := 0
	if not cancel_events.is_empty():
		cancel_key = int(cancel_events[0].get("code", 0))
	lib.assert_eq(
		cancel_key, KEY_ESCAPE, "CB-08", "action map bawaan diteruskan ke InputService"
	)
	var payloads := _emitted(bus, "app.ready")
	lib.assert_eq(payloads.size(), 1, "CB-08", "app.ready dipancarkan tepat satu kali")
	if payloads.is_empty():
		return
	var payload: Dictionary = payloads[0]
	lib.assert_true(
		payload.has("boot_ms") and typeof(payload["boot_ms"]) == TYPE_INT,
		"CB-08", "muatan app.ready memuat boot_ms bilangan bulat"
	)
	lib.assert_eq(
		payload["boot_ms"], result["boot_ms"], "CB-08", "boot_ms pada event sama dengan hasil boot"
	)
