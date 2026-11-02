extends SceneTree

## Suite EB: pengujian EventBus (EVENT-BUS-SPEC bagian 9, kasus EB-01 s.d.
## EB-12; CORE-FRAMEWORK-IMPLEMENTATION-TEST-SPEC bagian 2). Bus diuji pada
## instansi tersendiri yang disuntikkan ke akar scene; LogService autoload
## disiapkan ke direktori uji terpisah sehingga catatan ERROR, WARN, dan INFO
## yang diwajibkan spesifikasi dapat dibaca kembali dari berkasnya.
## Jalankan headless dari root proyek game/:
## godot --headless --script res://tests/core_event_bus_tests.gd


const EVENT_BUS_PATH := "res://src/core/event_bus.gd"
const TestLib := preload("res://tests/core_test_lib.gd")
const LOG_DIR := "user://logs-eb/"


class ListenerBox extends RefCounted:
	var received: Array[Dictionary] = []

	func record(payload: Dictionary) -> void:
		received.append(payload)


class ListenerNode extends Node:
	var received: Array[Dictionary] = []

	func record(payload: Dictionary) -> void:
		received.append(payload)


class OrderRecorder extends RefCounted:
	var order: Array[String] = []

	func mark_first(_payload: Dictionary) -> void:
		order.append("first")

	func mark_second(_payload: Dictionary) -> void:
		order.append("second")

	func mark_third(_payload: Dictionary) -> void:
		order.append("third")


class ChainEmitter extends RefCounted:
	var bus: Variant = null
	var received: Array[Dictionary] = []

	func record(payload: Dictionary) -> void:
		received.append(payload)
		bus.emit("bus.lanjut", {"rantai": true})


class RecursiveListener extends RefCounted:
	var bus: Variant = null
	var hits := 0
	var inner_status := ""

	func record(_payload: Dictionary) -> void:
		hits += 1
		var result: Dictionary = bus.emit("bus.rekursi", {})
		inner_status = str(result["status"])


func _initialize() -> void:
	var lib := TestLib.new("core_event_bus_tests")
	lib.assert_true(_prepare_log_service(), "EB", "LogService autoload tersedia untuk suite")
	_eb_01_register_and_duplicate(lib)
	_eb_02_unknown_event_rejected(lib)
	_eb_03_immediate_order(lib)
	_eb_04_deferred_delivery(lib)
	_eb_05_reentrancy_guard(lib)
	_eb_06_missing_keys_rejected(lib)
	_eb_07_unsubscribe_cleanup(lib)
	_eb_08_dead_owner_skipped(lib)
	_eb_09_invalid_listener_continues(lib)
	_eb_10_no_listener_info(lib)
	_eb_11_recursion_depth_rejected(lib)
	_eb_12_clear_all(lib)
	var failures := lib.report()
	quit(1 if failures > 0 else 0)


func _prepare_log_service() -> bool:
	var logger: Variant = root.get_node_or_null("LogService")
	if logger == null:
		return false
	logger.initialize(LOG_DIR, "DEBUG")
	return true


func _flush_log() -> void:
	var logger: Variant = root.get_node_or_null("LogService")
	if logger != null:
		logger.flush()


func _log_content() -> String:
	var path := LOG_DIR + "astranusa.log"
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var content := file.get_as_text()
	file.close()
	return content


func _new_bus() -> Variant:
	var script: Variant = load(EVENT_BUS_PATH)
	var bus: Variant = script.new()
	root.add_child(bus)
	return bus


func _dispose_bus(bus: Variant) -> void:
	root.remove_child(bus)
	bus.free()


func _eb_01_register_and_duplicate(lib) -> void:
	var bus: Variant = _new_bus()
	var keys: Array[String] = []
	var first: Dictionary = bus.register_event("bus.satu", "immediate", "SuiteEB", keys)
	lib.assert_status(first, "ok", "EB-01", "registrasi event baru diterima")
	var second: Dictionary = bus.register_event("bus.satu", "immediate", "SuiteEB", keys)
	lib.assert_status(second, "duplicate", "EB-01", "registrasi nama ganda ditolak")
	var bad_name: Dictionary = bus.register_event("NamaBesar", "immediate", "SuiteEB", keys)
	lib.assert_status(bad_name, "invalid", "EB-01", "nama di luar pola ditolak")
	var bad_mode: Dictionary = bus.register_event("bus.mode", "seketika", "SuiteEB", keys)
	lib.assert_status(bad_mode, "invalid", "EB-01", "mode tidak sah ditolak")
	_dispose_bus(bus)


func _eb_02_unknown_event_rejected(lib) -> void:
	var bus: Variant = _new_bus()
	var box := ListenerBox.new()
	var sub: Dictionary = bus.subscribe("bus.takda", Callable(box, "record"), box)
	lib.assert_status(sub, "unknown_event", "EB-02", "subscribe nama tak terdaftar ditolak")
	var emit_res: Dictionary = bus.emit("bus.takda", {})
	lib.assert_status(emit_res, "unknown_event", "EB-02", "emit nama tak terdaftar ditolak")
	_flush_log()
	lib.assert_true(
		_log_content().contains("tak terdaftar"), "EB-02", "penolakan tercatat sebagai ERROR"
	)
	_dispose_bus(bus)


func _eb_03_immediate_order(lib) -> void:
	var bus: Variant = _new_bus()
	var keys: Array[String] = []
	bus.register_event("bus.urut", "immediate", "SuiteEB", keys)
	var recorder := OrderRecorder.new()
	bus.subscribe("bus.urut", Callable(recorder, "mark_first"), recorder)
	bus.subscribe("bus.urut", Callable(recorder, "mark_second"), recorder)
	bus.subscribe("bus.urut", Callable(recorder, "mark_third"), recorder)
	var emit_res: Dictionary = bus.emit("bus.urut", {"nomor": 1})
	lib.assert_status(emit_res, "ok", "EB-03", "emit immediate diterima")
	var expected: Array[String] = ["first", "second", "third"]
	lib.assert_eq(recorder.order, expected, "EB-03", "listener dipanggil sesuai urutan")
	_dispose_bus(bus)


func _eb_04_deferred_delivery(lib) -> void:
	var bus: Variant = _new_bus()
	var keys: Array[String] = []
	bus.register_event("bus.tunda", "deferred", "SuiteEB", keys)
	var box := ListenerBox.new()
	bus.subscribe("bus.tunda", Callable(box, "record"), box)
	var emit_res: Dictionary = bus.emit("bus.tunda", {"nilai": 7})
	lib.assert_status(emit_res, "ok", "EB-04", "emit deferred diterima")
	lib.assert_eq(box.received.size(), 0, "EB-04", "listener belum menerima sebelum siraman")
	var flushed: int = bus.flush_deferred()
	lib.assert_eq(flushed, 1, "EB-04", "siraman mengirim satu event")
	lib.assert_eq(box.received.size(), 1, "EB-04", "listener menerima setelah siraman")
	lib.assert_eq(box.received[0]["nilai"], 7, "EB-04", "payload utuh sampai listener")
	_dispose_bus(bus)


func _eb_05_reentrancy_guard(lib) -> void:
	var bus: Variant = _new_bus()
	var keys: Array[String] = []
	bus.register_event("bus.reent", "deferred", "SuiteEB", keys)
	bus.register_event("bus.lanjut", "deferred", "SuiteEB", keys)
	var emitter := ChainEmitter.new()
	emitter.bus = bus
	var follow_box := ListenerBox.new()
	bus.subscribe("bus.reent", Callable(emitter, "record"), emitter)
	bus.subscribe("bus.lanjut", Callable(follow_box, "record"), follow_box)
	bus.emit("bus.reent", {})
	var flushed_first: int = bus.flush_deferred()
	lib.assert_eq(flushed_first, 1, "EB-05", "siraman pertama mengirim satu event")
	lib.assert_eq(emitter.received.size(), 1, "EB-05", "emitter menerima pada siraman pertama")
	lib.assert_eq(
		follow_box.received.size(), 0, "EB-05", "emit dalam siraman tidak dieksekusi seketika"
	)
	var flushed_second: int = bus.flush_deferred()
	lib.assert_eq(flushed_second, 1, "EB-05", "siraman kedua mengirim event antrean baru")
	lib.assert_eq(
		follow_box.received.size(), 1, "EB-05", "listener lanjut menerima pada siraman berikutnya"
	)
	_dispose_bus(bus)


func _eb_06_missing_keys_rejected(lib) -> void:
	var bus: Variant = _new_bus()
	var wajib: Array[String] = ["kunci"]
	bus.register_event("bus.wajib", "immediate", "SuiteEB", wajib)
	var box := ListenerBox.new()
	bus.subscribe("bus.wajib", Callable(box, "record"), box)
	var rejected: Dictionary = bus.emit("bus.wajib", {"lain": 1})
	lib.assert_status(rejected, "invalid_payload", "EB-06", "payload tanpa kunci wajib ditolak")
	lib.assert_eq(box.received.size(), 0, "EB-06", "listener tidak menerima payload ditolak")
	var accepted: Dictionary = bus.emit("bus.wajib", {"kunci": "nilai"})
	lib.assert_status(accepted, "ok", "EB-06", "payload berkunci wajib diterima")
	_flush_log()
	lib.assert_true(
		_log_content().contains("tanpa kunci"), "EB-06", "kunci hilang tercatat pada log"
	)
	_dispose_bus(bus)


func _eb_07_unsubscribe_cleanup(lib) -> void:
	var bus: Variant = _new_bus()
	var keys: Array[String] = []
	bus.register_event("bus.bebas", "immediate", "SuiteEB", keys)
	var box_a := ListenerBox.new()
	var box_b := ListenerBox.new()
	var box_c := ListenerBox.new()
	bus.subscribe("bus.bebas", Callable(box_a, "record"), box_a)
	bus.subscribe("bus.bebas", Callable(box_b, "record"), box_b)
	bus.unsubscribe("bus.bebas", Callable(box_a, "record"))
	bus.emit("bus.bebas", {})
	lib.assert_eq(box_a.received.size(), 0, "EB-07", "unsubscribe menghentikan pengiriman")
	lib.assert_eq(box_b.received.size(), 1, "EB-07", "listener lain tetap menerima")
	bus.subscribe("bus.bebas", Callable(box_c, "record"), box_c)
	var removed: int = bus.unsubscribe_owner(box_c)
	lib.assert_eq(removed, 1, "EB-07", "unsubscribe_owner melepas seluruh langganan pemilik")
	bus.emit("bus.bebas", {})
	lib.assert_eq(box_c.received.size(), 0, "EB-07", "pemilik yang dilepas tidak menerima lagi")
	bus.unsubscribe("bus.bebas", Callable(box_a, "record"))
	bus.emit("bus.bebas", {})
	lib.assert_eq(box_b.received.size(), 3, "EB-07", "unsubscribe idempoten tanpa efek samping")
	_dispose_bus(bus)


func _eb_08_dead_owner_skipped(lib) -> void:
	var bus: Variant = _new_bus()
	var keys: Array[String] = []
	bus.register_event("bus.mati", "immediate", "SuiteEB", keys)
	var owner_node := Node.new()
	var alive_box := ListenerBox.new()
	bus.subscribe("bus.mati", Callable(alive_box, "record"), owner_node)
	owner_node.free()
	var emit_res: Dictionary = bus.emit("bus.mati", {})
	lib.assert_status(emit_res, "ok", "EB-08", "emit berlanjut melewati pemilik mati")
	lib.assert_eq(
		alive_box.received.size(), 0, "EB-08", "listener pemilik mati tidak dipanggil"
	)
	var leftover: int = bus.unsubscribe_owner(owner_node)
	lib.assert_eq(leftover, 0, "EB-08", "langganan pemilik mati dilepas otomatis")
	_flush_log()
	lib.assert_true(
		_log_content().contains("dibebaskan"), "EB-08", "pemilik mati tercatat sebagai WARN"
	)
	_dispose_bus(bus)


func _eb_09_invalid_listener_continues(lib) -> void:
	var bus: Variant = _new_bus()
	var keys: Array[String] = []
	bus.register_event("bus.gagal", "immediate", "SuiteEB", keys)
	var dying_listener := ListenerNode.new()
	var survivor := ListenerBox.new()
	var dying_owner := RefCounted.new()
	bus.subscribe("bus.gagal", Callable(dying_listener, "record"), dying_owner)
	bus.subscribe("bus.gagal", Callable(survivor, "record"), survivor)
	dying_listener.free()
	var emit_res: Dictionary = bus.emit("bus.gagal", {"aman": true})
	lib.assert_status(emit_res, "ok", "EB-09", "emit selesai meski satu listener gagal")
	lib.assert_eq(
		survivor.received.size(), 1, "EB-09", "listener berikutnya tetap dipanggil"
	)
	_flush_log()
	lib.assert_true(
		_log_content().contains("Listener tidak sah"), "EB-09", "kegagalan listener tercatat ERROR"
	)
	_dispose_bus(bus)


func _eb_10_no_listener_info(lib) -> void:
	var bus: Variant = _new_bus()
	var keys: Array[String] = []
	bus.register_event("bus.kosong", "immediate", "SuiteEB", keys)
	var emit_res: Dictionary = bus.emit("bus.kosong", {})
	lib.assert_status(emit_res, "ok", "EB-10", "emit tanpa listener tetap sah")
	_flush_log()
	lib.assert_true(
		_log_content().contains("bus.kosong"), "EB-10", "diagnostik tanpa listener tercatat INFO"
	)
	_dispose_bus(bus)


func _eb_11_recursion_depth_rejected(lib) -> void:
	var bus: Variant = _new_bus()
	var keys: Array[String] = []
	bus.register_event("bus.rekursi", "immediate", "SuiteEB", keys)
	var recursive := RecursiveListener.new()
	recursive.bus = bus
	bus.subscribe("bus.rekursi", Callable(recursive, "record"), recursive)
	var emit_res: Dictionary = bus.emit("bus.rekursi", {})
	lib.assert_status(emit_res, "ok", "EB-11", "emit teratas selesai setelah pelindung rekursi")
	lib.assert_eq(
		recursive.hits, 8, "EB-11", "kedalaman immediate dibatasi delapan pemanggilan"
	)
	lib.assert_eq(
		recursive.inner_status, "rejected", "EB-11", "emit berikutnya ditolak pelindung rekursi"
	)
	_flush_log()
	lib.assert_true(
		_log_content().contains("rekursi"), "EB-11", "pelanggaran kedalaman tercatat ERROR"
	)
	_dispose_bus(bus)


func _eb_12_clear_all(lib) -> void:
	var bus: Variant = _new_bus()
	var keys: Array[String] = []
	bus.register_event("bus.selesai", "immediate", "SuiteEB", keys)
	var box := ListenerBox.new()
	bus.subscribe("bus.selesai", Callable(box, "record"), box)
	bus.clear_all()
	var emit_res: Dictionary = bus.emit("bus.selesai", {})
	lib.assert_status(emit_res, "unknown_event", "EB-12", "register event kosong setelah clear_all")
	var sub: Dictionary = bus.subscribe("bus.selesai", Callable(box, "record"), box)
	lib.assert_status(sub, "unknown_event", "EB-12", "register langganan kosong setelah clear_all")
	var again: Dictionary = bus.register_event("bus.selesai", "immediate", "SuiteEB", keys)
	lib.assert_status(again, "ok", "EB-12", "bus dapat dipakai ulang setelah clear_all")
	_dispose_bus(bus)
