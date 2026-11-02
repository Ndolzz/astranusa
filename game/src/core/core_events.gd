class_name CoreEvents
extends RefCounted

## Register tunggal konstanta event SDD-02 (EVENT-BUS-SPEC bagian 3): nama
## event, mode pengiriman, pemilik, dan kunci payload wajib. Pemilik event
## mendaftarkan miliknya melalui register_event saat inisialisasi layanan
## (langkah 4 s.d. 6 boot); lapisan atas menambah event bersama baris baru
## pada SERVICE-RESPONSIBILITY-MATRIX, bukan dengan string liar.


const EVENT_APP_PAUSED := "app.paused"
const EVENT_APP_RESUMED := "app.resumed"
const EVENT_APP_READY := "app.ready"
const EVENT_SAVE_STORE_WRITTEN := "save.store_written"
const EVENT_SAVE_MIGRATION_COMPLETED := "save.migration_completed"
const EVENT_CONFIG_SETTING_CHANGED := "config.setting_changed"

const MODE_IMMEDIATE := "immediate"
const MODE_DEFERRED := "deferred"

const KEY_BOOT_MS := "boot_ms"
const KEY_STORE := "store"
const KEY_FROM_VERSION := "from_version"
const KEY_TO_VERSION := "to_version"
const KEY_KEY := "key"

const OWNER_APP_BOOTSTRAP := "AppBootstrap"
const OWNER_SAVE_SERVICE := "SaveService"
const OWNER_CONFIG_SERVICE := "ConfigService"

## Spesifikasi lengkap register final SDD-02: mode, pemilik, dan kunci wajib
## per event; sumber tunggal bagi pendaftaran oleh layanan pemiliknya.
const EVENT_SPEC := {
	EVENT_APP_PAUSED: {
		"mode": MODE_IMMEDIATE,
		"owner": OWNER_APP_BOOTSTRAP,
		"required_keys": [],
	},
	EVENT_APP_RESUMED: {
		"mode": MODE_IMMEDIATE,
		"owner": OWNER_APP_BOOTSTRAP,
		"required_keys": [],
	},
	EVENT_APP_READY: {
		"mode": MODE_DEFERRED,
		"owner": OWNER_APP_BOOTSTRAP,
		"required_keys": [KEY_BOOT_MS],
	},
	EVENT_SAVE_STORE_WRITTEN: {
		"mode": MODE_DEFERRED,
		"owner": OWNER_SAVE_SERVICE,
		"required_keys": [KEY_STORE],
	},
	EVENT_SAVE_MIGRATION_COMPLETED: {
		"mode": MODE_DEFERRED,
		"owner": OWNER_SAVE_SERVICE,
		"required_keys": [KEY_STORE, KEY_FROM_VERSION, KEY_TO_VERSION],
	},
	EVENT_CONFIG_SETTING_CHANGED: {
		"mode": MODE_IMMEDIATE,
		"owner": OWNER_CONFIG_SERVICE,
		"required_keys": [KEY_KEY],
	},
}
