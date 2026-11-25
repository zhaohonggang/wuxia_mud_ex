# 大宗师（ultra 门派）教学门控移植计划

> 状态：✅ 审计与实现完成（#1048 审计 · #1049 实现；未提交，待全量回归）
> 实现批次：#27（见 `docs/待全量回归清单.zh-CN.md`）；定向测试 12/0。
> 对应 Task：#1048（审计 + 计划）
> LPC 源：`kungfu/class/ultra/{dugu,huang,huoshan,kuihua}.c` + 共享 `ultra.h`
> ex 现状：4 位大宗师 **均无 NPC 块**（仅 `liuxi.ucl` 有其物品 `owner_id` 引用），全部缺失

---

## 0. 结论先行

`kungfu/class/ultra/` 下是 **4 位「大宗师」称号**的超级师父（F_MASTER + F_NOCLONE + `check_clone()` + startroom），由 `npcd.c` `query_ultra_master()` 解析、`story/challenge.c` + `ultra.h` 引用。它们**不以传统「收徒/授艺」教学为主**——`recognize_apprentice` 在源中**全部被注释**（源内禁用收徒）。

真正的教学主体是 **ultra.h 的「宗师评价」子系统** + 各自 **绝招 quest** + `accept_object` 收集：
- **宗师评价**：玩家 `ask 评价/opinion` → `ask_opinion` → `accept_fight` → 对掌 + `check_opinion` → 按 `opinions_rank`（520..200）评级 → 达成 unarmed/weapon/force/dodge 四宗师 → `check_ultra` → `opinion/ultra=1` 大宗师 + 四大师 `do_congration` + `CHANNEL_D` rumor 江湖传闻。
- **绝招 quest**：
  - 独孤求败 独孤九剑无招（`accept_object` dugubook 残本）。
  - 黄裳 摄心大法（`accept_object` zhenjing1/2 九阴真经上下册 + `ask_skill`），依赖 `can_learn`/`can_perform` flags。
- **收徒**：源内禁用（`recognize_apprentice` 全注释）→ ex 侧**不放 `apprentice` 收徒块**（或按 LPC 语义置为不收），重点是**评价/评价门控的引擎级子系统**——这在 ex 中**完全缺失**。

**这是一次「引擎级子系统缺口」审计，不只是单 NPC 数据回填**。除非用户明确指示实现评价子系统，否则本批只登记、不实现。

---

## 1. 四位大宗师逐条核对

| 项 | 独孤求败 | 黄裳 | 霍山 | 葵花太监 |
|---|---|---|---|---|
| 文件 | `dugu.c` | `huang.c` | `huoshan.c` | `kuihua.c` |
| title | HIC 大宗师 | HIY 大宗师 | HIW 大宗师 | HIR 大宗师 |
| startroom | `/d/huashan/shandong` | `/d/dali/lushui` | `/d/mingjiao/xuantianshi` | `/d/beijing/shanlu3` |
| 评价类别 | weapon（兵器） | unarmed（拳脚） | force（内家功夫） | dodge（轻功） |
| MY_OPINION | `weapon` | `unarmed` | `force` | `dodge` |
| OPINION_TYPE | 兵器武功 | 拳脚功夫 | 内家功夫 | 轻功 |
| combat_exp | 50000000 | 50000000 | 50000000 | 50000000 |
| class | （未标） | class | fighter | （未标） |
| 主绝招 quest | 独孤九剑无招（accept dugubook） | 摄心大法（accept zhenjing1/2 + ask_skill） | 无 | 无 |
| recognize_apprentice | 注释禁用 | 注释禁用 | 注释禁用 | 注释禁用 |
| ex NPC 块 | ❌ 无 | ❌ 无 | ❌ 无 | ❌ 无 |
| ex 物品 owner | ✅ liuxi.ucl（残本 owner="dugu qiubai"） | ✅ liuxi.ucl（owner="huang shang"） | ✅ liuxi.ucl（旱烟袋 owner="霍山"/owner_id="huo shan"） | ✅ liuxi.ucl（owner="kuihua taijian"） |

---

## 2. 宗师评价子系统（ultra.h + 各 .c）—— 引擎级缺口

### 2.1 评价门控主流程（`ask_opinion`，四大师大同小异）
`inquiry "评价"/"opinion"` 触发，依序判断：
1. `me->query("combat_exp") < 200000` → `say 哼！你这点武功也出来丢人现眼？`（拒绝）。
2. `me->query("opinion/<MY_OPINION>") == "宗师"` → `say 不必了，你<类别>方面的修为已经称得上是宗师了！`（已达顶级，拒绝重复）。
3. `is_fighting(me)` → `say 哈哈，废什么话，打赢了我，你自己给自己评价吧！`。
4. `me->is_fighting()` → `say 你等会儿吧！待我赶走他们。`。
5. `query_temp("opinion")` 已有人在评价 → 恼怒文案（`你着什么急？不要烦我。` / `没看我正忙着吗？`）。
6. 通过 → 按 `query_temp("want_opinion/shenni")` 0..3 分支说推进台词，并 `add_temp("want_opinion/shenni", 1)` → 引导玩家 `fight`。

### 2.2 `accept_fight`（对掌比内力）
- 已宗师 → 允许切磋（比划文案）。
- 无 `want_opinion` → `say 你干什么要和我动手？` 拒绝。
- 有 → `COMBAT_D->do_attack` 打一招：
  - 玩家 qi<=0 → `say 你现在的武功还差得远，连我一招都接不住！`（拒）。
  - 玩家 neili < 3000 → `say 适才你内力不足，我难以衡量，待你将内力修炼好了再来吧！`（拒）。
  - 通过 → 玩家 `set("neili", 0)`（内力清零），`call_out("check_opinion", 2, me)` + `set_temp("opinion", me)`（评价进行中）→ `say 好了，待我想想。`

### 2.3 `calc_level`（等级计算，各大师按类别）
```
lvl = query_skill(<MY_OPINION>, 1) / 2
sp  = query_skill_mapped(<MY_OPINION>)   // 无 mapped → 返回 lvl
lvl += query_skill(sp, 1)
if (max_neili > 4000) lvl += 20
```

### 2.4 `check_opinion`（评级，ultra.h 共享）
- `opinions_rank` map（排序键）：
  ```
  520:宗师  490:登峰造极  460:超凡脱俗  430:臻至化境  400:炉火纯青
  360:已有大成  320:非同凡响  280:出类拔萃  240:身手不凡  200:已有小成
  ```
- 按现有 `rank` 定位 `next_lvl`；对 `my_opinions` 逐项 `calc_level`，取最高 `opinion`。
- `opinion == -1`：
  - 若首次（next_lvl==ks[0]）→ `say 你的<类别>不行啊！好好努力吧！`。
  - 否则 → `say 不怎么样，我发现你的<类别>比上次没什么太大的进步。`。
- 有进步 → 依 `opinions_rank[ks[i]]` 评级写 `set("opinion/<MY_OPINION>", rank)`：
  - 到终极（i==sizeof(ks)-1）→ 恭贺宗师 + `set("opinions/master", 1)` + `check_ultra(me)`。
  - 未到终极 → `say 就目前来看，你的<类别>已经可以算得上是<rank>了。`

### 2.5 `check_ultra`（四宗师 → 大宗师）
- 需 `opinion/unarmed == weapon == force == dodge == 宗师`（四类全宗师）。
- 达成 → `set("opinion/ultra", 1)` + `NPC_D->query_ultra_master()` 除己 → `do_congration(me)`（`chat 不错，不错，真是不错。`）+ `CHANNEL_D->do_channel(MASTER_OB, "rumor", "听说<name>成为武学大宗师。")`。

### 2.6 战斗互斥（accept_kill / accept_hit / unconcious / die）
- 四大师不可被击杀（unconcious/die → 吐血闪逝 + `chat 本座去也！` + `destruct`）。
- 独孤求败 额外：`chat_chance_combat 120` + `check_weapon`（无武器则销毁）。
- 霍山 `accept_kill`：exp<500000 → `me->unconcious()`（反制）。

---

## 3. 各大师绝招 quest 缺口

### 3.1 独孤求败 —— 独孤九剑无招
- `accept_object` dugubook（独孤九剑残本）：满足条件 → 传独孤九剑无招。
- 依赖 `can_learn`/`can_perform` flags（承继 GAP #743 `perform_known?` 机制）。
- ex 侧：`liuxi.ucl` 已有残本物品，但**无 NPC 无 accept_object 规则**。

### 3.2 黄裳 —— 摄心大法
- `accept_object` zhenjing1/2（九阴真经上下册）+ `ask_skill` 摄心大法。
- 需 240 jiuyin-shengong + 240 martial-cognize + 4 其他绝招。
- 依赖 `can_learn`/`can_perform` flags。
- ex 侧：`liuxi.ucl` 有 zhenjing 物品 owner="huang shang"，但**无 NPC 无接受规则无绝招 quest**。

---

## 4. 引擎机制缺口清单

1. **`ask_opinion`/`accept_fight`/`calc_level`/`check_opinion`/`check_ultra` 评价子系统**：ex 无任何对应 inquiry handler 或事件模块。
   - 需新增引擎：玩家 `ask 评价` → 门控 → 对掌 → 评级（`opinions_rank` map）→ `opinion/<类别>` 持久化 → 四宗师 → `opinion/ultra=1` 大宗师 + 江湖传闻。
   - `query_ultra_master`（`npcd.c`）：ex 无「大宗师集合」注册机制。
   - `ultrap/1`（`opinion/ultra`）：ex `Kantele.Character.Reborn` 已有 `ultrap?/1`（`hell_zhen.ex` 引用）——可复用。
2. **大宗师 NPC 数据缺失**：4 位均无 `data/world/*.ucl` NPC 块（仅物品 owner 引用）。
3. **绝招 quest（accept_object dugubook / zhenjing1-2 + ask_skill）**：ex `accept_object` 通用机制已有（`give_event`），但**无这些大宗师专属规则**；`ask_skill` 绝招传授需承继 #743 机制。
4. **不可击杀（unconcious/die → destruct）**：ex 通用死亡逻辑需核实是否覆盖「大宗师闪逝」。

---

## 5. 建议实现方案（登记，不实现）

### 5.1 数据落地（先决：NPC 数据）
为 4 位大宗师在对应 zone 的 `data/world/*.ucl` 新增 `characters` 块（name/aliases/title 大宗师/long/gender/age/str/int/con/dex/combat/战力/skills 500 级/mapped/chat_chance_combat/startroom 对应房间/carry cloth）：
- 独孤求败 → `huashan.ucl`（startroom `/d/huashan/shandong`）
- 黄裳 → `dali.ucl`（startroom `/d/dali/lushui`）
- 霍山 → `mingjiao.ucl`（startroom `/d/mingjiao/xuantianshi`）
- 葵花太监 → `beijing.ucl`（startroom `/d/beijing/shanlu3`）
- 并核对 startroom 房间是否存在；`liuxi.ucl` 物品 owner 绑定保持。

### 5.2 引擎新增（评价子系统）
- 新增 `lib/kantele/npc/ultra.ex`（或 inquiry handler）：`ask_opinion` 门控 + `accept_fight` 对掌 + `calc_level` + `check_opinion` 评级 + `check_ultra` 四宗师检测 + `do_congration`/rumor。
- 新增 UCL 表达：`inquiry "评价"/"opinion"` → handler 键；`opinions_rank` 评级表常量。
- `opinion/<类别>` / `opinions/master` / `opinion/ultra` 持久化到 `meta`/`character`。
- 不可击杀（unconcious/die 闪逝）挂到大宗师 NPC 类型标记。

### 5.3 绝招 quest（承继 #743）
- 独孤求败：`accept = [ { kind = "item_id" id = dugubook ... } ]` → 传独孤九剑无招（`perform_known?`）。
- 黄裳：`accept = [ { kind = "item_id" id = zhenjing1 } { kind = "item_id" id = zhenjing2 } ]` + `ask_skill 摄心大法` 门控（240 jiuyin-shengong + 240 martial-cognize + 4 绝招）。

---

## 6. 验证方式（实现后）

- 定向测试 `test/kantele/npc/ultra_*_test.exs`（或并入对应 zone）：
  1. exp<200000 `ask 评价` → 「哼！你这点武功也出来丢人现眼？」
  2. 达宗师后 `ask 评价` → 「不必了，你…方面的修为已经称得上是宗师了！」
  3. `fight` 后按 `calc_level` 评级 → `opinion/<类别>` 写入正确 rank。
  4. 四类别全宗师 → `opinion/ultra=1` + rumor 江湖传闻。
  5. 击杀大宗师 → 闪逝不死亡。
  6. 独孤求败/黄裳 accept_object 后绝招正确授予。

---

## 7. 已登记的 GAP / Task

- Task **#1048**（本计划，审计完成）。
- 待登记：
  - GAP：评价子系统（ask_opinion/accept_fight/calc_level/check_opinion/check_ultra + query_ultra_master）引擎级缺失。
  - GAP：4 位大宗师 NPC 数据缺失。
  - GAP：独孤求败/黄裳 绝招 quest（accept dugubook/zhenjing1-2 + ask_skill）缺失（承继 #743）。
  - 承继：GAP #743（perform_known? can_learn/can_perform flags 代理）。

---

## 8. 实现记录（#1049，2026-11-24）

### 8.1 数据落地
- `huashan/dali/mingjiao/beijing.ucl` 各新增 1 个 characters 块 + 对应 startroom 的 `room_characters`：`ultra_dugu` / `ultra_huang` / `ultra_huoshan` / `ultra_kuihua`。四位均带 `ask_handler = "Kantele.NPC.Ultra"`、`ultra = {...}`（类别/技能表/逐字文案）、`env["opinion/ultra"]=1`、`combat.jiali=100`、_static inquiries_；**不放 apprentice/teach**（LPC 收徒函数全注释）。
- `clone_lib.ucl` 新增 3 件 quest 物：`dugubook` / `zhenjing1` / `zhenjing2`（原转换器整组丢失）。
- 每位宗师的 `msgs` 含 `vanish` / `vanish_chat`，对齐 LPC die/unconcious 的吐血闪逝逐字文案。
- **#1055 补**：四位 `msgs.init` 落 LPC `init()` 逐字反应（独孤/黄裳「微微一笑…点了点头」、霍山「眉头一皱，哼了一声」、葵花「扫了$n一眼，冷笑一声」；`$N/$n` 按房间 UCL 惯例改 `{npc}/{name}`）。

### 8.2 引擎新增
| 文件 | 内容 |
|---|---|
| `lib/kantele/npc/ultra.ex`（新） | AskHandler（评价/opinion/摄心大法 + 静态 inquiry 兜底）、`engage_decide/3`（fight 动态门控）、`calc_level/3`（四种 calc_mode）、`check_opinion/3`、`check_ultra/2`（四宗师 → opinion/ultra + rumor） |
| `lib/kantele/character/ultra_event.ex`（新） | `ultra/accept-fight` NPC 侧 set_temp("opinion") + `CallOut.schedule(2)`；玩家侧 `fight-result`（删 want_opinion + 内力清零）、`rank-result`（落 env/文案） |
| `lib/kantele/world/ultra_accept.ex`（新） | `accept_object` dugubook / zhenjing1+2 的 NPC 侧收受与逐字台词 |
| `lib/kantele/character/events/give_event.ex` | `ultra/give-item` 玩家侧 flag/奖励（残本 340 门 + 9 次 improve；真经双册合璧） |
| `lib/kantele/npc/engage_rule.ex` | `decide/5` 动态 handler 入口（仅 `Kantele.NPC.Ultra` 实现），`decide/3` 行为不变 |
| `lib/kantele/world/room.ex` | `engage_rule_deny?/3` 传 target/attacker 给 decide/5 |
| `lib/kantele/character/events/combat_event.ex` | `die/3` 新增 ultra 从句：闪逝 + chat + 满状态复位，**不进尸体/死亡流程**（ex NPC 是世界静态对象，不 destruct） |
| `lib/kantele/world/loader.ex` | 新增 `top-level family/env/handing/ultra`、`combat.per/neili/jiali/score`、`engage.*.handler`、`accept kind="ultra"` 解析；`#1032`（jiali）随本批关闭 |
| `lib/kantele/world/npc_init.ex`（新，#1055） | 玩家进房的 `init()` 派发：无条件通知玩家清全部 `want_opinion/<key>`；`ultrap` 时按 `ultra.msgs.init` 返回 `{:vision, 文案}` |
| `lib/kantele/character/events/move_event.ex` | `notice/2` 新增 `npc_init/2`（在 `greet/2` 前）；仅 `player:*` 进屋触发，对齐 LPC `interactive(me)` 守卫 |
| `lib/kantele/character/events.ex` / `ultra_event.ex` | 新 topic `ultra/init` → `UltraEvent.clear_intent/2`；`put_character` 走引擎既有 staged update |

### 8.3 与 LPC 的已知偏差（均属 ex 架构差异，非删减）
1. `check_opinion` 的 2 拍延迟用 `CallOut.schedule/5` 复刻；评级以 2 秒前的玩家快照为准，而 LPC `call_out` 读取的是到期时对象。
2. 大宗师「不可击杀」在 ex 实现为满状态复位而非 `destruct`：世界里的 NPC 是静态定义，销毁后无法重生。
3. `calc_level` 的 action["force"/"parry"/"dodge"] 用 `Kantele.Combat.Skills.query_action/3` 的固定 rng=1 快照（LPC 按当前武器随机选招）；`my_opinions` 与阈值表、skill/mapped/4000 内力 +20 等逐条保留。
4. ~~`ultrap(me)` init 点头/皱眉/冷笑未挂钩子~~ → **#1055 已实现**（2026-11-24）：走 `NpcInit` + `MoveEvent.notice/2`，逐字文案落 `ultra.msgs.init`，`want_opinion` 由玩家侧事件清全部键。无残留偏差。

### 8.4 验证
- `mix compile` 通过（仅基线告警）；6 个 UCL `validate_ucl.py` 全绿。
- `ultra_and_special_npc_test.exs` **16 tests / 0 failures**（含 #1055 三条：文案逐字、ultrap 门控 + 普通 NPC 不触发、清意图回执）；`move_greet` / `move_command` / `npc_greeting` 60 tests / 0 failures；`engage_rule` / `attitude_wiring` / `kickoff` / give 相关 70+ tests / 0 failures。
- 全量回归按 §0.4 登记 **#27**，未自行运行。

### 8.5 `ultrap/1` 判据更正（#1055 实现时发现）
- LPC `ultrap(ob)` 定义为 `ob->query("opinion/ultra")`（`adm/single/simul_efun/user.c:8-11`），**不是** `combat_exp >= 800M`。
- 本文 §4 第 1 条旧注「可复用 `Kantele.Character.Reborn.ultrap?/1`」**作废**：那是转世前置的 exp 判据，与本子系统语义不同。`NpcInit` 直接读 `meta.env["opinion/ultra"]`，与 `Kantele.NPC.Ultra.check_ultra/2` 写入键一致。
- 两组判定继续共存，不可互相替代（转世前置 vs 大宗师身份标志）。