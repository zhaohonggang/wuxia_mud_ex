# LPC 样本迁移体验报告

> 本目录 `ex/` 收录把 `lpc_example/` 下 22 个 LPC `.c` 样本迁移到
> Kalevala/ExVenture 架构的**目标产物与结论**。迁移**未接入游戏、未测试**，
> 目的是一次性回答：**每个文件是“单文件直落”，还是必须动底层框架？**

## 核心结论（一句话版）

按“能否直接落单一文件”把 22 个样本分成三档：

| 档位 | 判定 | 样本 |
|---|---|---|
| A. 单文件直落（纯数据/纯服务） | 一个 `.ucl` 或一个纯函数 `.ex` | weapon_changjian, mount_ziliuma, item_shaolin_map, class_generate_chinese, room 静态结构, quest 数据 |
| B. 单文件 + 小幅本地逻辑（不动框架） | 一个 `.ex` + UCL 数据 | 两项技能的大部分 |
| C. 必须改底层框架（多文件/引擎扩展） | 不只是文件，要新增行为回调/引擎/状态 | taiji/dugu 少部分, combatd, damage, attack, poison, inherit(npc/room), system_npc(luban), class_npc(zhang/generate), 互动房间(liandu/qiyuan2), 互动物品(qianzhumiji/yinzhen) |

**比例：真正“单一文件就能完整、忠实地迁移”的只有少量文件；绝大多数 LPC
样本是把“玩法逻辑”写死在房间里/NPC里/技能里，而这在 Kalevala 里属于
框架层（Room.Processor / Combat.Engine / Skill behaviour / 状态机制），
需要先扩展框架，再以数据+少量模块接入。**

---

## 逐文件明细

### A. 单一文件即可（无需底层改动）

| 样本 | 落点 | 说明 |
|---|---|---|
| `weapon/weapon_changjian.c` | `lpc_samples.ucl` → `items.changjian` | 纯数据武器，直接映射 `Item.Meta.damage/skill_type`。 |
| `mount/mount_ziliuma.c` | `lpc_samples.ucl` → `characters.ziliuma` | 匹=野兽NPC+ridable 标记。坐骑消费端（负重/移速）需确认，见 B/C。 |
| `item/item_shaolin_map.c` | `lpc_samples.ucl` → `items.shaolin_map` | 纯数据物品（一整张 ASCII 地图写进 long，省略）。 |
| `class_npc/generate/chinese.c` | `ex/l.../name_generator.ex` | 中文姓名生成；纯函数服务，直接落地。 |
| 各房间的静态结构（qianting/liandu/qiyuan2） | `lpc_samples.ucl` → `rooms.*` | name/long/x/y/z 与静态 `room_exits` 是数据。 |
| `quest/quest_song-yupai.c` | `lpc_samples.ucl` → `items.yupai` + `characters.apo.turn_in` | Kalevala 已有 turn_in 机制，直接表达为“交付NPC+信物”。 |

### B. 一个模块 + UCL 数据（技能主体，不动框架）

| 样本 | 落点 | 说明 |
|---|---|---|
| `skill/skill_taiji-quan.c` | `taiji_quan.ex` + 注册 | 招式表（30+1）是纯数据 → `@actions`；`pick_action/3` 复用框架现有实现。`valid_enable/valid_learn/practice_cost` 均对得上。 |
| `skill/skill_dugu-jiujian.c` | `dugu_jiujian.ex` + 注册 | 招式表×2 + 基础数据；`pick_action` 对得上。 |

**但注意：B 档“主体”能落，**有相当一部分原回调却不在现有 `Kantele.Combat.Skill`
行为里，触发下方 C 档：

- taiji-quan：`valid_combine/1`、`valid_damage/4`、`query_effect_parry/2`、`hit_ob/3`
- dugu-jiujian：`valid_damage/4`、`hit_ob/3`、`skill_improved/1`、`difficult_level/0`，
  以及“按玩家『无招』标记选 action/action2 双表”的 `query_action/2+` 语义

### C. 必须改底层框架（这才是大头）

| 样本 | 需要的底层改动 |
|---|---|
| `daemon/combatd.c`（79KB） | 不是独立文件；它就是战斗引擎。并入/替换 `Kantele.Combat.Engine`（命中、damage 随机、护甲、招架/闪避、晕眩、死亡掉落）。 |
| `feature/feature_damage.c` | 双血条 `eff_qi/eff_jing`（现有 Vitals 只有 qi/max_qi）；receive_damage/receive_wound 落点。 |
| `feature/feature_attack.c` | `is_killing` 击杀仇恨、`kill_ob` 点名追杀、`start_busy` 硬直轮语义。 |
| `condition/poison.c` | 周期 tick 的状态（现有 Buff 只单次到期），需“Condition 每 tick 副作用+到期解除”。 |
| `inherit/char/npc.c` | 通用 NPC 基类：`chat_chance`、`add_action`、`set_heart_beat`、`is_killing`、`unconcious` → 并入 UCL 加载层/NPC 进程，一次开发全部生效。 |
| `inherit/room/pigroom.c` | 房间 `reset`、`heart_beat`、`add_action`、动态 exit 状态机 → 并入 `Kantele.World.Room`/`Room.Processor`。 |
| `system_npc/luban.c` | 新增 **Crafting 服务**（蓝图查表+等级校验+材料扣减+产出进包），UCL 摆 NPC。 |
| `class_npc/wudang/zhang.c` | 带逻辑的问询（ask_* 前置条件）、收徒判定、`accept_object`、战斗动作表演 → UCL 的 `inquiries` 只支持静态字符串映射，需支持“逻辑问询/NPC钩子”。 |
| `room/wudu_liandu.c`、`room/qiyuan2.c`、`room/qianting.c`（行为半） | `room_verbs` 自定义动词 + `room_heart_beat` + 动态 exit（大门开合）。 |
| `item/wudu_qianzhumiji.c`、`item/yinzhen.c`（行为半） | 带状态的“研读多绝招、针灸”动词；`InteractiveItem` 需支持持久化进度。 |

---

## 迁移过程的工程经验

### 1. “数据 vs 行为”是首要切分
LPC 房间/NPC/物品文件几乎都同时含 `create()`（数据）与
`init()/add_action/input_to/句柄函数`（行为）。Kalevala 的对应界是
**UCL 数据文件 ↔ Elixir 事件处理器/行为**。迁移第一步永远是把它劈开：
数据进 `.ucl`，行为进 `.ex`。

### 2. 技能最接近“可直接映射”
因为本 MUD 已经为技能做了 LPC `skill.c` 的忠实契约
（`@actions` 八字段、`pick_action`/`NewRandom` 加权随机、`valid_enable`/
`valid_learn`/`practice_cost`），taiji-quan / dugu-jiujian 的招式表基本
能整表拷入。**但 LPC 技能的横向钩子（valid_damage / hit_ob /
query_effect_parry / valid_combine / skill_improved）行为里一个都没有**，
要忠实就得扩行为+战斗引擎 → C 档。

### 3. LPC 的“继承与模板化”正是 Kantele 应有的“框架层”
- `inherit/npc.c`/`room/pigroom.c` 是**给所有 NPC/房间用的基类**，
  对应的不是“某个数据文件”，而是 `Kantele.World.*` 的内置回调。
  把它们当成“文件迁移”是反模式：应把它们**一次性地变成框架能力**，
  数据文件只管声明。
- `daemon/combatd.c` / `feature/damage.c` / `feature/attack.c` 同理，
  就是引擎/模块层，不是数据。

### 4. 行为型内容对底层的具体诉求（汇总待办）
按迁移动到下一步真正实现时所需的框架新能力排序：

1. **Skill 行为 + 战斗引擎扩展**：`valid_combine`、`valid_damage`（受击前减伤/反击）、`hit_ob`（命中后连击）、`query_effect_parry`（招架按技能加成）、`skill_improved`。
2. **Vitals 双血条**：`eff_qi / eff_jing`，支持 receive_wound 与治疗（yinzhen 针灸、poison、damage 全依赖它）。
3. **状态 Condition 机制**：可周期 tick、到期解除、可被清除（poison）。
4. **房间/NPC 交互钩子**：`add_action` 自定义动词、`heart_beat`、`reset`、动态 exit、`accept_object`、带逻辑的 ask（替代静态 inquiries）。
5. **击杀/仇恨与硬直**：`is_killing`、`kill_ob`、`start_busy`。
6. **服务层**：Crafting（鲁班）。

> 排序理由：技能是战斗核心（先玩）；双血条是一切伤害/治疗/状态的地基；
> 状态机制紧咬其后；交互钩子与服务层属于“丰富度”阶段。

### 5. 工具链注意（工程层面）
- 本机是 Windows/PowerShell，无 elixir；真要编译/测试需进
  `wuxia_mud_dev-app-1` Docker。本次因“不接入、不测试”，未编译 ——
  `ex/` 中的 `.ex` 是**目标形态示例，非已编译可用代码**。
- 若进入实现，新增技能需：放进 `lib/kantele/combat/skills/`、在
  `Kantele.Combat.Skills.@skills` 注册（`ex/lib/kantele/combat/skills/registry.ex`
  给了接入路径）。

---

## 目录对照

```
ex/
  data/world/lpc_samples.ucl        # A、B 档的数据：房间/NPC/物品/坐骑/任务
  lib/kantele/
    combat/
      skills/
        taiji_quan.ex               # B（招式表数据+部分逻辑）
        dugu_jiujian.ex             # B（招式表×2+部分逻辑）
        registry.ex                 # 接入主注册表的路径说明
      combat_daemon.ex              # C：combatd -> 引擎（规则并入）
      damage_attack.ex              # C：feature damage/attack -> 引擎/模块
    character/conditions/poison.ex  # C：Condition 机制目标
    world/
      bases.ex                      # C：inherit npc / room 基础行为诉求
      name_generator.ex             # A：中文姓名生成（纯函数）
      npc/
        class_wudang_zhang.ex       # C：带逻辑问询/收徒行为
        luban.ex                    # C：Crafting 服务目标
      item/interactive_items.ex     # C：qianzhumiji/yinzhen 互动物品
      room/interfaces.ex            # C：qianting/liandu/qiyuan2 行为目标
```
