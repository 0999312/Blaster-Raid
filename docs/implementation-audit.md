# 实现状态审计 — BLASTER RAID

> 生成时间：本轮检查（对照 `README.md`、`docs/design/fps-rogue-extraction-design.md`、
> `docs/backlog.md` 与全部代码）。目标：确定“哪些内容实际上还没有实现”。

## 1. 预置素材使用盘点（assets_temp → assets/kenney）

| 素材包 | 状态 | 说明 |
|---|---|---|
| kenney_blaster-kit_2.1 | ✅ 已接入（部分） | 玩家武器 blaster-a/c/j、敌人武器 blaster-a、配件/弹匣/子弹拾取物、箱体 crate-medium 已用；`grenade-*`、`target-*`、`smoke` 等未用 |
| kenney_mini-characters | ✅ 已接入（部分） | 三种敌人 male-a / female-a / male-c + 全套动画；轮椅、辅助道具（拐杖/眼镜/面具）未用；角色皮肤贴图未用 |
| kenney_food-kit | ✅ 文件已导入，⚠ 之前渲染不可见 | 全部 GLB 已复制到 `assets/kenney/food`；items.json 定义了 4 种（苹果/香蕉/面包/医疗饮料），掉落表已含食物；**旧拾取物仅 0.45 倍统一缩放且不居中 → 食物只有约 9cm，肉眼几乎看不见（本轮已修复）** |
| kenney_prototype-kit | ⚠ 仅极少量使用 | 仅 `coin.glb` 用作金币拾取物；**围墙/地板程序生成用的是 BoxMesh（`map_builder.gd`），门、楼梯、立柱、指示牌、号码牌、标签等模型全部未用** |
| kenney_impact-sounds | ✅ 已接入 | 敌人射击/受击、玩家脚步/受伤/枪声/命中音 |
| kenney_interface_sounds | ✅ 已接入 | UI 点击音（`game_ui.gd`） |
| 音乐（Funkorama / Faster Does It） | ✅ 已接入 | `assets/music/`，菜单/战斗切换 |

## 2. 已实现（代码实测 / 冒烟验证）

- **数据驱动**：weapons / attachments / items / enemies / loot_tables / upgrades JSON → `ContentManager` → Registry（12 物品、3 武器、3 敌人、4 掉落表、4 强化）
- **玩家**：WASD/摇杆移动、跳跃、蹲、冲刺、闪避、鼠标+摇杆视角（本轮拆分鼠标/摇杆输入）、脚步音、受伤音
- **武器**：中心射线射击、换弹、切枪（1/2）、近战 V、弹药、后坐力 + 视图模型摆动 + 枪口焰、配件数据生效（伤害/射速/弹匣/换弹/散布/射程）
- **敌人**：近战冲刺者、远程射手（投射物）、精英重装；视线检测（隔墙不索敌）、动画（idle/walk/sprint/attack/die）、死亡掉落、精英三选一局内强化
- **搜打撤闭环**：随机地图（房间+走廊）、物资箱（E 交互）、自动拾取、绿色撤离点站 4 秒、成功/失败结算、战利品价值兑换信用点、死亡保底研究数据
- **局外成长**：枪匠整备（武器选择/配件安装/永久强化购买）、`user://` 元进度存档
- **生存**：饥饿下降、空腹掉血、食物/医疗 F 键快速使用（本轮补 HUD 反馈）
- **输入**：GUIDE 键鼠 + 手柄双套（代码构建 Action，`guide_input_manager.gd`）
- **音频/UI**：音乐切换、主菜单/HUD/暂停/强化/结算/整备界面

## 3. 未实现清单（按设计文档逐项核对）

| # | 功能 | 证据/说明 | 优先 |
|---|---|---|---|
| 1 | **背包/快捷栏 UI** | README 标注“Tab 背包（预留）”；`inventory` action 已绑定但无消费者；`inventory_controller.gd` 无 UI | 高 |
| 2 | **瞄准 ADS（右键）** | `aim` action 已绑定（右键/LT）但 `weapon_controller.gd` 无任何 aim 分支；设计 4.1“可选聚焦” | 中 |
| 3 | **垂直瞄准吸附/辅助** | 设计 4.1 明确要求“准星附近锥形自动吸附”；未实现（纯手瞄） | 中 |
| 4 | **滑铲 Slide** | `crouch` 有 C 键；`slide` 无 action 无代码（Ctrl 未绑定） | 低 |
| 5 | **投掷物** | G/RB 未绑定；`grenade-a/b.glb` 未使用 | 低 |
| 6 | **门/门互动** | prototype 门模型全部未用；地图无门；交互只有开箱 | 中 |
| 7 | **房间模板 / 随机局内词条** | 设计 §6 room registry / run_modifier 均无；地图只有矩形房间+直线走廊；强化仅在精英死后三选一，非“清房给强化” | 高 |
| 8 | **Boss 敌人** | 设计 §3 提及；enemies.json 只有 3 种，无 boss 标签 | 中 |
| 9 | **击杀反馈 HUD** | 设计 4.2：Hitmarker / 伤害数字 / 敌人碎裂；现有：命中音 + 命中点闪光 + 掉落 | 中 |
| 10 | **状态效果 / 污染区 / 时间压力** | 设计 §5/Phase 5；`status_effect` 注册表不存在 | 低 |
| 11 | **重绑定/手柄图标提示 UI** | GUIDE 支持 is_remappable，但无重绑定界面；HUD 无双套按键图标 | 低 |
| 12 | **敌人血条 / 敌人模型着色区分** | 敌人按 model_path 区分（男女模型），`color` 字段定义后未用到模型材质上 | 低 |
| 13 | **道具特殊机制** | `ItemData.use_time`（快速食用）等字段存在但未使用 | 低 |
| 14 | **VFX 深化** | 弹孔为发光小球、无地面痕迹；无敌人碎块；无死亡音 | 低 |
| 15 | **性能优化** | 无 MultiMesh/LOD/合批；当前地图规模小，暂可接受；`--headless` 泄漏警告源于强制退出 | 低 |
| 16 | **I18N / 主题** | I18NManager 在 autoload 中但文本全部硬编码中文；`fps_rogue_ui.tres` 主题已启用 | 低 |
| 17 | **地图内容丰富度** | 无装饰、无房间类型（loot room / fight room / extraction room 标签没有任何消费）、无补给点 | 高 |
| 18 | **HUD 交互提示细化** | 本轮已补：附近有未开箱时显示“E 搜刮物资箱”；可进一步加拾取物名称悬浮 | 中 |

### 明确没接通但“看似有”的东西

- `scripts/hud.gd`（AimTrainerHUD）：**死代码**，旧训练场 UI，未被主场景引用。
- `resources/content/*.json` 中 `attachments` 在局内掉落（`raid:crate_basic` 等）✓ 但 **战斗内拾到配件后只在撤离时转入枪匠**，局内无法直接给当前武器安装（install_attachment 只能在整备界面调用）。
- `aim` / `inventory` / `slide` action 已建但无逻辑 —— 上文已列。
- 敌人 `color` 字段、`use_time`、`model_forward`（三个模型前向都是 +z，字段冗余）。

## 4. 本轮已修复的问题

1. **敌人“脑门上的枪”**：原实现把 blaster 固定在 `_model_root` 的 `(0, 1.08, 0.26)`——模型按 1.8m 归一化后（原高 0.776m，放大 2.32 倍），该高度正好是 chibi 大头模型的脸/额头区。现改为：从蒙皮顶点实时计算右手骨骼（`arm-right`，单臂骨骼 肩→手）的手部末端，武器每帧跟随手部骨骼姿态（`process_priority` 晚于 AnimationPlayer），枪口对齐手臂方向，射弹从真实枪口 Marker 发出（兜底：手前 0.8m 高度）。
2. **操作顿挫**：① 开启 `physics/common/physics_interpolation`（60Hz 物理 vs 高刷渲染阶梯）；② 视角输入拆为 `look_mouse` / `look_stick` 两个 action——原实现按 `|value| < 2` 阈值判断鼠标/摇杆，慢速鼠标移动（<2px/帧）被误判为摇杆，灵敏度瞬间放大 10 倍以上，形成明显的“跳格/顿挫”；③ 出生点补 `reset_physics_interpolation()`。
3. **食物看不见/不可判断**：拾取物改为按类别归一化世界尺寸（食物 0.30m / 医疗 0.34 / 弹药 0.36 / 配件 0.55）+ 模型居中 + 慢速自旋悬浮；HUD 新增左下“背包：苹果×2 …（F 使用食物/医疗）”摘要；拾取/使用均有底部中央 toast（“获得 苹果 ×1”“使用 面包：饱食 +35”）；无可食用物按 F 提示“没有可用的食物/医疗品”；靠近未开箱显示“按 E 搜刮物资箱”。

## 5. 建议的下一步（按性价比）

1. 背包 UI（最简单：复用 HUD 摘要弹出面板）—— 影响“无法判断是否可用”的主观体验
2. 房间模板 + 房间类型标签（loot/fight/extraction）—— 地图内容丰富度 + 素材利用
3. 击杀反馈（Hitmarker + 伤害数字）—— 爽快感提升，接近零风险
4. 瞄准吸附（准星 5° 内锥形吸附敌人胶囊）—— 手柄友好 + 古典 FPS 手感
5. 配件局内即时安装（捡到弹匣自动装/提示）
