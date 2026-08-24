# BLASTER RAID — 古典 FPS × 搜打撤 × Roguelite（Godot 4.7）

一个基于 Kenney 低模素材、Minecraft Style Framework 数据驱动、G.U.I.D.E 输入系统的 3D FPS 游戏原型。

> **⚠️ 项目状态**：实际完成效果**欠佳** —— 仅完成了基本配置与基础玩法骨架，内容不够有趣，**未能通过项目实战考核**。本仓库作为学习与复盘记录保留。

核心玩法（设计目标）：随机地图 → 搜刮物资/食物 → 清剿敌人 → 选择撤离 → 兑换永久强化；死亡只保留少量研究数据。

## 运行

```powershell
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --path .
```

或在 Godot 编辑器中打开 `project.godot`，运行主场景 `res://scenes/main.tscn`。

## 操作

| 键鼠 | 手柄 | 功能 |
|------|------|------|
| WASD | 左摇杆 | 移动 |
| 鼠标 | 右摇杆 | 视角 |
| 左键 | RT | 射击 |
| Shift | L3 | 冲刺 |
| 空格 | A | 跳跃 |
| C | B | 下蹲 |
| Alt | 右摇杆按下 | 闪避 |
| R | X | 换弹 |
| E | Y | 交互 / 搜刮 |
| F | LB | 使用食物/医疗 |
| 1 / 2 | D-pad | 切枪 |
| Tab | Back | 背包（预留） |
| Esc | Start | 暂停 |

## 玩法

- **古典 FPS**：中心射线射击、高速移动、低模网格房间，敌人近战冲锋或投射物攻击。
- **搜打撤**：打开物资箱、拾取补给与战利品，前往绿色撤离点坚持 4 秒即可撤离。
- **生存**：饥饿随时间下降，吃食物恢复；空腹会持续掉血。
- **Roguelite**：随机地图、随机掉落；击杀精英敌人后三选一局内强化。
- **局外成长**：撤离获得信用点与研究数据，可在“枪匠整备”购买永久强化。
- **改枪**：配件的数据驱动系统，通过配件槽修改伤害/射速/弹匣/换弹等。

## 实际完成情况

| 项目 | 状态 |
|------|------|
| 引擎 / 插件 / 数据驱动等基本配置 | ✅ 完成 |
| 基础 FPS 玩法骨架（移动 / 射击 / 敌人 / 搜刮 / 撤离） | 🟡 基本可用 |
| 内容量与趣味性 | ❌ 不足 |
| 项目实战考核 | ❌ **未通过**（完成效果欠佳，仅能完成基本配置但不够有趣） |

## 音乐

- 主菜单：Kevin MacLeod — Funkorama
- 战斗中：Kevin MacLeod — Faster Does It
- `assets/music/Funkorama.mp3` 与 `assets/music/Faster Does It.mp3` 已从 `assets_temp/` 复制到位。
- 也可放 OGG；未检测到时回退到程序生成的小型音轨。
- CC-BY 署名见 `assets/music/README.md`。

## 数据驱动

内容 JSON 位于 `resources/content/`：

- `weapons.json` / `attachments.json` / `items.json`
- `enemies.json` / `loot_tables.json` / `upgrades.json`

新增武器、物品、敌人、配件、掉落表只需添加 JSON 条目，代码通过 `ContentManager` 注册到 `RegistryManager`。

## 代码结构

```
scripts/game.gd                 # 主入口/全局状态/菜单/整备
scripts/core/                   # 数据资源、ContentManager、GUIDE 输入
scripts/player/                 # 玩家、武器、背包、生存
scripts/combat/                 # 敌人、敌人投射物
scripts/loot/                   # 拾取物、物资箱
scripts/raid/                   # RaidManager、随机地图
scripts/ui/                     # HUD/菜单/整备/强化/结算
scripts/meta/                   # 元进度存档
scripts/audio/                  # 音乐管理
resources/content/              # JSON 内容数据
assets/kenney/                  # 解压后的 Kenney GLB 素材
assets/music/                   # 音乐放置目录
```

## 冒烟测试

```powershell
$env:FPS_ROGUE_SMOKE='1'
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless --path . --quit-after 800
```

该模式会自动开始一局并触发拾取、升级等路径，用于验证运行时无错误。
