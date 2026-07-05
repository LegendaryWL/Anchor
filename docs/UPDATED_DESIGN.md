# Anchor — 8 小时冲刺版技术设计

> 基于 `docs/DESIGN.md` 的收缩版。  
> 目标不是架构最漂亮，而是 8 小时内做出一个能在网页打开、能胜利/失败、能展示恐怖氛围的完整版本。  
> 引擎：Godot 4.x，语言：GDScript，平台：Web。

---

## 0. 结论

原版 `DESIGN.md` 的三层架构是对的：

- `Behavior`：玩家交互。
- `Event`：怪物事件。
- `Process`：全局状态、SAN、胜负。

但在 8 小时 game jam 里，不建议先实现完整的 `BehaviorBase`、`EventBase`、消息对象体系。第一版应该写“脏而完整”的版本：

- `GameManager.gd`
- `RoomManager.gd`
- `WindowAttack.gd`
- `CandleAttack.gd`
- 若干 UI / 交互脚本

先让游戏从开始到胜利/失败跑通，再考虑抽象。

---

## 1. MVP 范围

### 必做

- 固定视角，不做自由移动。
- 小地图按钮切换房间。
- SAN 值。
- 锚修理进度，修满胜利。
- 窗户耐久。
- 蜡烛亮灭。
- Phase 1：怪物随机破窗。
- Phase 2：任一窗户破掉后，黑手尝试熄灭蜡烛。
- UI：SAN、锚进度、窗户耐久、读条、小地图。
- Web 导出。

### 暂缓 / 砍掉

- 完整第一人称移动。
- 跳跃。
- 复杂监控 live 视图。
- 多怪物。
- 多事件并发。
- 复杂动画状态机。
- 完整抽象事件框架。

### 加分项

- 相机小角度旋转。 20度
- 黑屏转场。
- 窗外红光。
- 低语、破窗、蜡烛熄灭音效。
- 简单 jump scare。

---

## 2. 三人分工

### 程序 A：核心玩法 / 数值 / 事件

负责文件：

```text
autoload/
gameplay/
```

任务：

- 写 `GameManager` 单例。
- 管理 `SAN`、`anchor_progress`、`phase`、胜负。
- 管理窗户耐久、蜡烛状态。
- 写怪物定时攻击逻辑。
- Phase 1：随机攻击窗户。
- Phase 2：随机选择亮着的蜡烛生成黑手 / 熄灭蜡烛。
- 发出状态变化信号给 UI 和场景。

不要负责：

- UI 布局。
- 3D 场景摆放。
- Web 导出。

### 程序 B：交互 / 房间切换 / UI

负责文件：

```text
interaction/
ui/
```

任务：

- 点击、长按、连点。
- 房间按钮 / 小地图切换。
- 读条。
- UI：SAN 条、锚进度、窗户耐久、读条、小地图。
- 音效提示：破窗声、低语声、蜡烛熄灭声。
- 调用 A 暴露的 API，不直接改核心数据。

不要负责：

- 怪物 AI。
- 胜负判断。
- 模型导入。

### 程序 C：场景 / 美术 / 集成 / Web

负责文件：

```text
scenes/
assets/
web_build/
export_presets.cfg
```

任务：

- 搭 3D 房间灰盒。
- 导入模型、材质、动画。
- 摆窗户、蜡烛、锚、黑手。
- 固定相机机位。
- 灯光、红光、恐怖氛围。
- 主场景集成。
- Web 导出、本地预览、提交 `web_build/`。

不要负责：

- SAN 数值逻辑。
- 怪物事件逻辑。
- 复杂交互状态。

---

## 3. 开工顺序

### 第 0-30 分钟

- C：建项目结构、主场景、空房间、相机、占位窗户/蜡烛/锚。
- A：写 `GameManager.gd` 草稿，不依赖真实场景。
- B：列 UI 和交互清单，等 A 的 API 和 C 的节点名。

### 第 30-90 分钟

- A：做最小闭环，SAN 会变，修锚能赢，SAN 归零能输。
- C：稳定节点结构和相机点。
- B：开始接按钮、长按、读条、小地图，调用 A 的 API。

### 第 90 分钟后

- A：Phase 1 / Phase 2 / 怪物事件。
- B：交互手感、UI、音效。
- C：场景、美术、灯光、Web 导出。

一句话：C 搭舞台，A 写规则，B 接手感。

---

## 4. 8 小时时间表

| 时间 | 目标 |
|---|---|
| 0:00-0:30 | 锁 MVP，建目录，确定节点名和 API |
| 0:30-1:30 | M1：修锚、SAN、胜利/失败闭环 |
| 1:30-2:30 | M2：房间切换、窗户/蜡烛状态、基础 UI |
| 2:30-4:00 | M3：Phase 1 破窗事件、修窗 |
| 4:00-5:30 | M4：Phase 2 黑手、熄蜡烛、点蜡烛 / 驱赶 |
| 5:30-6:30 | M5：接美术、音效、灯光、红光提示 |
| 6:30-7:15 | Web 导出、本地预览、修网页端问题 |
| 7:15-8:00 | 只修 bug 和调数值，不加新功能 |

最后 45 分钟冻结功能。

---

## 5. 关键接口约定

### 5.1 实体 ID

```text
room_a 船长室
room_b 休息室
bow_room 走廊

window_room_a_0
window_room_a_1
window_room_b_0
window_room_b_1
window_bow_room_0 休息室方向视角

candle_room_a_0
candle_room_a_1
candle_room_b_0
candle_room_b_1
candle_bow_room_0 船长室方向视角
candle_bow_room_1 休息室方向视角


anchor_device
black_hand
```

### 5.2 程序 A 暴露给 B/C 的 API

```gdscript
repair_anchor(delta: float) -> void
repair_window(window_id: String, delta: float) -> void
light_candle(candle_id: String) -> void
expel_black_hand(candle_id: String) -> void
switch_room(room_id: String) -> void
get_snapshot() -> Dictionary
```

### 5.3 程序 A 发出的信号

```gdscript
signal san_changed(current: float, max_value: float)
signal anchor_progress_changed(value: float)
signal window_changed(window_id: String, durability: int, is_broken: bool)
signal candle_changed(candle_id: String, lit: bool)
signal phase_changed(phase: int)
signal room_changed(room_id: String)
signal attack_started(target_id: String, attack_type: String)
signal attack_resolved(target_id: String, attack_type: String)
signal game_over(result: String)
```

### 5.4 事件限制

第一版只允许同一时间一个怪物事件：

```text
active_attack = null | { type, target_id, timer }
```

不要做多窗同时攻击。这样 UI、SAN、音效和提示都简单。

---

## 6. 建议目录结构

项目根目录建议：

```text
Anchor/
├── autoload/
│   ├── game_manager.gd
│   └── room_manager.gd
├── gameplay/
│   ├── window_attack.gd
│   └── candle_attack.gd
├── interaction/
│   ├── interactable.gd
│   ├── hold_interaction.gd
│   └── click_interaction.gd
├── scenes/
│   ├── main.tscn
│   ├── rooms/
│   │   ├── room_a.tscn
│   │   ├── room_b.tscn
│   │   └── bow_room.tscn
│   └── props/
├── ui/
│   ├── hud.tscn
│   └── hud.gd
├── assets/
│   ├── models/
│   ├── textures/
│   └── audio/
├── docs/
│   ├── DESIGN.md
│   └── UPDATED_DESIGN.md
├── web_build/
│   ├── WEB_PREVIEW.md
│   ├── index.html
│   ├── index.js
│   ├── index.wasm
│   └── index.pck
├── project.godot
└── export_presets.cfg
```

当前如果还有 `new-game-project/`，它可以作为临时 Godot 项目目录，但最终建议把正式项目放到 `Anchor/` 根目录，Web 导出放 `web_build/`。

---

## 7. 场景节点约定

主场景建议：

```text
Main
├── Managers
├── World
│   ├── Rooms
│   │   ├── RoomA
│   │   │   ├── Camera3D
│   │   │   ├── Windows
│   │   │   │   ├── window_room_a_0
│   │   │   │   └── window_room_a_1
│   │   │   ├── Candles
│   │   │   │   ├── candle_room_a_0
│   │   │   │   └── candle_room_a_1
│   │   │   └── Lights
│   │   ├── RoomB
│   │   └── BowRoom
│   │       ├── Camera3D
│   │       └── anchor_device
│   └── Monster
│       └── black_hand
└── CanvasLayer
    └── HUD
```

节点名要稳定。B 和 A 会按这些名字接逻辑和 UI。

---

## 8. 核心 GDScript 模板

### 8.1 GameManager.gd

```gdscript
extends Node

signal san_changed(current: float, max_value: float)
signal anchor_progress_changed(value: float)
signal window_changed(window_id: String, durability: int, is_broken: bool)
signal candle_changed(candle_id: String, lit: bool)
signal phase_changed(phase: int)
signal room_changed(room_id: String)
signal attack_started(target_id: String, attack_type: String)
signal attack_resolved(target_id: String, attack_type: String)
signal game_over(result: String)

const PHASE_WINDOW := 1
const PHASE_CANDLE := 2

var phase := PHASE_WINDOW
var san := 100.0
var san_max := 100.0
var anchor_progress := 0.0
var anchor_target := 60.0
var current_room_id := "room_a"
var is_game_over := false

var windows := {
	"window_room_a_0": {"room": "room_a", "durability": 100.0, "broken": false},
	"window_room_a_1": {"room": "room_a", "durability": 100.0, "broken": false},
	"window_room_b_0": {"room": "room_b", "durability": 100.0, "broken": false},
	"window_room_b_1": {"room": "room_b", "durability": 100.0, "broken": false},
}

var candles := {
	"candle_room_a_0": {"room": "room_a", "lit": true},
	"candle_room_a_1": {"room": "room_a", "lit": true},
	"candle_room_b_0": {"room": "room_b", "lit": true},
	"candle_room_b_1": {"room": "room_b", "lit": true},
}

var active_attack := {}
var attack_timer := 0.0
var next_attack_timer := 6.0

func _process(delta: float) -> void:
	if is_game_over:
		return
	_update_attack(delta)
	_update_san(delta)
	_check_game_over()

func repair_anchor(delta: float) -> void:
	if is_game_over:
		return
	anchor_progress = min(anchor_progress + delta, anchor_target)
	anchor_progress_changed.emit(anchor_progress / anchor_target)

func repair_window(window_id: String, delta: float) -> void:
	if not windows.has(window_id):
		return
	var window = windows[window_id]
	if window.broken:
		return
	window.durability = min(window.durability + 4.0 * delta, 100.0)
	window_changed.emit(window_id, window.durability, window.broken)
	if active_attack.get("target_id", "") == window_id:
		_resolve_attack()

func light_candle(candle_id: String) -> void:
	if not candles.has(candle_id):
		return
	candles[candle_id].lit = true
	candle_changed.emit(candle_id, true)
	if active_attack.get("target_id", "") == candle_id:
		_resolve_attack()

func expel_black_hand(candle_id: String) -> void:
	if active_attack.get("target_id", "") == candle_id:
		_resolve_attack()

func switch_room(room_id: String) -> void:
	current_room_id = room_id
	room_changed.emit(room_id)

func get_snapshot() -> Dictionary:
	return {
		"phase": phase,
		"san": san,
		"san_max": san_max,
		"anchor_progress": anchor_progress / anchor_target,
		"current_room_id": current_room_id,
		"active_attack": active_attack,
	}

func _update_san(delta: float) -> void:
	var all_lit := true
	for candle in candles.values():
		if not candle.lit:
			all_lit = false
			break

	if all_lit:
		san += delta * 1.5

	if active_attack:
		if active_attack.type == "window":
			san -= delta * 1.0
		elif active_attack.type == "candle" and not candles[active_attack.target_id].lit:
			san -= delta * 5.0

	san = clamp(san, 0.0, san_max)
	san_changed.emit(san, san_max)

func _update_attack(delta: float) -> void:
	if active_attack:
		attack_timer -= delta
		if active_attack.type == "window":
			_damage_window(active_attack.target_id, delta)
		if attack_timer <= 0.0:
			_attack_timeout()
		return

	next_attack_timer -= delta
	if next_attack_timer <= 0.0:
		_start_random_attack()

func _start_random_attack() -> void:
	if phase == PHASE_WINDOW:
		var ids := windows.keys()
		var target_id = ids[randi() % ids.size()]
		active_attack = {"type": "window", "target_id": target_id}
		attack_timer = randf_range(8.0, 15.0)
		attack_started.emit(target_id, "window")
	else:
		var lit_ids := []
		for id in candles.keys():
			if candles[id].lit:
				lit_ids.append(id)
		if lit_ids.is_empty():
			next_attack_timer = 4.0
			return
		var target_id = lit_ids[randi() % lit_ids.size()]
		active_attack = {"type": "candle", "target_id": target_id}
		attack_timer = 15.0
		attack_started.emit(target_id, "candle")

func _damage_window(window_id: String, delta: float) -> void:
	var window = windows[window_id]
	if window.broken:
		return
	window.durability = max(window.durability - 5.0 * delta, 0.0)
	if window.durability <= 0.0:
		window.broken = true
		_enter_phase_2()
	window_changed.emit(window_id, window.durability, window.broken)

func _attack_timeout() -> void:
	if active_attack.type == "candle":
		var candle_id = active_attack.target_id
		candles[candle_id].lit = false
		candle_changed.emit(candle_id, false)
	_resolve_attack()

func _resolve_attack() -> void:
	if active_attack:
		attack_resolved.emit(active_attack.target_id, active_attack.type)
	active_attack = {}
	next_attack_timer = randf_range(6.0, 12.0)

func _enter_phase_2() -> void:
	if phase == PHASE_CANDLE:
		return
	phase = PHASE_CANDLE
	san_max = 80.0
	san = min(san, san_max)
	phase_changed.emit(phase)
	san_changed.emit(san, san_max)

func _check_game_over() -> void:
	if san <= 0.0:
		is_game_over = true
		game_over.emit("lose")
	elif anchor_progress >= anchor_target:
		is_game_over = true
		game_over.emit("win")
```

### 8.2 长按交互模板

```gdscript
extends Button

@export var target_id := "anchor_device"
@export var action := "repair_anchor"

var holding := false

func _process(delta: float) -> void:
	if not holding:
		return
	if action == "repair_anchor":
		GameManager.repair_anchor(delta)
	elif action == "repair_window":
		GameManager.repair_window(target_id, delta)

func _on_button_down() -> void:
	holding = true

func _on_button_up() -> void:
	holding = false
```

### 8.3 HUD 绑定模板

```gdscript
extends Control

@onready var san_bar: ProgressBar = $SanBar
@onready var anchor_bar: ProgressBar = $AnchorBar
@onready var result_label: Label = $ResultLabel

func _ready() -> void:
	GameManager.san_changed.connect(_on_san_changed)
	GameManager.anchor_progress_changed.connect(_on_anchor_progress_changed)
	GameManager.game_over.connect(_on_game_over)

func _on_san_changed(current: float, max_value: float) -> void:
	san_bar.max_value = max_value
	san_bar.value = current

func _on_anchor_progress_changed(value: float) -> void:
	anchor_bar.value = value * 100.0

func _on_game_over(result: String) -> void:
	if result == "win":
		result_label.text = "锚修好了，你活下来了"
	else:
		result_label.text = "SAN 归零，游戏结束"
```

### 8.4 相机切换模板

```gdscript
extends Node

@export var cameras: Dictionary = {
	"room_a": NodePath("../World/Rooms/RoomA/Camera3D"),
	"room_b": NodePath("../World/Rooms/RoomB/Camera3D"),
	"bow_room": NodePath("../World/Rooms/BowRoom/Camera3D"),
}

func _ready() -> void:
	GameManager.room_changed.connect(_on_room_changed)
	_on_room_changed("room_a")

func _on_room_changed(room_id: String) -> void:
	for id in cameras.keys():
		var camera: Camera3D = get_node(cameras[id])
		camera.current = id == room_id
```

---

## 9. 重要 Godot 操作

### 建项目

- 使用 Godot 4.x。
- 使用 GDScript。
- Web 导出不要用 C#。
- Renderer 优先 Compatibility。

### Autoload

`GameManager.gd` 需要加到：

```text
Project -> Project Settings -> Globals -> Autoload
```

名字填：

```text
GameManager
```

### 连接按钮事件

按钮节点：

```text
Button -> Node 面板 -> Signals
```

常用信号：

```text
button_down
button_up
pressed
```

### 导入模型

建议美术交：

```text
.glb
```

优先级：

```text
GLB > glTF > FBX
```

每个关键物体最好单独导出：

```text
window.glb
candle.glb
anchor_device.glb
black_hand.glb
room_a.glb
room_b.glb
```

### Web 预览

导出到：

```text
web_build/index.html
```

本地预览：

```bash
cd "/home/abcd/Documents/gamejam/cicg2026/anchor/Anchor/web_build"
python3 -m http.server 8060
```

浏览器打开：

```text
http://localhost:8060/
```

不要直接双击 `index.html`。

---

## 10. 数值规范（与 `autoload/game_manager.gd` 一致）

### 10.1 SAN

| 项 | 值 | 说明 |
|---|---|---|
| 初始值 | `100` | 开局 `san = san_max = 100` |
| Phase 1 上限 | `100` | 破窗前 |
| Phase 2 上限 | `80` | 任一窗户破碎后 `san_max = 80`，当前 SAN 截断到上限 |
| 胜利条件 | 锚进度满 | `anchor_progress >= anchor_target`（目标 60 秒） |
| 失败条件 | SAN 归零 | `san <= 0` |

**每帧变化（`_update_san`，可叠加）：**

| 条件 | 公式 | 备注 |
|---|---|---|
| 全蜡烛点亮 | `san += delta * 1.5` | 6 根全亮才生效 |
| Phase 1 窗户正被袭击 | `san -= delta * 1.0` | 仅 `active_attack.type == "window"` 时 |
| Phase 2 有蜡烛熄灭 | `san -= delta * 5.0 * unlit_count` | `unlit_count` 为**全局**熄灭蜡烛数（含走廊两视角） |

最终：`san = clamp(san, 0, san_max)`。

### 10.2 窗户耐久

| 项 | 值 | 说明 |
|---|---|---|
| 类型 | `int` | 信号 `window_changed` 的 `durability` 为整数 |
| 上限 | `100` | `WINDOW_DURABILITY_MAX` |
| 初始值 | `100` | 每扇窗开局满耐久 |
| 破碎 | `durability <= 0` | 设 `broken = true`，触发进入 Phase 2 |

**状态与耐久变化：**

| 状态 | 公式 | 作用范围 |
|---|---|---|
| 正常 | 无被动衰减 | — |
| 怪物袭击中 | `durability -= 5 * delta` | 仅 `active_attack` 指向的那扇窗 |
| 全局时间 > 2min | `durability -= 8 * delta` | **所有**未碎窗户（被动衰减，与是否开启袭击无关） |
| 袭击 + 超过 2min | 上两项叠加 | 被袭窗户合计 `-13 * delta` |
| 玩家修补（按住） | `durability += 4 * delta` | 当前视角内、未碎、未满的窗；修满或化解袭击 |

**时间与常量：**

| 常量 | 值 |
|---|---|
| `game_time` | 从开局累计秒数，`reset_game()` 归零；`get_snapshot()` 含 `"game_time"` |
| `GAME_TIME_PASSIVE_DECAY_SEC` | `120`（2 分钟） |
| `WINDOW_ATTACK_RATE` | `5` |
| `WINDOW_PASSIVE_DECAY_RATE` | `8` |
| `WINDOW_REPAIR_RATE` | `4` |

内部用小数余量 `_durability_frac` 累积帧间变化，对外展示的 `durability` 始终为整数。

### 10.3 事件与其它建议值

| 项 | 建议值 |
|---|---|
| 锚修理目标 | 60 秒（试玩太难可改为 45） |
| Phase 1 袭击持续 | 8–15 秒（随机） |
| 袭击间隔 | 6–12 秒（随机） |
| Phase 2 黑手掐灭倒计时 | 15 秒 |
| 驱赶黑手点击次数 | 5–8 次 |

如果试玩太难，先把锚修理目标改成 45 秒。

---

## 11. 美术交付要求

发给美术：

```text
请尽量交 .glb 文件，每个物件单独导出：
- room_a / room_b / bow_room
- window
- candle
- anchor_device
- wood_board
- black_hand

要求：
- 低模，网页端能跑
- 贴图打包或放同目录
- 比例统一，1 Godot unit 约等于 1 米
- 模型原点合理，窗户/蜡烛/锚方便摆放
- 黑手动画如果来不及，只给静态模型也可以
```

---

## 12. 提交与协作规则

- 不要多人同时改同一个 `.tscn`。
- A 主要改 `autoload/`、`gameplay/`。
- B 主要改 `interaction/`、`ui/`。
- C 主要改 `scenes/`、`assets/`、`web_build/`。
- `.godot/` 是本地缓存目录，一般不要提交。
- Web 展示要提交整个 `web_build/`，不能只提交 `index.html`。
- 最后 45 分钟不加功能，只修 bug。

---

## 13. 里程碑验收

### M1：闭环

- 点修锚，锚进度上涨。
- SAN 会变化。
- 锚满胜利。
- SAN 归零失败。

### M2：房间与 UI

- 能切 `room_a`、`room_b`、`bow_room`。
- SAN UI 正确。
- 锚 UI 正确。
- 窗户 / 蜡烛状态能显示。

### M3：Phase 1

- 怪物会随机攻击窗户。
- 被攻击窗户高亮 / 小地图提示。
- 修窗能解决事件。

### M4：Phase 2

- 任一窗户破掉后进入 Phase 2。
- 黑手出现。
- 蜡烛会灭。
- 点蜡烛 / 驱赶黑手能处理事件。

### M5：展示

- 有美术模型或至少灰盒完整。
- 有灯光和音效。
- Web 导出可打开。

### M6：Polish

- 黑屏转场。
- 相机小角度旋转。
- 惊吓演出。
- 数值调优。

---

## 14. 最重要原则

第一目标：做出一个能玩的网页游戏。  
第二目标：让它看起来像恐怖游戏。  
第三目标：代码变漂亮。

不要反过来。
