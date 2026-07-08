# GameManager API（程序 B / C 用）

> 权威实现：`autoload/game_manager.gd`  
> 实体 ID / 机位：`docs/ENTITY_IDS.md`  
> 数值规则：`docs/UPDATED_DESIGN.md` §10  

Autoload 名：**`GameManager`**。B/C **只读状态、只调公开 API**，不要直接改 `GameManager.windows` / `candles` 等字典。

---

## 1. 快速索引

| 角色 | 主要用途 |
|---|---|
| **B** | 调交互 API、听信号、读 `get_snapshot()` 驱动 UI / 音效 / 读条 |
| **C** | 场景节点名 = 实体 ID；听信号做高亮、黑手模型、相机切换；**不调**玩法 API |

---

## 2. 常量

| 名称 | 值 | 说明 |
|---|---|---|
| `PHASE_WINDOW` | `1` | 破窗阶段 |
| `PHASE_CANDLE` | `2` | 任一窗户破碎后 |
| `WINDOW_DURABILITY_MAX` | `100` | 窗户耐久上限（int） |

---

## 3. 信号

| 信号 | 参数 | 何时触发 | B/C 用途 |
|---|---|---|---|
| `san_changed` | `current: float, max_value: float` | SAN 变化 | SAN 条 |
| `anchor_progress_changed` | `value: float` | 0.0–1.0 | 锚进度条 |
| `window_changed` | `window_id, durability: int, is_broken: bool` | 耐久整数变化 / 破碎 | 窗 UI、特效 |
| `candle_changed` | `candle_id, lit: bool` | 蜡烛亮灭 | 烛火模型 / 光 |
| `phase_changed` | `phase: int` | 进入 Phase 2 | 氛围切换 |
| `phase1_ended` | `broken_window_id: String` | 首个窗户耐久归零、进入 Phase 2 前后 | 播放破窗音效；把破窗粒子移动到对应窗户并触发 |
| `room_changed` | `view_id: String` | 切换视角后 | **C 切相机**（参数是视角 id，不是逻辑房间名） |
| `attack_started` | `target_id, attack_type: String` | 怪物事件开始 | 高亮 / 小地图 / 音效；`attack_type` 为 `"window"` 或 `"candle"` |
| `attack_resolved` | `target_id, attack_type: String` | 事件被化解或超时结束 | 取消高亮、停音效 |
| `black_hand_expel_changed` | `target_id, progress: int, required: int` | 每次成功驱赶点击 | 连点进度 UI（`progress/required`） |
| `game_over` | `result: String` | 胜负已定 | `"win"` / `"lose"` |

**约定：** 同一时间最多一个 `active_attack`（一个怪物事件）。

---

## 4. 交互 API（程序 B）

所有带 `-> bool` 的方法：**`true` = 本次操作生效**，`false` = 被拒绝（游戏结束、ID 无效、视角不对、条件不满足等）。

### 4.1 锚与房间

| 方法 | 说明 |
|---|---|
| `repair_anchor(delta: float) -> void` | 按住修锚时每帧调用；进度满触发 `game_over("win")` |
| `switch_room(view_id: String) -> void` | 切视角/相机。合法值见下表 |

**`switch_room` 合法 `view_id`：**

| view_id | 逻辑房间 `current_room_id` |
|---|---|
| `room_a` | `room_a` |
| `room_b` | `room_b` |
| `bow_room_0` | `bow_room` |
| `bow_room_1` | `bow_room` |

### 4.2 窗户（Phase 1 为主）

| 方法 | 说明 |
|---|---|
| `repair_window(window_id, delta) -> bool` | 长按修窗；+4/s 耐久；若该窗正在被袭击，袭击仍持续，直到怪物计时结束或窗户破碎 |
| `can_repair_window(window_id) -> bool` | 未碎、未满、**当前视角可交互** |

修窗 UI 请用 **`get_window_durability_value(window_id)`** 或 snapshot 的 `durability_exact` 做平滑进度条（整数 `durability` 会阶梯变化）。

### 4.3 蜡烛

| 方法 | 说明 |
|---|---|
| `light_candle(candle_id) -> bool` | 点亮**已熄灭**的蜡烛；**不能**用来驱赶 Phase 2 黑手 |
| `can_light_candle(candle_id) -> bool` | 已熄灭且当前视角可交互 |
| `expel_black_hand(candle_id) -> bool` | 连点驱赶；**`candle_id` 必须是当前袭击目标**；需 5–8 次（每次袭击随机，见 `black_hand_expel_changed`） |
| `can_expel_black_hand(candle_id) -> bool` | 当前视角内且该烛正在被黑手袭击 |

**重要：** 驱赶时不要用 `get_primary_lit_candle_in_view()` 猜目标，应使用：

```gdscript
var target := GameManager.get_candle_under_attack_in_view()
if target != "":
	GameManager.expel_black_hand(target)
```

若袭击目标不在当前视角，提示玩家切换房间（读 `get_active_attack_target()`）。

### 4.4 开局与袭击开关

| 方法 | 说明 |
|---|---|
| `set_attacks_enabled(true)` | 主场景开局后调用，开启 Phase 1/2 随机袭击 |
| `reset_game()` | 重开一局（通常仅菜单/测试用） |

---

## 5. 查询 API（程序 B · UI / 小地图）

| 方法 | 返回值 | 说明 |
|---|---|---|
| `get_snapshot()` | `Dictionary` | **推荐**每帧或按需拉全量状态 |
| `get_window_state(window_id)` | `Dictionary` | 单窗状态 |
| `get_candle_state(candle_id)` | `Dictionary` | 单烛状态 |
| `get_window_durability_value(window_id)` | `float` | 含小数余量的耐久（0–100） |
| `get_active_attack_target()` | `String` | 当前袭击实体 id；无则 `""` |
| `is_window_under_attack(window_id)` | `bool` | Phase 1 破窗事件 |
| `is_candle_under_attack(candle_id)` | `bool` | Phase 2 黑手事件 |
| `get_candle_under_attack_in_view()` | `String` | 当前视角内被袭击的蜡烛 id；无则 `""` |
| `get_black_hand_expel_state()` | `Dictionary` | 见 §6.3；无黑手时 `{}` |
| `get_window_ids_in_current_view()` | `Array[String]` | 当前视角所有窗 |
| `get_candle_ids_in_current_view()` | `Array[String]` | 当前视角所有烛 |
| `count_unlit_candles()` | `int` | 全局熄灭蜡烛数 |

---

## 6. `get_snapshot()` 结构

```gdscript
{
	"phase": int,                    # 1=PHASE_WINDOW, 2=PHASE_CANDLE
	"san": float,
	"san_max": float,
	"anchor_progress": float,        # 0.0–1.0
	"current_room_id": String,     # 逻辑房间 room_a / room_b / bow_room
	"current_view_id": String,     # 当前相机视角
	"game_time": float,            # 开局累计秒数
	"attacks_enabled": bool,
	"attack_timer": float,         # 当前袭击剩余秒数；无袭击时仍可读
	"next_attack_timer": float,    # 距下次随机袭击
	"unlit_candle_count": int,
	"active_attack": Dictionary,   # {} 或 {"type":"window"|"candle", "target_id": "...", ...}
	"black_hand": Dictionary,      # {} 或见下表
	"is_game_over": bool,
	"windows": { window_id: {...} },
	"candles": { candle_id: {...} },
}
```

### 6.1 `windows[window_id]`

| 字段 | 类型 | 说明 |
|---|---|---|
| `room` | String | 逻辑房间 |
| `view` | String | 可交互视角 |
| `durability` | int | 整数耐久 0–100 |
| `durability_exact` | float | **UI 推荐**，含小数 |
| `broken` | bool | 是否已碎 |

### 6.2 `candles[candle_id]`

| 字段 | 类型 | 说明 |
|---|---|---|
| `room` | String | 逻辑房间 |
| `view` | String | 可交互视角 |
| `lit` | bool | 是否点燃 |

### 6.3 `black_hand`（Phase 2 且有黑手袭击时）

| 字段 | 类型 | 说明 |
|---|---|---|
| `target_id` | String | 被袭击蜡烛 id |
| `expel_progress` | int | 已驱赶点击次数 |
| `expel_required` | int | 需要次数（5–8） |
| `time_left` | float | 掐灭倒计时（秒） |

---

## 7. 视角与交互规则

```
仅当 entity.view == GameManager.current_view_id 时，
repair_window / light_candle / expel_black_hand 等交互 API 才会成功。
```

| 场景 | B 做法 |
|---|---|
| 小地图显示全局袭击 | 读 `get_active_attack_target()`，与视角无关 |
| 玩家在当前视角操作 | 必须切到 `entity.view` 对应的 `switch_room(view_id)` |
| 走廊 | `bow_room_0` 只能交互 `candle_bow_room_0`；`bow_room_1` 可交互 `window_bow_room_0` + `candle_bow_room_1` |

---

## 8. 阶段与事件行为（联调摘要）

### Phase 1（`phase == 1`）

- 随机袭击未碎窗户，`attack_type == "window"`
- 袭击中该窗 `-5/s` 耐久；修窗不会化解袭击，怪物只会在本次袭击随机时间结束后停止并准备下一次袭击
- 任一窗户耐久归零时进入 Phase 2，并发出 `phase1_ended(broken_window_id)`，`broken_window_id` 是破碎窗户实体 ID
- 袭击中 SAN 额外 `-1/s`（与全烛 +1.5/s 可叠加）
- `game_time > 120s` 后所有未碎窗额外 `-8/s` 被动衰减

### Phase 2（`phase == 2`，任一窗户破碎后）

- `san_max` 变为 80
- 随机袭击**仍亮着**的蜡烛，`attack_type == "candle"`
- 15s 内未驱赶 → 蜡烛熄灭；驱赶需连点 5–8 次
- 每有一根全局熄灭蜡烛，SAN `-5/s`

---

## 9. 程序 B 推荐接法

```gdscript
# _ready
GameManager.san_changed.connect(_on_san_changed)
GameManager.anchor_progress_changed.connect(_on_anchor_changed)
GameManager.window_changed.connect(_on_window_changed)
GameManager.candle_changed.connect(_on_candle_changed)
GameManager.phase1_ended.connect(_on_phase1_ended)
GameManager.room_changed.connect(_on_room_changed)          # C 也听
GameManager.attack_started.connect(_on_attack_started)
GameManager.attack_resolved.connect(_on_attack_resolved)
GameManager.black_hand_expel_changed.connect(_on_expel_progress)
GameManager.phase_changed.connect(_on_phase_changed)
GameManager.game_over.connect(_on_game_over)

# 开局（主场景）
GameManager.reset_game()          # 若需要
GameManager.set_attacks_enabled(true)

# 长按修窗（_process）
if holding:
	GameManager.repair_window(window_id, delta)

# 连点驱赶黑手
func _on_black_hand_clicked(candle_id: String) -> void:
	GameManager.expel_black_hand(candle_id)

# 切房间按钮
GameManager.switch_room("bow_room_0")
```

---

## 10. 程序 C 推荐接法

| 任务 | 做法 |
|---|---|
| 节点命名 | 与实体 id 一致，如 `window_room_a_0`、`candle_room_a_1`、`anchor_device`、`black_hand` |
| 切相机 | 听 `room_changed(view_id)`，切换到对应 `Camera3D` |
| 窗/烛状态 | 听 `window_changed` / `candle_changed`，或轮询 `get_snapshot()` |
| Phase 1 结束音效 / 破窗粒子 | 听 `phase1_ended(broken_window_id)`；用 `broken_window_id` 找同名 `Area3D`，把一个共用粒子移动过去播放 |
| 被袭高亮 | 听 `attack_started` / `attack_resolved`；`target_id` 匹配节点名 |
| 黑手模型 | `attack_type == "candle"` 时在 `target_id` 蜡烛节点旁显示 `black_hand`；`attack_resolved` 隐藏 |
| 耐久/烛火 | 窗用 `durability_exact` 做材质/动画；烛用 `lit` 控制可见与灯光 |

**C 不要调用** `repair_window`、`light_candle` 等玩法 API（交给 B 的交互层）。

---

## 11. 测试专用 API（B/C 正式场景勿依赖）

| 方法 | 用途 |
|---|---|
| `force_window_attack(window_id, duration)` | 测试强制破窗事件 |
| `force_candle_attack(candle_id, duration, expel_required=-1)` | 测试强制黑手 |
| `skip_attack_cooldown()` | 跳过袭击间隔 |
| `enter_phase_2_for_test()` | 不进破窗直接 Phase 2 |
| `chip_window_damage` / `break_window` / `extinguish_candle` | 调试 / 自动测试 |

---

## 12. 验收场景（程序 A 提供）

| 场景 | 文件 |
|---|---|
| M1 锚 / SAN / 胜负 | `gameplay/m1_test.tscn` |
| M2 房间 / 窗烛 | `gameplay/m2_test.tscn` |
| M3 Phase 1 破窗 | `gameplay/m3_test.tscn` |
| M4 Phase 2 黑手 | `gameplay/m4_test.tscn` |

---

## 13. 修订记录

| 版本 | 日期 | 说明 |
|---|---|---|
| 1.0 | 2026-07-05 | 初版：M1–M4 完整 API、snapshot、B/C 分工 |
