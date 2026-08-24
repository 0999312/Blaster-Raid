# 项目待办 / 问题记录

> 用于记录还没完成、需要后续处理的事项。按“用户反馈”优先级排序。

## 0. 本轮已完成（backlog #5 修复轮：撤离点可见 / 装饰碰撞 / 兵种场景预览）

- **#5.2 撤离点不可见**：根因 = `raid_manager._spawn_proto` 把父节点局部坐标当世界坐标用（`global_position = pos`），素材全落在地图原点附近。修复 = 改为 `inst.position = pos`（局部空间）。验证：真实 raid 地图（seed 20260822，撤离点 (74,0,58)）上所有素材围绕撤离点（最大水平偏差 2.6m = 旗子位置）；渲染 + 像素断言确认绿光圆盘在画面中心可见。
- **#5.3 房间装饰碰撞箱过大**：根因 = 装饰碰撞统一按 `0.5×0.5×0.5 × scale` 放立方体，而 column 仅 0.2×1×0.2、ladder 约 0.15×1×0.55。修复 = `map_builder._collect_model_aabb_in(body, inst)` 在碰撞父节点空间按实例化后模型真实 AABB 生成 BoxShape3D（含缩放/旋转）。验证：5 个种子 14 个装饰全部 PASS（column 0.64×3.2×0.64、ladder 0.48×3.2×1.76、crate 0.75³，碰撞尺寸与模型 AABB 一致）。
- **#5.1 兵种场景 T-Pose 预览与运行不一致**：采用“方案 B+C 组合”：
  1. 三个兵种场景（enemy_runner/shooter/brute.tscn）已重生成：WeaponAnchor = rest 姿态右手握点（ModelRoot 局部、单位基），WeaponProp = 与 enemy.gd 动态挂枪路径完全相同的摆放（目标长度归一化 scale / weapon_yaw / AABB 居中）。编辑器静态预览现在就是“T-Pose 手握武器”的运行态 rest/idle 等效视图（射手枪 0.55m、枪口 Marker 修正到 (0,0,-0.4)，旧场景的 -0.8m 偏移与错误枪口位置已消除）。
  2. 新增数据驱动微调：`EnemyData.weapon_grip_offset: Vector3`（敌人前向基里的附加位移，自动跟随模式每帧生效；JSON 支持 `"weapon_grip_offset": [x,y,z]`）。
  3. 重生成工具：`dev_temp/probe_capture_anchor.gd`（headless 运行即可把三场景锚点/武器摆放重新对齐到当前模型，即“一键对齐到手部”）。
  - 验证：静态断言（锚点 vs rest 手部误差 ~1e-7、武器中心距手 <0.05m）与运行态断言（锚点每帧贴动画手部、prop 缩放 = 数据值）全部 PASS；`dev_temp/probe_enemy_scene.png` / `probe_runtime_scenes.png` 重新出图。
  - 已知边界（接受“以运行时为准”）：动画姿态（attack/holding-both 等）与 rest/idle 手部位置仍有差异，场景静态视图只保证 rest/idle 一致；改模型后请重跑捕获探针。
- 新增探针：`dev_temp/probe_raid_extract`、`probe_decor`、`probe_runtime_scenes`、`probe_static_assert`（+tscn）。
- 主场景 headless 冒烟（--quit-after 20）无脚本错误。

## 0-1. 上轮已完成（素材运用 + Enemy 场景化 + 换弹音效）

- **Enemy 场景化**：`scenes/enemy.tscn`（CharacterBody3D + 胶囊碰撞 + ModelRoot + WeaponAnchor 锚点 Marker3D）。
  - 武器锚点两种模式（enemy.gd `weapon_anchor_manual` 开关）：默认自动跟随右手骨骼（位置跟手、朝向水平朝前、按 `weapon_world_length` 归一化）；手动模式 = 锚点完全按场景人工设计（编辑器里摆位/旋转/缩放）。
  - 近战敌人武器：KayKit RPG Tools Bits（CC0，已复制到 `assets/kaykit/`）：冲刺者=axe（0.55m）、重装壮汉=hammer（0.62m）；射手=blaster-a（0.55m，yaw 180）。`weapon_model_path` 为空 = 空手。
- **门 / 墙壁**：`map_builder.gd` —— 与走廊相邻的墙格替换为 kenney `wall-doorway.glb`（门洞 2.4×2.4m，可通行碰撞：边柱+门楣）+ `door-sliding.glb` 半开门扇（带碰撞）；普通墙维持 BoxMesh。房间内随机 0~2 个原型装饰（column/crate/ladder，带碰撞），出生房不摆。
- **撤离点素材化**：`raid_manager.build_extraction_marker()` —— indicator-round-a 绿光大圆盘（4.4m）+ 悬浮旋转 indicator-special-arrow（绿光/上下浮动）+ 四角 column-low 界柱 + 双 flag 入口旗；修复了旧代码“发光材质未赋给 mesh”导致只有灰色圆盘的问题（现在真正发绿光）。
- **换弹音效**：`weapon_controller.gd` —— 换弹开始 `impactMetal_medium_000.ogg`、换弹完成 `impactMetal_heavy_001.ogg`。
- 验证：headless 冒烟通过；探针确认武器尺寸/朝向/手部跟随；渲染确认三兵种持械、撤离点绿光、门厅布局。

## 1. 预置素材未充分利用（进行中）

- 已接入：Kenney mini_characters / blaster / food / impact-sounds / interface_sounds / prototype（coin、wall-doorway、door-sliding、indicator-*、column、crate、ladder、flag）+ KayKit RPG Tools Bits（axe/hammer 等近战武器）。
- 仍未用：prototype 的 numbers/stairs/pipe、blaster 的 grenade/target/smoke、mini_characters 的轮椅/辅助道具、KayKit 的其他工具（蓝图纸/日志/火把等，可做地图装饰）。
- 详见 `docs/implementation-audit.md`。

## 2. 食物可见 / 可用（已修复，待用户验证）

- 根因：`Pickup.setup()` 在 `add_child` 之后调用，`_ready()` 里构建模型时 `item == null` → 所有拾取物都渲染兜底黄框。
- 修复：模型构建移到 setup()（item 就绪后），按类别归一化尺寸 + 居中 + 自旋；HUD 背包摘要 / toast / 开箱提示。

## 3. 敌人武器位置（已修复，待用户验证）

- 根因1：旧固定挂点 (0,1.08,0.26) 落在 chibi 脸部；根因2：骨骼跟随方向跟了手臂（斜上 37°）且 holder 正交基丢失缩放链（枪缩到 0.24m）。
- 修复：锚点方案 —— 位置跟右手、朝向水平朝前、prop 直接按目标长度缩放、枪口 Marker 修正；现在所有敌人（近战/远程）默认持械。

## 4. 玩家操作顿挫（已修复，待验证）

- 已开物理插值；视角拆为 look_mouse / look_stick；出生点 reset_physics_interpolation。

## 5. 移交新对话处理（用户反馈）——已修复，待用户验证

### 5.1 兵种场景 T-Pose 预览与实际运行不一致（已修复，见 §0）

- 原现象与根因：场景 WeaponAnchor 静态摆位与运行时自动跟随的基准不同（锚点每帧被覆盖、T-Pose 骨骼轴与持械姿态轴不同），射手场景枪被手工摆到左侧 -0.8m、枪口 Marker 位置写错（y=-0.4 应为 z=-0.4）。
- 修复：三场景重生成（锚点=rest 手部握点、武器=动态路径同款摆放）+ `weapon_grip_offset` 数据化微调 + `dev_temp/probe_capture_anchor.gd` 一键重对齐工具。详见 §0。
- 残留（接受以运行时为准）：attack 等动画姿态与 rest/idle 手部位置不同，静态预览不承诺模拟动画姿态。

### 5.2 撤离点彻底不可见（已修复，见 §0）

- 根因：`_spawn_proto` 中 `inst.global_position = pos` 把父空间局部坐标当世界坐标 → 素材落在地图原点附近。已改为 `inst.position = pos`。
- 验证：真实 raid 地图渲染 + 坐标/像素断言 PASS。

### 5.3 房间装饰立柱/梯子碰撞箱过大（已修复，见 §0）

- 根因：统一 `0.5×0.5×0.5 × scale` 立方体碰撞。已改为按模型真实 AABB（碰撞父节点空间，含缩放/旋转）生成。
- 验证：5 种子 × 14 装饰全部 PASS。

## 6. 其他未完成（docs/implementation-audit.md §3）

- 背包 UI、ADS、瞄准吸附、滑铲、投掷物、门开关交互、房间类型、Boss、击杀反馈 HUD、状态效果等。
