extends Node

## EventBus: komunikasi publish-subscribe lintas modul yang tervalidasi
## (EVENT-BUS-SPEC). Register event diaudit dan nama liar ditolak (CFR-FR-011);
## dua mode pengiriman immediate dan deferred dengan pemutusan reentrancy
## (CFR-FR-012); kebersihan listener dan pelepasan otomatis langganan pemilik
## mati (CFR-FR-013); diagnostik emit tanpa listener dicatat INFO (CFR-FR-014);
## kegagalan listener tidak menghentikan siraman (CFR-FR-031); jalur menganggur
## hanya memeriksa ukuran antrean tanpa alokasi (CFR-NFR-005). Ketergantungan
## hanya pada LogService yang diakses melalui nama autoload; EventBus tidak
## berlangganan ke layanan mana pun.


const MODE_IMMEDIATE := "immediate"
const MODE_DEFERRED := "deferred"
const VALID_MODES: Array[String] = [MODE_IMMEDIATE, MODE_DEFERRED]

const STATUS_OK := "ok"
const STATUS_DUPLICATE := "duplicate"
const STATUS_INVALID := "invalid"
const STATUS_UNKNOWN_EVENT := "unknown_event"
const STATUS_INVALID_PAYLOAD := "invalid_payload"
const STATUS_REJECTED := "rejected"

const MAX_IMMEDIATE_DEPTH := 8
const MODULE_NAME := "EventBus"


var _events := {}
var _listeners := {}
var _deferred_queue: Array[Dictionary] = []
var _flush_batch: Array[Dictionary] = []
var _immediate_depth := 0
var _flushing := false


func register_event(
	name: String, mode: String, owner: String, required_keys: Array[String]
) -> Dictionary:
	if _events.has(name):
		_log("error", "Registrasi ganda ditolak: %s." % name)
		push_error("EventBus: registrasi ganda ditolak: %s." % name)
		return {"status": STATUS_DUPLICATE}
	if not _valid_name(name) or not VALID_MODES.has(mode):
		_log("error", "Registrasi tidak sah: nama atau mode (%s, %s)." % [name, mode])
		push_error("EventBus: registrasi tidak sah: %s (mode: %s)." % [name, mode])
		return {"status": STATUS_INVALID}
	var keys: Array[String] = []
	keys.assign(required_keys)
	_events[name] = {"mode": mode, "owner": owner, "required_keys": keys}
	return {"status": STATUS_OK}


func subscribe(name: String, listener: Callable, owner: Object) -> Dictionary:
	if not _events.has(name):
		_log("error", "Subscribe ditolak: event tak terdaftar (%s)." % name)
		push_error("EventBus: subscribe pada event tak terdaftar: %s." % name)
		return {"status": STATUS_UNKNOWN_EVENT}
	if not _listeners.has(name):
		_listeners[name] = []
	var entries: Array = _listeners[name]
	entries.append({"callable": listener, "owner": owner})
	return {"status": STATUS_OK}


func unsubscribe(name: String, listener: Callable) -> void:
	if not _listeners.has(name):
		return
	var entries: Array = _listeners[name]
	for i in range(entries.size() - 1, -1, -1):
		var entry: Dictionary = entries[i]
		if entry["callable"] == listener:
			entries.remove_at(i)


func unsubscribe_owner(owner: Object) -> int:
	var removed := 0
	for event_name in _listeners.keys():
		var entries: Array = _listeners[event_name]
		for i in range(entries.size() - 1, -1, -1):
			var entry: Dictionary = entries[i]
			if entry["owner"] == owner:
				entries.remove_at(i)
				removed += 1
		if entries.is_empty():
			_listeners.erase(event_name)
	return removed


func emit(name: String, payload: Dictionary) -> Dictionary:
	var event: Dictionary = _events.get(name, {})
	if event.is_empty():
		_log("error", "Emit ditolak: event tak terdaftar (%s)." % name)
		push_error("EventBus: emit pada event tak terdaftar: %s." % name)
		return {"status": STATUS_UNKNOWN_EVENT}
	var missing := _missing_keys(event["required_keys"], payload)
	if not missing.is_empty():
		var missing_detail := ", ".join(PackedStringArray(missing))
		_log("error", "Emit ditolak: payload %s tanpa kunci %s." % [name, missing_detail])
		push_error("EventBus: payload event %s tanpa kunci wajib: %s." % [name, missing_detail])
		return {"status": STATUS_INVALID_PAYLOAD}
	if event["mode"] == MODE_DEFERRED:
		_deferred_queue.append({"name": name, "payload": payload})
		return {"status": STATUS_OK}
	return _emit_immediate(name, payload)


func flush_deferred() -> int:
	if _flushing or _deferred_queue.is_empty():
		return 0
	var pending := _deferred_queue.size()
	for i in pending:
		_flush_batch.append(_deferred_queue[i])
	_deferred_queue.clear()
	_flushing = true
	for entry in _flush_batch:
		_dispatch(str(entry["name"]), entry["payload"])
	_flush_batch.clear()
	_flushing = false
	return pending


func clear_all() -> void:
	_events.clear()
	_listeners.clear()
	_deferred_queue.clear()
	_immediate_depth = 0
	_flushing = false


func _process(_delta: float) -> void:
	if _deferred_queue.is_empty():
		return
	flush_deferred()


func _emit_immediate(name: String, payload: Dictionary) -> Dictionary:
	_immediate_depth += 1
	if _immediate_depth > MAX_IMMEDIATE_DEPTH:
		_immediate_depth -= 1
		_log("error", "Emit ditolak: kedalaman rekursi melebihi %d (%s)." % [MAX_IMMEDIATE_DEPTH, name])
		push_error("EventBus: kedalaman rekursi immediate melebihi batas (%s)." % name)
		return {"status": STATUS_REJECTED}
	_dispatch(name, payload)
	_immediate_depth -= 1
	return {"status": STATUS_OK}


func _dispatch(name: String, payload: Dictionary) -> void:
	_purge_dead_owners(name)
	var entries: Array = _listeners.get(name, [])
	if entries.is_empty():
		_log("info", "Emit event %s tanpa listener." % name)
		return
	var snapshot: Array = entries.duplicate()
	for entry in snapshot:
		var listener: Callable = entry["callable"]
		if not listener.is_valid():
			_log("error", "Listener tidak sah pada event %s; dilepas dan siraman berlanjut." % name)
			unsubscribe(name, listener)
			continue
		listener.call(payload)


func _purge_dead_owners(name: String) -> void:
	var entries: Array = _listeners.get(name, [])
	var dead_count := 0
	for i in range(entries.size() - 1, -1, -1):
		var entry: Dictionary = entries[i]
		if not is_instance_valid(entry["owner"]):
			entries.remove_at(i)
			dead_count += 1
	if dead_count == 0:
		return
	_log("warn", "Listener pemilik dibebaskan dilewati; langganan pemilik dilepas (%s)." % name)
	if entries.is_empty():
		_listeners.erase(name)


func _missing_keys(required_keys: Array[String], payload: Dictionary) -> Array[String]:
	var missing: Array[String] = []
	for key in required_keys:
		if not payload.has(key):
			missing.append(str(key))
	return missing


func _valid_name(name: String) -> bool:
	if name != name.to_lower() or name.count(".") != 1:
		return false
	var parts := name.split(".", false)
	if parts.size() != 2:
		return false
	for part in parts:
		if not part.is_valid_identifier():
			return false
	return true


func _log(level: String, message: String) -> void:
	var logger: Variant = _logger()
	if logger == null:
		return
	match level:
		"info":
			logger.info(MODULE_NAME, message)
		"warn":
			logger.warn(MODULE_NAME, message)
		"error":
			logger.error(MODULE_NAME, message)


func _logger() -> Variant:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/LogService")
