# 实体 ID 与房间机位对照表

> 与 `docs/UPDATED_DESIGN.md` §5.1 一致。  
> 程序 A：`GameManager` 字典。程序 B：按 ID 调 API。程序 C：场景节点名 = ID。

---

## 1. 区域总览

| 逻辑房间 `current_room_id` | 中文名 | 可切换视角 `current_view_id` | 窗户 | 蜡烛 |
|---|---|---|---|---|
| `room_a` | 船长室 | `room_a` | 2 | 2 |
| `room_b` | 休息室 | `room_b` | 2 | 2 |
| `bow_room` | 走廊（逻辑合一） | `bow_room_0` / `bow_room_1` | 1 | 2 |

**合计：** 5 扇窗 · 6 根蜡烛 · `anchor_device` · `black_hand`

### 走廊规则

- `bow_room_0`、`bow_room_1` 是 **两个相机视角**，逻辑上同属 `bow_room`。
- **SAN / 阶段 / 胜负** 看全局状态（含走廊两视角的全部烛/窗）。
- **交互** 仅允许操作 `view == current_view_id` 的物体（A 在 API 内校验）。
- B/C：`switch_room("bow_room_0")` 切相机；`room_changed` 信号参数为 **视角 id**。

---

## 2. 机位与相机（程序 C）

| current_view_id | 中文 | 相机 | 可见可交互实体 |
|---|---|---|---|
| `room_a` | 船长室 | `RoomA/Camera3D` | room_a 全部窗/烛 |
| `room_b` | 休息室 | `RoomB/Camera3D` | room_b 全部窗/烛 |
| `bow_room_0` | 走廊 · 船长室方向 | `BowRoom/CameraCaptain` | `candle_bow_room_0` |
| `bow_room_1` | 走廊 · 休息室方向 | `BowRoom/CameraLounge` | `window_bow_room_0`, `candle_bow_room_1` |

```gdscript
GameManager.switch_room("room_a")
GameManager.switch_room("room_b")
GameManager.switch_room("bow_room_0")  # 走廊视角 0
GameManager.switch_room("bow_room_1")  # 走廊视角 1
```

---

## 3. 窗户

| window_id | room | view | 说明 |
|---|---|---|---|
| `window_room_a_0` | `room_a` | `room_a` | 船长室 |
| `window_room_a_1` | `room_a` | `room_a` | 船长室 |
| `window_room_b_0` | `room_b` | `room_b` | 休息室 |
| `window_room_b_1` | `room_b` | `room_b` | 休息室 |
| `window_bow_room_0` | `bow_room` | `bow_room_1` | 走廊 · 仅休息室方向视角可修 |

---

## 4. 蜡烛

| candle_id | room | view | 说明 |
|---|---|---|---|
| `candle_room_a_0` | `room_a` | `room_a` | 船长室 |
| `candle_room_a_1` | `room_a` | `room_a` | 船长室 |
| `candle_room_b_0` | `room_b` | `room_b` | 休息室 |
| `candle_room_b_1` | `room_b` | `room_b` | 休息室 |
| `candle_bow_room_0` | `bow_room` | `bow_room_0` | 走廊 · 船长室方向视角 |
| `candle_bow_room_1` | `bow_room` | `bow_room_1` | 走廊 · 休息室方向视角 |

---

## 5. SAN 规则（程序 A 已实现）

| 条件 | 每帧变化 |
|---|---|
| 全部蜡烛亮着（阶段 1&2） | `+ delta * 1.5` |
| 阶段 1 且窗户正被攻击 | `- delta * 1` |
| 阶段 2 且有蜡烛熄灭 | `- delta * 5 * 熄灭蜡烛个数` |

`get_snapshot()["unlit_candle_count"]` 可给 UI 显示。

---

## 6. 程序 B / C API

完整接口表见 **`docs/API_FOR_BC.md`**（信号、交互 API、`get_snapshot` 结构、阶段行为、B/C 接法示例）。

常用入口：

```gdscript
GameManager.switch_room(view_id)
GameManager.repair_window(window_id, delta)
GameManager.light_candle(candle_id)
GameManager.expel_black_hand(candle_id)
GameManager.can_repair_window(window_id)
GameManager.can_light_candle(candle_id)
GameManager.can_expel_black_hand(candle_id)
GameManager.get_candle_under_attack_in_view()
GameManager.get_snapshot()
```

---

## 7. 修订记录

| 版本 | 日期 | 说明 |
|---|---|---|
| 2.2 | 2026-07-05 | API 迁至 docs/API_FOR_BC.md |
| 2.1 | 2026-07-04 | 走廊双视角；SAN 按灭烛数量扣；view 字段 |
| 2.0 | 2026-07-04 | 对齐 UPDATED_DESIGN §5.1 |
