## Phase 0 冒烟测试：确认 GameManager Autoload 已加载且 get_snapshot() 可用。
## 运行：打开 gameplay/phase0_smoke.tscn，按 F6。
extends Node


func _ready() -> void:
	print("========== Phase 0 Smoke Test ==========")
	print(JSON.stringify(GameManager.get_snapshot(), "\t"))
	print("GameManager loaded OK")
