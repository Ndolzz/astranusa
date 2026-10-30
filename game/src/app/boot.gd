extends Control

## Scene boot minimal tahap SDD-01: menampilkan identitas dan versi aplikasi.
## Scene ini bukan gameplay; digunakan sebagai smoke test visual pada perangkat.


const APP_VERSION := preload("res://src/core/app_version.gd")


@onready var _version_label: Label = %VersionLabel


func _ready() -> void:
	var version := APP_VERSION.load_version()
	if version["valid"]:
		_version_label.text = "ASTRANUSA %s (build %d)" % [version["name"], version["code"]]
	else:
		_version_label.text = "ASTRANUSA - metadata versi tidak valid"
		push_error("Metadata versi tidak valid; periksa version.json.")
