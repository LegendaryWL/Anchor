# 程序 B 开发计划：交互 / 房间切换 / UI

> 负责人：程序 B  
> 项目目录：`/Users/ryuuna/Documents/GitHub/project-for-future/Anchor`  
> 素材目录：`/Users/ryuuna/Documents/GitHub/project-for-future/ai-help/anchor/resources`  
> 参考文档：`docs/UPDATED_DESIGN.md`、`docs/FEATURE_LIST.md`、`docs/GAME_DESIGN_DRAFT_V1.md`、`docs/PROGRAM_B_INTERFACE_CONTRACT.md`

## 1. 职责边界

程序 B 负责“玩家怎么操作、玩家看到什么反馈”，不接管怪物 AI、数值判定和场景导入。

### 必做

- 房间切换：小地图 / 房间按钮切换视角。
- 物品交互：长按修锚、长按修窗、长按点蜡烛、连点驱赶黑手。
- UI：SAN 条、锚修理进度、窗户耐久、读条、小地图 / 房间按钮、退出窗口、胜负界面。
- 音效提示：破窗声、低语声、蜡烛熄灭 / 点亮声等。
- 对接 A 的全局状态和事件接口，对接 C 的场景节点与相机节点。

### 不做

- 不写怪物随机攻击逻辑。
- 不直接判定胜利 / 失败。
- 不直接导入模型、材质和 Web 导出。
- 不在 UI/交互脚本里复制一份 SAN、窗户、蜡烛的权威状态。

## 2. 当前可用接口

当前工程已有这些全局节点和事件骨架：

- `GameProcessManager`
  - `add_repair_time(delta: float)`
  - `get_snapshot() -> Dictionary`
  - signals:
	- `san_changed(current, max_san)`
	- `repair_progress_changed(accum, target)`
	- `phase_changed(old_phase, new_phase)`
	- `game_over(reason)`
- `RoomStateManager`
  - `set_current_room(room_id: String)`
  - `modify_window_durability(window_id: String, delta: float)`
  - `set_candle_lit(candle_id: String, lit: bool)`
  - `get_window_state(window_id: String)`
  - `get_candle_state(candle_id: String)`
  - `can_fix_window(window_id: String)`
  - signals:
	- `room_changed(room_id)`
	- `window_durability_changed(window_id, durability)`
	- `candle_lit_changed(candle_id, lit)`
- `EventManager`
  - `on_behavior_message(msg: BehaviorMessage)`
  - `get_window_attack_state()`
  - `get_candle_extinguish_state()`
- `BehaviorMessage.create(type, target_id, resolved, payload)`

程序 B 的交互完成后，主要通过以下消息通知事件层：

```gdscript
EventManager.on_behavior_message(BehaviorMessage.create("fix_window", window_id, true))
EventManager.on_behavior_message(BehaviorMessage.create("expel_black_hand", candle_id, true))
EventManager.on_behavior_message(BehaviorMessage.create("light_candle", candle_id, true))
```

## 3. 推荐目录和文件

建议新增以下目录：

```text
interaction/
ui/
audio/
```

建议文件：

```text
interaction/hold_interaction.gd
interaction/click_spam_interaction.gd
interaction/interaction_target.gd
interaction/room_switcher.gd
interaction/camera_look_limiter.gd

ui/hud.gd
ui/progress_prompt.gd
ui/minimap.gd
ui/exit_dialog.gd
ui/game_result_screen.gd

audio/audio_feedback.gd
```

第一版可以先把脚本挂在 C 提供的主场景节点下，不急着做完整组件框架。

## 当前实现进度

- M0 已补充：`docs/PROGRAM_B_INTERFACE_CONTRACT.md`，记录 B/A/C 对接 ID、节点、信号和主场景绑定约定。
- M1 已完成：`mock/m1_room_switch_demo.tscn`，房间按钮切换相机与当前房间状态。
- M2 已完成：`mock/m2_hold_interaction_demo.tscn`，长按修锚、修窗、点蜡烛与读条提示。
- M3 已完成：`mock/m3_black_hand_interaction_demo.tscn`，触发黑手、连点 5 次驱赶、超时熄灭后长按重燃。
- M4 已完成：`mock/m4_hud_demo.tscn`，HUD 自动绑定 SAN、锚进度、阶段、房间、窗户、蜡烛和游戏结束状态。
- M5 已完成：`mock/m5_flow_demo.tscn`，退出确认、胜利/失败界面、返回主界面流程。
- M6 已完成：`mock/m6_audio_feedback_demo.tscn`，事件、UI、房间切换、修锚、蜡烛和低 SAN 音效反馈。
- B 侧独立补充已完成：`interaction/interaction_target.gd`、低 SAN 红屏、默认船头 ID 统一为 `bow_room`。

## 4. 和 A/C 的对接约定

### 4.1 ID 命名

优先使用当前代码已有 ID：

```text
room_a
room_b
bow_room（旧 mock 兼容名：room_bow）

window_room_a_0
window_room_a_1
window_room_b_0
window_room_b_1

candle_room_a_0
candle_room_a_1
candle_room_b_0
candle_room_b_1

anchor_device
```

注意：正式对接文档 `docs/PROGRAM_B_INTERFACE_CONTRACT.md` 建议最终统一使用 `bow_room`，`room_bow` 仅作为旧 mock 兼容名。

### 4.2 C 需要提供给 B 的节点

C 的场景中建议给关键节点加 group 或导出变量，方便 B 找到：

```text
camera_room_a
camera_room_b
camera_bow

interactable_anchor_device
interactable_window_room_a_0
interactable_window_room_a_1
interactable_window_room_b_0
interactable_window_room_b_1
interactable_candle_room_a_0
interactable_candle_room_a_1
interactable_candle_room_b_0
interactable_candle_room_b_1
interactable_black_hand

red_light_window_room_a_0
red_light_window_room_a_1
red_light_window_room_b_0
red_light_window_room_b_1
```

### 4.3 B 对 A 的最小依赖

B 只需要 A 保证：

- `GameProcessManager.add_repair_time(delta)` 可连续调用。
- `RoomStateManager.modify_window_durability(window_id, delta)` 可连续调用。
- `RoomStateManager.set_candle_lit(candle_id, true)` 可用于点亮蜡烛。
- `EventManager.on_behavior_message(...)` 能结束对应事件。
- 状态变化信号稳定发出，UI 不需要每帧轮询。

## 5. 开发顺序

### M0：对齐场景和接口（30 分钟）

目标：B 可以在不等最终美术的情况下开工。

- 确认房间 ID：`room_a`、`room_b`、船头房间 ID。
- 确认四扇窗和四根蜡烛 ID。
- 确认 C 的相机节点和可交互节点路径。
- 确认主场景里 UI 根节点位置。
- 在文档或代码注释中记录最终 ID 表。

交付物：

- B 能在主场景里拿到当前房间、窗户、蜡烛、锚装置节点。

### M1：房间切换和基础视角（45 分钟）

目标：玩家可以通过小地图 / 按钮切换房间。

- 实现 `ui/minimap.gd`：
  - 房间 A 按钮。
  - 房间 B 按钮。
  - 船头房间按钮。
- 实现 `interaction/room_switcher.gd`：
  - 点击按钮后调用 `RoomStateManager.set_current_room(room_id)`。
  - 监听 `RoomStateManager.room_changed`。
  - 通知 C 的相机控制节点切换目标相机。
- 可选：实现 `interaction/camera_look_limiter.gd`：
  - 固定机位下允许鼠标轻微转动。
  - 建议先限制 yaw/pitch，小范围即可。

验收：

- 点击 UI 按钮后，当前房间 ID 更新。
- 相机切到对应房间。
- 切房时不影响 SAN、锚进度、窗户耐久。

### M2：通用读条交互（60 分钟）

目标：复用一套长按逻辑，先跑通修锚和修窗。

- 实现 `interaction/hold_interaction.gd`：
  - 鼠标左键按住开始。
  - 松开取消或暂停。
  - 每帧输出 `progress_changed(value)`。
  - 完成时输出 `completed`。
- 实现 `ui/progress_prompt.gd`：
  - 显示当前交互读条。
  - 支持锚、窗、蜡烛三类提示文本。

修锚：

- 长按锚装置时，每帧调用：

```gdscript
GameProcessManager.add_repair_time(delta)
```

修窗：

- 长按窗户时，每帧调用：

```gdscript
RoomStateManager.modify_window_durability(window_id, 4.0 * delta)
```

- 读条完成或修到合理阈值后发送：

```gdscript
EventManager.on_behavior_message(BehaviorMessage.create("fix_window", window_id, true))
```

验收：

- 长按锚装置会推进锚修复进度。
- 长按窗户会恢复窗户耐久。
- 修窗可结束当前窗户攻击事件。
- 松开鼠标时读条表现明确，不产生误完成。

### M3：蜡烛和黑手交互（45 分钟）

目标：Phase 2 的核心操作可玩。

点蜡烛：

- 长按蜡烛 1s。
- 完成时：

```gdscript
RoomStateManager.set_candle_lit(candle_id, true)
EventManager.on_behavior_message(BehaviorMessage.create("light_candle", candle_id, true))
```

驱赶黑手：

- 实现 `interaction/click_spam_interaction.gd`。
- 连点黑手 5 次后完成。
- 完成时：

```gdscript
EventManager.on_behavior_message(BehaviorMessage.create("expel_black_hand", candle_id, true))
```

验收：

- 熄灭蜡烛可以被重燃。
- 黑手事件 active 时，连点 5 次可驱赶。
- 黑手被驱赶后蜡烛保持亮，不触发熄灭失败。

### M4：HUD 和状态绑定（60 分钟）

目标：玩家能看懂当前状态。

实现 `ui/hud.gd`，监听全局信号：

- `GameProcessManager.san_changed`
- `GameProcessManager.repair_progress_changed`
- `GameProcessManager.phase_changed`
- `RoomStateManager.window_durability_changed`
- `RoomStateManager.candle_lit_changed`
- `RoomStateManager.room_changed`
- `GameProcessManager.game_over`

UI 内容：

- 左上角 SAN 条 / 数值。
- 屏幕下方锚修理进度。
- 交互时显示读条。
- 当前房间窗户耐久。
- 小地图 / 房间按钮。
- 右上角退出按钮。

验收：

- SAN 变化时 UI 自动刷新。
- 锚进度变化时 UI 自动刷新。
- 当前房间切换后，窗户耐久显示切到对应房间。
- 游戏结束时 HUD 不继续接收交互输入。

### M5：退出窗口和胜负界面（45 分钟）

退出窗口：

- 右上角常驻入口。
- 点击后弹出确认：
  - 文案：“是否退出游戏？”
  - 按钮：“确认”
- 确认后返回主界面或重置当前场景，具体由主场景流程决定。

胜负界面：

- 监听 `GameProcessManager.game_over(reason)`。
- 胜利：
  - 标题：“平安启航”
  - 描述：“锚一归位，我就恢复了平静。我筋疲力尽，扑倒在小床上。想必我睡着了，因为醒来时满脸映着星光。”
- 失败：
  - 标题：“坠海”
  - 描述：“海水涌入我的咽喉，这座现实的地狱，终归不是人的王国。”
- 按钮：“返回主界面”

验收：

- 修锚完成后出现胜利界面。
- SAN 归零后出现失败界面。
- 返回主界面按钮可用。

### M6：音效反馈（45 分钟）

素材路径：

```text
/Users/ryuuna/Documents/GitHub/project-for-future/ai-help/anchor/resources
```

可先接入这些已有音频：

| 用途 | 素材 |
|---|---|
| 破窗 / 撞击提示 | `knocking_a_wooden_door2.mp3` 或 `knocking_an_iron_door1.mp3` |
| 低语循环 | `freesound_community-whispers-loop-41891.mp3` |
| 点亮蜡烛 | `freesound_community-match-lighting-candle-81020.mp3` |
| 熄灭蜡烛 | `candle_snuff.mp3` |
| 脚步 / 切房反馈 | `walking_on_floor1.mp3` |
| 鼠标进入 / UI 反馈 | `mouse_in.mp3` |
| 鼠标点击 / 确认反馈 | `click.mp3` |
| 锚机 / 回收装置运转 | `freesound_community-electric-hoist-75932.mp3` |
| SAN 过低警告 | `sanity2low.mp3` 或 `sanity2low_2.mp3` |
| 开场 / 主界面 | `opening.mp3` 或 `opening_A_Turn_for_the_Worse.mp3` |

实现 `audio/audio_feedback.gd`：

- 攻窗 active：播放撞击 / 对应窗户提示音。
- 蜡烛攻击 active：播放低语循环。
- 蜡烛重燃：播放点火音。
- 房间切换：可播放脚步声。
- SAN < 20：播放低 SAN 危险提示音 `sanity2low.mp3`。

验收：

- 攻击开始有声音提示。
- 事件结束后循环音效停止。
- 音效不重复叠太多层。
- Web 预览中声音可播放。

## 6. 输入规则

第一版建议输入规则简单明确：

- 鼠标左键：
  - 点击物体进入特写 / 选中物体。
  - 长按执行当前物体交互。
  - 连点黑手计数。
- 鼠标右键：
  - 退出物体特写。
- 小地图按钮：
  - 切换房间。

如果时间紧，特写可以先弱化为“选中物体 + 显示读条”，不一定要做相机推近。

## 7. 优先级

### P0：必须完成

- 小地图切房。
- 修锚长按。
- 修窗长按。
- 点蜡烛长按。
- 驱赶黑手连点。
- SAN / 锚进度 / 读条 UI。
- 胜负界面。

### P1：强烈建议

- 当前房间窗户耐久显示。
- 攻窗和蜡烛攻击音效。
- 低 SAN 屏幕变红。
- 退出确认窗口。

### P2：时间允许再做

- 相机小角度旋转。
- 交互特写镜头。
- 更细致的小地图状态标记。
- UI 动效和音效混音。

## 8. 风险和备选方案

| 风险 | 影响 | 备选方案 |
|---|---|---|
| A 的事件随机触发还没完成 | B 无法等真实攻击调交互 | 用 `EventManager.trigger_window_attack(...)` 和 `EventManager.trigger_candle_extinguish(...)` 做调试按钮 |
| C 的正式场景还没稳定 | 节点路径会变 | B 先在 mock 场景或临时主场景里按 ID 写脚本，最终只替换节点引用 |
| 船头房间 ID 不一致 | 修锚按钮/相机切换出错 | 正式统一 `bow_room`，旧 `room_bow` 只做兼容 |
| Web 音频播放受限制 | 首次进入无声 | 主界面“开始游戏”点击后再启动音频系统 |
| 时间不够做特写 | 交互反馈弱 | 先做 hover/选中高亮 + 屏幕读条，特写放 P2 |

## 9. 程序 B 最终验收清单

- 从主界面点击“开始游戏”进入游戏。
- 可以在房间 A、房间 B、船头房间之间切换。
- 长按锚装置会推进锚修理进度。
- 锚修满后出现胜利界面。
- 窗户被攻击时，玩家可长按修窗并恢复耐久。
- 修窗完成可以结束攻窗事件。
- 黑手出现时，玩家连点 5 次可以驱赶。
- 蜡烛熄灭后，玩家可长按点亮。
- SAN 条、锚进度、读条、小地图、退出按钮可见。
- SAN 归零后出现失败界面。
- 攻窗、低语、点火、切房等关键音效至少接入占位版本。
