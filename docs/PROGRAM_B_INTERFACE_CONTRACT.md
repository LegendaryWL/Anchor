# 程序 B 对接约定：场景和接口

> 目标：补齐 M0“对齐场景和接口”。  
> 状态：程序 B 侧对接草案，可作为 A/C 最终确认清单。  
> 当前结论：正式接入优先使用 `bow_room`；`room_bow` 只作为旧 mock 兼容名。

## 1. 范围

本文只定义程序 B 需要依赖的 ID、节点、信号和绑定方式。

程序 B 负责：

- 房间切换。
- 长按 / 连点交互。
- HUD、读条、小地图、退出窗口、胜负界面。
- 音效反馈。

程序 B 不负责：

- 怪物随机攻击规则。
- SAN、胜负、耐久、蜡烛亮灭的权威数据。
- 模型导入、材质、动画、灯光、Web 导出。

## 2. 统一 ID

### 2.1 房间 ID

| 含义 | 正式 ID | 兼容旧名 | 备注 |
|---|---|---|---|
| 房间 A | `room_a` | 无 | 有窗户和蜡烛 |
| 房间 B | `room_b` | 无 | 有窗户和蜡烛 |
| 船头 / 锚房间 | `bow_room` | `room_bow` | 正式接入时统一用 `bow_room` |

说明：

- `docs/UPDATED_DESIGN.md` 使用 `bow_room`。
- 旧版 mock 脚本曾使用 `room_bow`。
- 程序 B 正式接主场景时建议把导出变量改为 `bow_room`；如短期不改代码，可在 `RoomSwitcher` 和 `Minimap` 的导出字段里手动填 `bow_room`。

### 2.2 窗户 ID

| 房间 | 窗户 0 | 窗户 1 |
|---|---|---|
| `room_a` | `window_room_a_0` | `window_room_a_1` |
| `room_b` | `window_room_b_0` | `window_room_b_1` |

规则：

- ID 格式已在当前代码中落地为 `window_room_a_0` 这种形式。
- B 侧只使用这些 ID 调用 `RoomStateManager` 和 `EventManager`。
- 破损窗口不可再修，由 A/状态层控制。

### 2.3 蜡烛 ID

| 房间 | 蜡烛 0 | 蜡烛 1 |
|---|---|---|
| `room_a` | `candle_room_a_0` | `candle_room_a_1` |
| `room_b` | `candle_room_b_0` | `candle_room_b_1` |

规则：

- B 侧长按重燃蜡烛时使用蜡烛 ID。
- 黑手事件的目标 ID 也是蜡烛 ID。
- `bow_room` 暂不放蜡烛，除非 A/C 后续扩展。

### 2.4 其他目标 ID

| 含义 | ID |
|---|---|
| 锚回收装置 | `anchor_device` |
| 黑手交互目标 | `black_hand` 或对应蜡烛 ID |

说明：

- 当前 `ClickSpamInteraction` 的 `target_id` 建议填被攻击蜡烛 ID，例如 `candle_room_a_0`，这样可以直接结束 `CandleExtinguishEvent`。
- 场景中黑手模型节点可以命名为 `black_hand`，但行为消息的目标仍优先使用蜡烛 ID。

## 3. A 侧接口约定

程序 B 只调用当前已有单例，不复制权威状态。

### 3.1 `GameProcessManager`

B 侧使用：

```gdscript
GameProcessManager.add_repair_time(delta)
GameProcessManager.get_snapshot()
```

B 侧监听：

```gdscript
GameProcessManager.san_changed(current, max_san)
GameProcessManager.repair_progress_changed(accum, target)
GameProcessManager.phase_changed(old_phase, new_phase)
GameProcessManager.game_over(reason)
```

### 3.2 `RoomStateManager`

B 侧使用：

```gdscript
RoomStateManager.set_current_room(room_id)
RoomStateManager.modify_window_durability(window_id, delta)
RoomStateManager.set_candle_lit(candle_id, true)
RoomStateManager.get_window_state(window_id)
RoomStateManager.get_candle_state(candle_id)
RoomStateManager.can_fix_window(window_id)
```

B 侧监听：

```gdscript
RoomStateManager.room_changed(room_id)
RoomStateManager.window_durability_changed(window_id, durability)
RoomStateManager.candle_lit_changed(candle_id, lit)
```

### 3.3 `EventManager`

B 侧使用：

```gdscript
EventManager.on_behavior_message(BehaviorMessage.create("fix_window", window_id, true))
EventManager.on_behavior_message(BehaviorMessage.create("expel_black_hand", candle_id, true))
EventManager.on_behavior_message(BehaviorMessage.create("light_candle", candle_id, true))
```

B 侧可监听：

```gdscript
EventManager.window_attack_event.state_changed
EventManager.candle_extinguish_event.state_changed
```

## 4. C 侧场景节点约定

C 不需要严格按某个绝对路径摆节点，但需要提供下面这些节点给 B 绑定。

### 4.1 相机节点

| 用途 | 推荐节点名 | 推荐 group | B 侧绑定 |
|---|---|---|---|
| 房间 A 相机 | `CameraRoomA` | `camera_room_a` | `RoomSwitcher.room_a_camera_path` |
| 房间 B 相机 | `CameraRoomB` | `camera_room_b` | `RoomSwitcher.room_b_camera_path` |
| 船头相机 | `CameraBow` | `camera_bow_room` | `RoomSwitcher.bow_room_camera_path` |

要求：

- 每个节点类型为 `Camera3D`。
- 正式主场景中同一时间只允许一个房间相机 `current = true`。

### 4.2 可交互节点

| 目标 | 推荐节点名 | 推荐 group | B 侧脚本 |
|---|---|---|---|
| 锚回收装置 | `AnchorDevice` | `interactable_anchor_device` | `HoldInteraction(action_type="repair_anchor", target_id="anchor_device")` |
| A0 窗 | `WindowRoomA0` | `interactable_window_room_a_0` | `HoldInteraction(action_type="fix_window", target_id="window_room_a_0")` |
| A1 窗 | `WindowRoomA1` | `interactable_window_room_a_1` | `HoldInteraction(action_type="fix_window", target_id="window_room_a_1")` |
| B0 窗 | `WindowRoomB0` | `interactable_window_room_b_0` | `HoldInteraction(action_type="fix_window", target_id="window_room_b_0")` |
| B1 窗 | `WindowRoomB1` | `interactable_window_room_b_1` | `HoldInteraction(action_type="fix_window", target_id="window_room_b_1")` |
| A0 蜡烛 | `CandleRoomA0` | `interactable_candle_room_a_0` | `HoldInteraction(action_type="light_candle", target_id="candle_room_a_0")` |
| A1 蜡烛 | `CandleRoomA1` | `interactable_candle_room_a_1` | `HoldInteraction(action_type="light_candle", target_id="candle_room_a_1")` |
| B0 蜡烛 | `CandleRoomB0` | `interactable_candle_room_b_0` | `HoldInteraction(action_type="light_candle", target_id="candle_room_b_0")` |
| B1 蜡烛 | `CandleRoomB1` | `interactable_candle_room_b_1` | `HoldInteraction(action_type="light_candle", target_id="candle_room_b_1")` |
| 黑手 | `BlackHand` | `interactable_black_hand` | `ClickSpamInteraction(action_type="expel_black_hand", target_id=<被攻击蜡烛 ID>)` |

建议：

- 可交互节点可以用 `Area3D`、`StaticBody3D` 或 UI 按钮触发，B 只要求能接到按下、松开、点击事件。
- 每个节点建议写入 metadata：`target_id` 和 `interaction_type`，方便后续自动绑定。

### 4.3 场景提示节点

| 用途 | 推荐节点名 / group |
|---|---|
| A0 窗红光 | `red_light_window_room_a_0` |
| A1 窗红光 | `red_light_window_room_a_1` |
| B0 窗红光 | `red_light_window_room_b_0` |
| B1 窗红光 | `red_light_window_room_b_1` |
| 黑手显示根节点 | `black_hand_root` |

这些节点主要由 C 控制视觉表现，B 只需要在交互成功时通过事件消息通知 A/事件层。

## 5. UI 节点约定

主场景建议有一个 UI 根：

```text
CanvasLayer
└── UI
    ├── HUD
    ├── ProgressPrompt
    ├── Minimap
    ├── ExitDialog
    └── GameResultScreen
```

B 侧组件通过导出 `NodePath` 绑定，不强制固定绝对路径。

必须绑定：

- `HUD`
  - SAN 文本和条。
  - 锚修理进度文本和条。
  - 阶段文本。
  - 当前房间文本。
  - 当前房间窗户状态文本。
  - 当前房间蜡烛状态文本。
- `ProgressPrompt`
  - 读条文本。
  - 读条 `ProgressBar`。
- `Minimap`
  - `room_a` 按钮。
  - `room_b` 按钮。
  - `bow_room` 按钮。
- `ExitDialog`
  - 右上角退出入口。
  - 确认按钮。
- `GameResultScreen`
  - 标题文本。
  - 正文文本。
  - 返回主界面按钮。
- `AudioFeedback`
  - 可挂在主场景根节点或 UI 根旁边。

## 6. B 侧脚本接入方式

### 6.1 房间切换

`RoomSwitcher`：

```gdscript
room_a_id = "room_a"
room_b_id = "room_b"
bow_room_id = "bow_room"
```

绑定三个相机 `NodePath`。

`Minimap`：

```gdscript
room_a_id = "room_a"
room_b_id = "room_b"
bow_room_id = "bow_room"
```

绑定三个按钮 `NodePath`。

### 6.2 长按交互

修锚：

```gdscript
action_type = "repair_anchor"
target_id = "anchor_device"
required_hold_time = 1.5 # 正式数值可由策划调
```

修窗：

```gdscript
action_type = "fix_window"
target_id = "window_room_a_0"
required_hold_time = 2.0
```

点蜡烛：

```gdscript
action_type = "light_candle"
target_id = "candle_room_a_0"
required_hold_time = 1.0
```

### 6.3 连点黑手

```gdscript
action_type = "expel_black_hand"
target_id = "candle_room_a_0"
required_clicks = 5
reset_after_seconds = 2.0
```

`target_id` 必须是当前被黑手攻击的蜡烛 ID。

### 6.4 音效反馈

`AudioFeedback` 默认监听全局信号：

- 攻窗事件 active：撞击声。
- 蜡烛攻击 active：低语循环。
- 蜡烛亮灭：点火 / 熄灭声。
- 房间切换：脚步声。
- SAN < 20：低 SAN 警告。

额外绑定：

```gdscript
audio_feedback.bind_hold_interaction(hold_anchor)
audio_feedback.bind_ui_hover_root(ui_root)
```

## 7. M0 验收清单

### A 侧确认

- `GameProcessManager` 已是 autoload。
- `RoomStateManager` 已是 autoload。
- `EventManager` 已是 autoload。
- 上文列出的信号可稳定发出。
- `BehaviorMessage` 类型字段保持：
  - `fix_window`
  - `expel_black_hand`
  - `light_candle`

### B 侧确认

- M1-M6 mock 已按当前接口跑通。
- 正式接入时，房间 ID 使用 `bow_room`。
- 如短期需要兼容旧场景，可手动把 `RoomSwitcher.bow_room_id` 和 `Minimap.bow_room_id` 设为 `room_bow`。

### C 侧确认

- 三个房间相机节点可提供给 `RoomSwitcher`。
- 锚、窗户、蜡烛、黑手节点可提供给交互脚本。
- UI 根节点 `CanvasLayer/UI` 可放置 B 的 HUD、读条、小地图、退出窗口、胜负界面。
- 如果 C 使用不同节点名，需要在主场景里通过导出 `NodePath` 绑定给 B，不需要改 B 的脚本。

## 8. 待三人最终拍板

- A/C 是否还有旧场景或旧脚本使用 `room_bow`。
- 船头房间是否会有窗户或蜡烛。
- 黑手模型是否每根蜡烛单独一个，还是全局一个复用节点。
- 正式主场景路径和 UI 根节点路径。
- Web 导出时是否保留所有音频，还是压缩 / 替换部分音频。
