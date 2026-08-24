# 3D 古典 FPS × Roguelite × 搜打撤 策划与架构设计

> 项目：godot_dsh_test（Godot 4.7 / GDScript）
> 目标：一个可扩展的数据驱动 3D FPS 原型，融合《德军总部 3D》/《DOOM 2》的古典视角与节奏，以及现代撤离射击的“搜刮—战斗—撤离”循环，并加入 Roguelite 局外成长与轻度生存要素。

---

## 1. 一句话定位

**“体素/低模风格的快节奏撤离 FPS”**：每局随机生成一座可搜刮的设施，用 DOOM 式的中心精准射击清理敌人、搜刮食物与战利品，在风险与收益之间决定何时撤离；活着带出的物资用于基地强化，死亡则只带回少量研究数据。

---

## 2. 核心体验支柱

| 支柱 | 说明 |
|---|---|
| 古典 FPS 爽快感 | DOOM/Wolf3D 式高速移动、大量敌人、中心准星打击；动作轻快，击杀反馈强 |
| 搜打撤 risk/reward | 搜索资源 → 战斗压制 → 主动撤离；停留越久收益越高但风险越大 |
| Roguelite 循环 | 随机地图/敌人/战利品/局内强化；撤离换取永久成长 |
| 数据驱动扩展 | 武器、物品、敌人、掉落表、房间模板、强化、局内词条全部走 Registry + Codec/JSON |
| 生存调味 | 饥饿/食物已备好，作为行动节奏与资源取舍的软压力，不做硬核生存模拟 |

---

## 3. 核心循环

```
（基地/整备）
    │
    ▼
[进入撤离行动]
    │
    ├─ 随机地图/种子生成
    ├─ 搜刮：箱子、尸体、补给点、食物
    ├─ 战斗：清剿敌人、精英、Boss
    ├─ 局内强化：清空房间/精英战后三选一（Roguelite 成长）
    ├─ 生存：饥饿持续消耗，吃食物恢复
    │
    ▼
[选择撤离] ──失败/死亡──► 失去随身战利品，获得少量“研究数据”
    │
    ▼
[成功撤离] ──► 战利品兑换信用点 + 解锁/升级基地天赋
    │
    └──► 回到基地整备，开始下一局
```

- 单局目标时长：**10–20 分钟**
- 撤离点可能固定开启，也可在“清理关键房间后解锁”
- 局内 Roguelite 强化：每个大型房间/精英战后弹出 3 张强化卡
- 生存压力：饥饿随时间下降，空腹影响生命回复，最终掉血；食物是搜刮优先级之一

---

## 4. 古典 FPS 设计取舍

### 4.1 视角与操作

| 项 | 设计 |
|---|---|
| 视角 | 第一人称，FOV 80–90；有水平自由视角，垂直视角做了限制（约 ±35°） |
| 瞄准 | 默认屏幕中心射线（DOOM 式），不做强制开镜；可保留可选的“聚焦/ADS”作为低倍率稳定 |
| 垂直辅助 | 对敌人做“锥形自动吸附”：射线中心未命中时，在准星附近小范围内自动吸附到敌人躯干，以保留古典 FPS 的轻操作手感，同时方便手柄 |
| 移动 | 高速移动 + 加速度，走 6 m/s、跑 9 m/s；加入冲刺/滑铲/下蹲等现代战术动作 |
| 地图 | 网格化房间+走廊，使用 Kenney Prototype Kit 的墙、地板、立柱、箱子、门、指示牌 |

### 4.2 战斗节奏

- 玩家武器以 **hitscan（即时命中）** 为主：快、直接、爽快。
- 敌人以 **投射物（泡沫子弹/低模弹体）** 为主：可读、可闪避，符合古典 FPS 的“走位躲弹”。
- 敌人数量偏多、单体血少，强调走位、扫射、清群。
- 击杀反馈：命中音、Hitmarker、伤害数字、敌人模型破碎/消失、弹药与掉落。
- 技能/道具不做复杂冷却，只用“冲刺/滑铲/投掷/近战”等短平快动作。

### 4.3 现代战术动作清单

| 动作 | 说明 | 键鼠 | 手柄 |
|---|---|---|---|
| 冲刺 Sprint | 提升移速，耐力不做硬限制 | Shift | L3 |
| 滑铲 Slide | 冲刺中下蹲，低姿态快速通过/躲弹 | Ctrl | B |
| 闪避 Dash | 短距离快速位移（可选，配合滑铲二选一） | 双击方向/Alt | 右摇杆按下 |
| 下蹲 Crouch | 降低轮廓、提升精准 | C | B |
| 跳跃 Jump | 基础垂直机动 | Space | A |
| 换弹 Reload | 可取消/切枪打断 | R | X |
| 快速切枪 | 主/副/近战 | 1/2/3、滚轮 | D-pad 左右、Y |
| 近战 Melee | 近身快速击退 | V | 右摇杆按下 |
| 交互 Interact | 开箱、开门、拾取、启动撤离 | E | Y |
| 使用道具 | 快速吃食物/用药 | F | LB |
| 投掷 | 手雷/闪光（后期） | G | RB |

> 手柄 UI 与 G.U.I.D.E 的按键/图标显示由 GUIDE 插件提供，必要时代入 `input/actions/*.tres` + `input/contexts/*.tres`。

---

## 5. 生存要素（轻量）

| 系统 | 设计 |
|---|---|
| 生命 | 常规 HP，受击/跌落/饥饿影响 |
| 饥饿 | 持续缓慢下降；饥饿条低时生命恢复速度下降；极低时持续掉血 |
| 食物 | 使用 Kenney Food Kit 模型；吃食物恢复饱食度 + 少量生命，部分是“快速食用” |
| 补给 | 弹药、医疗食物、稀有食物/饮料（未来可扩展） |
| 节奏 | 饥饿不是倒计时，而是让“搜刮”有意义的压力源；掉血速度设计为可容忍，不打断爽快感 |

---

## 6. 数据驱动架构（基于 Minecraft Style Framework）

### 6.1 注册表（Registry）

使用 `RegistryManager` + `ResourceLocation`，建议命名空间 `raid`。

| 注册表 | 内容 |
|---|---|
| `weapon` | 武器定义：伤害、射速、弹匣、换弹、模型、音效 |
| `item` | 物品定义：弹药/食物/医疗/贵重品/武器/装备 |
| `enemy` | 敌人定义：属性、AI 类型、掉落表、模型 |
| `loot_table` | 掉落表：物品加权、数量范围、稀有度 |
| `room` | 房间模板：占地、预置物、刷怪点、刷物点 |
| `map_layout` | 整图模板/生成规则：房间图、连接、撤离点 |
| `run_modifier` | 局内词条：敌人血量倍率、掉落倍率、时间限制等 |
| `meta_upgrade` | 永久强化：血量、移速、幸运、初始武器等 |
| `status_effect` | 状态效果：中毒、增益、减速等（后期） |

### 6.2 数据资源

推荐用 `CodecResource` 子类 + JSON，既能编辑器 Inspector 编辑，也能 JSON 热扩展。

```gdscript
# 示例：WeaponData 的字段
class_name WeaponData
extends CodecResource

static func get_type_id() -> String:
    return "raid:weapon"

# id, display_name, model_path, damage, fire_rate, spread,
# magazine_size, reserve_ammo, reload_time, ammo_type,
# projectile_type (hitscan / projectile), auto, rarity, tags
```

- `resources/content/weapons/*.json`
- `resources/content/items/*.json`
- `resources/content/enemies/*.json`
- `resources/content/loot_tables/*.json`
- `resources/content/rooms/*.json`
- `resources/content/meta_upgrades/*.json`

`ContentPackLoader` 启动时扫描这些目录，用 `JsonOps` + `CodecResource.from_json_data()` 解码后 `RegistryManager.get_registry("weapon").register(loc, data)`。新增内容 = 丢一个 JSON。

### 6.3 组件系统（Component）

对运行时实体使用 `ComponentType` + `ComponentContainer`（`ComponentHost` 挂到 Node/Resource 上）：

| 组件 | 作用 |
|---|---|
| `health_component` | 当前/最大生命、伤害事件、死亡事件 |
| `hunger_component` | 饱食度、消耗速度、空腹惩罚 |
| `ammo_component` | 当前弹匣/备弹/弹种 |
| `inventory_component` | 背包/快捷栏 |
| `attributes_component` | 移速、冲刺速度、掉落幸运等派生属性 |
| `loot_component` | 指向 loot_table，死亡/开箱时掉落 |
| `faction_component` | 阵营与敌对关系 |
| `tag_component` | 通过 Tag 做类型/需求过滤 |

### 6.4 Tag 分类

- `item:food` / `item:ammo` / `item:valuable` / `item:weapon`
- `enemy:melee` / `enemy:ranged` / `enemy:elite` / `enemy:boss`
- `room:start` / `room:fight` / `room:loot` / `room:extraction`

### 6.5 EventBus 事件

| 事件 | 用途 |
|---|---|
| `raid:started` / `raid:extracted` / `raid:failed` | 局流程 |
| `player:damaged` / `player:healed` / `player:ate` | 生存 |
| `enemy:spawned` / `enemy:killed` | 战斗统计/任务 |
| `item:picked` / `container:opened` | 搜刮反馈 |
| `weapon:fired` / `weapon:reloaded` | HUD/音频 |
| `upgrade:chosen` | 局内强化 |

---

## 7. 场景树与模块职责

```
Main (Node3D)
├── RaidManager          # 局状态机：准备/进行中/撤离/失败/结算
├── MapBuilder           # 生成/加载房间、门、障碍、撤离点
├── Player               # CharacterBody3D
│   ├── CameraRig
│   │   ├── Camera3D
│   │   ├── GunModel
│   │   └── MuzzleFlash
│   ├── MovementController   # 移动/跳跃/冲刺/滑铲/下蹲
│   ├── WeaponController     # 射击、换弹、切枪、投掷
│   ├── InventoryController  # 背包/快捷栏
│   ├── SurvivalController   # 生命/饥饿/状态
│   ├── InteractionController# 开箱/拾取/交互
│   └── CollisionShape3D
├── EnemyManager         # 敌人波次/刷怪控制
├── LootManager          # 根据 loot_table 生成拾取物
├── ExtractionManager    # 撤离区/撤离流程
├── SurvivalDirector     # 全局饥饿/环境压力
├── HUD                  # CanvasLayer：准星、血量、饥饿、弹药、击杀反馈
├── MenuLayer            # CanvasLayer：暂停、整备、强化选择、结算
└── MetaManager          # 持久化：信用点、天赋、解锁、统计
```

关键规则：
- `RaidManager` 只负责局流程，不直接生成地图/掉落。
- `MapBuilder` 从 `map_layout` / `room` 注册表读取并实例化。
- `LootManager` 只认 `loot_table` 注册表，不感知具体物品。
- 所有横跨系统的沟通走 `EventBus`，减少节点间硬耦合。

---

## 8. 输入方案（GUIDE 插件）

### 8.1 ACTION 资源建议

创建 `input/actions/*.tres`（GUIDEAction），建议：

| Action | 类型 | 键鼠 | 手柄 | 说明 |
|---|---|---|---|---|
| `move` | AXIS_2D | WASD | 左摇杆 | 移动 |
| `look` | AXIS_2D | 鼠标 | 右摇杆 | 视角 |
| `jump` | BOOL | Space | A | 跳跃 |
| `sprint` | BOOL | Shift | L3 | 冲刺 |
| `crouch` | BOOL | C | B | 下蹲 |
| `slide` | BOOL | Ctrl | B（冲刺中） | 滑铲 |
| `dash` | BOOL | Alt/双击 | 右摇杆按下 | 闪避 |
| `fire` | BOOL | 左键 | RT | 射击 |
| `aim` | BOOL | 右键 | LT | 聚焦/开镜（可选） |
| `reload` | BOOL | R | X | 换弹 |
| `interact` | BOOL | E | Y | 交互 |
| `use_item` | BOOL | F | LB | 使用快捷道具 |
| `melee` | BOOL | V | 右摇杆按下 | 近战 |
| `next_weapon` | BOOL | 滚轮/1/2/3 | D-pad 左右 | 切枪 |
| `prev_weapon` | BOOL | 滚轮/1/2/3 | D-pad 左右 | 切枪 |
| `inventory` | BOOL | Tab | Back | 背包 |
| `pause` | BOOL | Esc | Start | 暂停 |
| `map` | BOOL | M | View | 地图（后期） |

### 8.2 映射上下文

- `input/contexts/gameplay_context.tres`：局内战斗激活
- `input/contexts/inventory_context.tres`：背包打开时
- `input/contexts/menu_context.tres`：暂停/整备/结算

手柄注意：
- 左摇杆用 `GUIDEInputJoyAxis2D` + 死区/曲线 modifier
- 右摇杆视角用 `GUIDEInputJoyAxis2D`，可加响应曲线 modifier
- 鼠标视角用 `GUIDEInputMouseAxis2D` / 相对窗口 modifier
- 所有玩家可重绑定 Action 设 `is_remappable = true`

---

## 9. Kenney 素材使用

| 素材包 | 用途 |
|---|---|
| `kenney_prototype-kit` | 房间地板、墙壁、门、立柱、箱子、梯子、指示牌、号码牌；搭建网格化地图 |
| `kenney_blaster-kit_2.1` | 玩家枪械（blaster-a~r）、子弹/弹壳、靶子、消音器、瞄准镜、手雷；武器模型与拾取物 |
| `kenney_mini-characters` | 低模敌人角色（male/female），通过材质/颜色区分兵种；也可做 NPC/商店 |
| `kenney_food-kit` | 食物/饮料拾取物，对应生存与饥饿系统 |

资源整理建议：

```
assets/
  kenney/
    prototype/
    blaster/
    mini_characters/
    food/
```

- 统一使用 **GLB** 格式导入（比 FBX 更适合 Godot）。
- 为每个模型建立统一缩放/朝向前置规范，保证地图格与碰撞体对齐。
- 可用 `assets/kenney/manifest.tres` 记录 `模型路径 ↔ 资源ID ↔ 缩放/碰撞` 的映射。

---

## 10. 开发路线图

### Phase 0：资源导入与基础环境

- [ ] 解压 4 个 Kenney zip 到 `assets/kenney/`
- [ ] Godot 导入 GLB，建立材质/缩放规范
- [ ] 搭建一个简单的展示房间（地板+墙+枪）
- [ ] 跑通现有 `scenes/main.tscn` 替换为新的 FPS 测试场景

### Phase 1：古典 FPS 垂直切片

- [ ] 用 GUIDE 重写玩家移动/视角（去除 `Input.is_key_pressed` 硬编码）
- [ ] 移动：走/跑/跳/蹲/滑铲/冲刺
- [ ] 中心射线射击 + 简单垂直自动吸附
- [ ] 一把武器（hitscan），换弹、切枪基础
- [ ] 一个静态敌人靶/移动靶
- [ ] HUD：准星、弹药、生命、击杀提示
- [ ] 基础音效（kenney_interface_sounds 暂替）

验收：键鼠可完整打一个靶场演示；手柄可移动+射击。

### Phase 2：数据驱动基建

- [ ] `WeaponData` / `ItemData` / `EnemyData` / `LootTableData` CodecResource
- [ ] `ContentPackLoader`：扫描 JSON 并注册进 Registry
- [ ] 把 Phase 1 的硬编码武器/敌人/掉落改为注册表读取
- [ ] GUT 测试：Codec 编解码、Registry 注册/读取、掉落表概率

### Phase 3：搜打撤闭环

- [ ] 拾取物/容器/交互系统
- [ ] 背包与快捷栏（UI 最小版）
- [ ] 掉落表生成战利品
- [ ] 撤离点 + 撤离倒计时/确认
- [ ] `RaidManager` 状态机：进入→进行中→撤离/失败
- [ ] 死亡/结算面板、携带物处理

验收：能“进图→搜刮→战斗→走到撤离点→结算”，键鼠/手柄都可完成。

### Phase 4：Roguelite 与随机化

- [ ] 随机地图生成（房间图/网格生成；先做“房间模板 + 随机连接”）
- [ ] 局内强化卡三选一（清房/精英战后）
- [ ] 随机局内词条：敌人强化、掉落强化、时间压力
- [ ] 基地整备界面：信用点、永久天赋、初始装备
- [ ] 元进度存档（ConfigFile/Resource 持久化）

### Phase 5：生存与内容扩展

- [ ] 饥饿系统 + 食物使用/拾取
- [ ] 更多敌人 AI：近战冲锋、远程射击、精英、Boss
- [ ] 更多武器：不同射速/弹道/投掷物
- [ ] 撤离压力：污染区/时间窗口/精英守卫
- [ ] 难度曲线与数值平衡

### Phase 6：打磨、音频、UI、测试

- [ ] G.U.I.D.E 重绑定界面 / 手柄图标提示
- [ ] `sound_manager` 接入正式音效
- [ ] VFX：枪口焰、弹孔、命中特效、敌人碎裂
- [ ] UI 主题统一、中文本地化（I18NManager）
- [ ] GUT 核心逻辑测试 + 评审
- [ ] 性能：MultiMesh/实例化、遮挡剔除、LOD

---

## 11. 推荐技术决策

| 决策 | 原因 |
|---|---|
| 使用 GDScript | 项目现有代码为 GDScript，迭代快 |
| 先 hitscan 后投射物 | 快节奏古典 FPS 射击反馈直接；敌人投射物用于可闪避 |
| 先用固定房间模板 + 随机连接，后做完整程序生成 | 降低地图生成风险，保证布局可读性 |
| 数据走 Registry/Codec，不走散落常量 | 扩展性是硬需求 |
| 输入完全走 GUIDE | 键鼠/手柄/重绑定一体，避免双写输入代码 |
| 饥饿作为软压力 | 避免喧宾夺主，保持“爽快”核心 |
| 撤离成功才保留高级收益，死亡保留少量研究数据 | 维持 Roguelite 成长感，同时保留撤离射击的得失感 |
| 单机为主 | 当前项目无网络需求；未来可多人再引入 Multiplayer |

---

## 12. 风险与应对

| 风险 | 应对 |
|---|---|
| Kenney GLB 模型比例/朝向不一 | 建立 `AssetManifest` 统一缩放与碰撞体；先做 1 个武器/1 个敌人验证规范 |
| 数据驱动前期成本高 | 先用硬编码完成 Phase 1，再逐项迁移到 Registry |
| 搜打撤+生存+局外成长功能膨胀 | 按路线图做垂直切片；每个 Phase 均可独立验收 |
| GUIDE 上手成本 | 用脚本批量生成 action/context；先只做 gameplay 一套上下文 |
| 大量低模实体性能 | 敌人/道具使用 MultiMeshInstance3D 或合批，地图静态物体合并 |
| 地图随机生成质量 | 先从手调模板 + 随机排序/旋转开始，再引入 BSP/图算法 |

---

## 13. 下一步

1. 按此时策划书写 `feature-brief-fps-rogue-extraction.md`（可省，直接进入 Phase 0）
2. Phase 0：解压/导入 Kenney 素材，建立模型规范
3. Phase 1：实现“古典 FPS 垂直切片”并用 GUIDE 重写输入
4. 按 `docs/dev-example/README.md` 的三步流程推进：策划→实现→评审
