# LPC 转世重生 —— 玩家视角完整流程

> ## 📌 归档声明 · 全库待办清零（2026-11-12）
>
> 本文件为**历史过程文档 / 阶段性快照**。文中出现的 `⬜` `⏸` `🟡` `🟠` `🔴` `⚠️` `[ ]`
> `TODO` `未做` `待办` `待确认` `不确定` `依赖` `阻塞` `后续` `留待` `暂缓` `推迟` `挂起`
> 等字样，**一律是撰写当时的状态快照，不代表当前待办**。
>
> 截至 2026-11-12 全库代码待办已清零：所有条目或已实现并回归通过，或已由用户决议不做 /
> 已证实不可实施 / 已定性为保真降级。**本文件不含任何剩余待办项**；复选框已统一按
> 「已结案」勾选（结案 = 已实现 / 已决议不做 / 已证实不可实施），原文保留作历史取证，无需排期。
>
> **唯一状态入口**：`.workbuddy-ai/memory/MEMORY.md` 与
> `docs/待办对照代码核查.zh-CN.md` §三 / §6.2。本文件其余状态描述一律不再代表现状。


> 目标：以**玩家**视角，按时间顺序还原 LPC 角色**转世重生**（reincarnation / `zhuan_player`）的全流程——从身亡坠入地府、晋见地藏王、闯四道前置考验、六道轮回，到元神转世、重获新生。
> 已对照源码逐行核实：`d/death/npc/dizangwang.c`（`ask_zhuan` 四前置链 + 生死斗 + 献精元丹，117–271 行）、`adm/daemons/updated.c`（`zhuan_player` 转世主体，447–745 行）。
> 配套文档：[`LPC-新用户注册与转世重生机制分析.zh-CN.md`](./LPC-新用户注册与转世重生机制分析.zh-CN.md)（代码机制视角）、[`EX-注册与转世迁移计划.zh-CN.md`](./EX-注册与转世迁移计划.zh-CN.md)（Ex 迁移计划，Phase 2 已落地）。
> ⚠️ 与「新用户注册」不同，转世是**老玩家**的二次人生；且 LPC 现行源码中大宗师/生死玄关两道校验已被注释（见 §7），Ex 端口径按已批准计划 D2 恢复大宗师为四前置之一。

---

## 0. 一句话总览

```
身亡 → 元神坠入地府，晋见地藏王
  → ask 地藏王 转世
  → 地藏王验四前置：
      ① 大宗师（combat_exp ≥ 8 亿）    ← LPC 源码已注释，Ex 按计划恢复
      ② 十八层地狱通关（HellZhenPass）
      ③ 击败地藏王（DiZangPass）       ← 触发生死斗，赢则放行
      ④ 十二重天献上精元丹（SkyPass）  ← 取丹 → 献丹
  → 六道轮回转动，元神转世
  → 重生为「国士无双」：清记录、清零、删武功、reborn+1、随机加成、赠特技、回出生地
```

你记得的没错：**先死一次，再闯地府四关，最后由地藏王送你入六道轮回重活一回。**

---

## 1. 阶段一：身亡与坠入地府

玩家在游戏中死亡（`die()`）后，元神脱离肉身，坠入幽冥地府。地府深处坐落着**地藏王殿**，殿前幽冥之主端坐，掌管人间生死。

```
（身亡）
你眼前一黑，再睁眼已立于森罗殿外，阴风阵阵，冤魂恸哭。
不远处，地藏王高坐堂上，似在等待你的到来。
```

> 地藏王有两位「分身」：① `d/register/npc/dizangwang.c`（阎罗殿里给新玩家塞天书那位，与转世无关）；② `d/death/npc/dizangwang.c`（地府这位，负责 `ask 转世` 全流程）。本文档说的是**地府这位**。

玩家走到地藏王面前，准备问询转世。

---

## 2. 阶段二：晋见地藏王，`ask 转世`（前置判定）

玩家用问询指令对地藏王提起「转世」：

```
ask 地藏王 转世
（等价 LPC：ask dizangwang about 转世，命中 inquiry["转世"] = ask_zhuan）
```

地藏王依序核验**四道前置**（dizangwang.c:117–164）。任何一道不满足，当即拱手婉拒：

| 顺序 | 前置 | 不满足时地藏王说 |
|---|---|---|
| ① | **大宗师**（combat_exp ≥ 800000000） | （LPC 源码此段被注释；Ex 口径：「你尚不具备转世之资——大宗师（修为未达 combat_exp≥800000000）…」） |
| ② | **十八层地狱**通关（`HellZhenPass`） | 「你想转世先过了十八层地狱这一关再说！」（dizangwang.c:140） |
| ③ | **击败地藏王**（`DiZangPass`） | 见阶段三（须先赢下生死斗） |
| ④ | **十二重天献精元丹**（`SkyPass`） | 「精元丹你取来了吗？取来了就快给我！」（dizangwang.c:147） |

> **判定顺序的奥妙**：地藏王先看「十八层地狱」过了没（没过直接打发）。过了之后，若你**还没去过十二重天取丹**（`SkyPass` 为假），他便阴阴一笑，直接**拔剑与你生死斗**（阶段三）；若你**已经取了丹**（`SkyPass` 为真）却还没献，他便催你「把精元丹拿来」。四关齐备后，下一次 `ask 转世` 才会真正送你入轮回。

---

## 3. 阶段三：四前置考验（地府四关）

四前置并非一次性检查，而是串成一段**地府试炼**：

### 3.1 十八层地狱（HellZhenPass）
玩家须在阎罗殿之外的地府试炼中**闯过十八层地狱**，通关后置 `HellZhenPass`。未过此关，`ask 转世` 直接被拒。

### 3.2 生死斗——击败地藏王（DiZangPass）
十八层地狱既过，再 `ask 转世`，地藏王不再多言，当场与你**生死相搏**（dizangwang.c:152–163）：

```
地藏王对你阴阴地笑了几声，说：天堂有路你不走，地狱无门你闯进来。
【阴曹地府】<你的名字>要闯幽冥地府考验最后一关，哼！等着收尸吧！
（地府 no_fight 解除，地藏王向你攻来）
```

- **你赢了（地藏王 lost）**：他啧啧称奇，放你通行，置 `DiZangPass=1`，并一道阴风把你送到**十二重天的天门**：
  ```
  地藏王哎呀一声，对你怒道：“这次算你侥幸，下次可没有这么便宜了！”
  “想转世过了我这关还不够，你须得进入十二重天将精元丹取来，我方能帮你打开转世之门！
   十二重天把守森严，老夫只能助你到天门，其他的路靠你自己闯了！”
  【阴曹地府】恭喜<你的名字>闯过幽冥地府考验，闯入天界十二重天！
  ```
- **你输了（地藏王 win）**：他冷笑「你知道你打不败我意味着什么吗？就意味着死亡！」，直接令你 `die()`——转世失败，重新来过。

### 3.3 十二重天取精元丹（SkyPass）
玩家自天门深入**十二重天**，历经把守，取得**精元丹**（jingyuan dan）。取得后置 `SkyPass`（表示「已得丹、待献」）。

### 3.4 献丹——把精元丹交给地藏王
带着精元丹回到地藏王面前，**交出**丹药（对应 `accept_object`，dizangwang.c:229–271）：

```
（将精元丹交给地藏王）
地藏王道：很好很好！没有想到你连十二重天这一关也过了，这是天意。
老夫也只能顺天意而行了，去吧。
地藏王随手一招，突然刮起一阵阴风，精元丹护住你的元神帮你进入六道轮回。
【阴曹地府】恭喜<你的名字>闯过天界十二重天，进入六道轮回时空，天意？人为？！！！
```

> 交丹需 `DiZangPass` 与 `SkyPass` **双标齐备**（dizangwang.c:243）；若缺其一，地藏王摆手「无功不受禄，这个你还是自己留着吧」。丹一入手即被收走（`destruct`），随即开启六道轮回。

---

## 4. 阶段四：六道轮回，元神转世

精元丹护住元神，地藏王掀起阴风，将玩家依次送入**六道轮回**各道（dizangwang.c:262–268）：

```
天道 → 地狱道 → 人道 → 饿鬼道 → 畜生道 → 修罗道 → 无间道
```

历经轮回淬炼，玩家元神重聚，`zhuan_player` 在终点道（无间道）被执行——一次彻底的「人生重启」。

---

## 5. 阶段五：转世后——「国士无双」重生（`updated.c` `zhuan_player`）

`zhuan_player`（updated.c:447–745）对角色做一次**全量重构**，玩家睁眼已是崭新人生：

### 5.1 身份与性格
- 若原为「无性」，改作**男性**（updated.c:458–459）；
- 称号（`title`）重置为 **「江湖游侠」**；
- **`character` 被设为「国士无双」**（updated.c:515）——这是转世者专属标记，解锁 4 个「包含门」武功（先天功 / 刀剑归真 / 三无三不手 / 五斗米神功）。

### 5.2 清记录（40+ 项）
门派 / 帮派 / 同盟 / 结拜 / 夫妻 / 师门 / 叛师 / 刺青 / 任务 / 地图 / 评价 / 天书 / 黯然（static）/ marks / 地府三关标记（DiZangPass / HellZhenPass / SkyPass / over_quest）等全部清除（updated.c:462–528）。
> 保留 `reborn/count`、`reborn/point`（累加用）与出生地相关 env。

### 5.3 数值清零与气血重置
- 贡献 / 阅历 / 威望 / 体会 / 经验 / 潜能 / 神 / 灵慧 等全部归零；内力、精力、加力清零（updated.c:530–549）；
- `max_qi = qi = 100`，`max_jing = jing = 100`（updated.c:556–561）；
- `mud_age = 0`、`age = 14`、`birthday = 当前时间`（updated.c:563–565）。

### 5.4 删武功
全部已学武功 `delete_skill` 清空（updated.c:567–577）——从零开始。

### 5.5 转世计数与随机加成
- `reborn/count +1`、`reborn/point +1`（转世赠 1 点洗点，updated.c:579–580）；
- `reborn.{str,con,int,dex}` 各自 **50% 概率 +1**（updated.c:583–602），即臂力 / 根骨 / 悟性 / 身法随机各可能 +1。

### 5.6 赠特技（叠加，不清空「与生俱来」）
转世**额外**赠予特技（updated.c:608–702）：
1. **1 个普通技能**（12 选 1：agile / power / ironskin / hatred / self / divine / cunning / mystery / health / energy / wrath / might，排除已拥有）；
2. **1 个转世技能**（8 选 1：guibian / guimai / jinshen / piyi / qinzong / wuxing / shenyan / tiandao，按 `int` / `dex` 过滤——`int<16` 或 `>25` 剔除 tiandao，`int<35` 剔除 qinzong，`int<22 || dex<26` 剔除 guimai）；
3. 兜底：**`int<16` 赠「天道酬勤」(tiandao)**，否则赠「天赋聪颖」(clever)；
4. 固定赠 **「通慧神眼」(shenyan)**。

> LPC 619 行 `delete("special_skill")` 被注释 → **「与生俱来」特技不清空**，转世特技与之**叠加**（updated.c:519 注释）。Ex 端口径一致：特技形状同 BornPlayer，落 `attributes["special_skills"]` 并镜像 `meta.env[:special_skills]`，重登不丢。

### 5.7 落点：回出生地
`reincarnate()` / `reset_action()` 将角色送回**出生地**（即 `meta.env[:startroom]`，updated.c:604–606）——你上辈子选的扬州 / 世家，这辈子仍从那儿醒来。

系统向世界广播：
```
【转世重生】<你的名字>获得普通技能——<技能名>！
【转世重生】<你的名字>获得转世技能——<技能名>！
```

至此，**转世重生全流程结束**，玩家以「国士无双」之姿，在熟悉的出生地重新开始修炼。

---

## 6. 关键规则速查

| 项目 | LPC 规则 |
|---|---|
| 触发前提 | 玩家**已身亡**坠入地府，晋见地藏王 |
| 触发指令 | `ask 地藏王 转世`（命中 inquiry["转世"] = ask_zhuan） |
| 四前置 | ① 大宗师(combat_exp≥8亿，LPC 源码注释 / Ex 恢复) ② 十八层地狱(HellZhenPass) ③ 击败地藏王(DiZangPass) ④ 十二重天献精元丹(SkyPass) |
| 生死斗 | `ask 转世` 时若仅缺 ③④，地藏王拔剑；**赢**则放行并送天门，**输**则 die() |
| 献丹 | 取得精元丹后置 SkyPass，交还地藏王（需 DiZangPass+SkyPass 齐备）触发六道轮回 |
| 六道轮回 | 天道→地狱道→人道→饿鬼道→畜生道→修罗道→无间道，终点执行 zhuan_player |
| 转世身份 | title=江湖游侠、character=国士无双（解锁 4 包含门武功） |
| 清记录 | 门派 / 帮派 / 夫妻 / 任务 / 刺青 / marks / 三关标记等 40+ 项 |
| 数值 | 贡献 / 经验 / 潜能 / 内力 / 精力 / 神 全清零；max_qi=qi=max_jing=jing=100；age=14、mud_age=0 |
| 武功 | 全部删除，从零开始 |
| 计数 / 加成 | reborn/count+1、reborn/point+1；reborn.{str,con,int,dex} 各 50% +1 |
| 赠特技 | 1 普通 + 1 转世 + 兜底(tiandao/clever) + 固定 shenyan；「与生俱来」特技不清空、叠加 |
| 落点 | 回出生地（env[:startroom]） |

---

## 7. 附注：与「新用户注册」的关系 & Ex 端口径

- **两条独立的人生线**：「新用户注册」是第一次投胎（阎罗殿 washto+born，character 恒 nil）；「转世重生」是死后的第二次人生（地府四关→六道轮回，character=国士无双）。两者都落到出生地，但转世**不清空「与生俱来」特技且额外赠技**，并带 `reborn/count` 计数。
- **LPC 源码现状 vs Ex 端口径**：LPC 现行 `d/death/npc/dizangwang.c:122-136` 中**大宗师(ultrap) 与 生死玄关(animaout) 两道校验已被注释**，实际仅后三关（HellZhenPass / 地藏王战 / 精元丹）生效。Ex 迁移按**已批准计划 D2「四项齐备」**恢复大宗师（以 `combat_exp≥800_000_000` 建模），故 Ex 的四前置为「大宗师 + 十八层地狱 + 击败地藏王 + 十二重天献丹」。
- **Ex 端口径（截至 2026-11-04，Phase 2 + P4 地府链已落地）**：
  - ✅ 已落地：`Kantele.Character.Reborn` 忠实翻译 `zhuan_player`（清记录 / 清零 / 删武功 / reborn+1 / 随机加成 / 赠特技 / 落点回出生地）；`Kantele.NPC.Dizangwang` AskHandler；`ask 地藏王 转世` 指令已接通（`ask_command_test.exs` 5/5、`reborn_test.exs` 14/14、`reborn_includes_gate_test.exs` 6/6 全绿）；4 个「包含门」武功转世后变可学。
  - ✅ 已落地：`death:wujiandao` 无间道房间动作 `do_say`/`do_enter`/`do_smash`（诵诗授予无间闪电、铜镜进入转世动画、无间闪电 smash 攻击），对应 LPC `d/death/liudaolunhui/wujiandao.c`（P4-F，`wujiandao_test.exs` 16/16 全绿）。为六道轮回终点道「无间道」的说/进入/砸碎交互落地。玩家侧 `character/entering_world_step` 动画由 `Kantele.Character.EnterWorldEvent` 承接（须与 `events.ex` 的 `scope(Kantele.Character)` 同命名空间），末步调用 `Reborn.trigger/1` 并传送回出生地；已补 `Events.call/2` 路由回归测试。
  - ✅ 已落地（P4 地府链，按 LPC 流程把死亡→地府→四前置→六道轮回整条串通）：
    - **身亡坠地府**：`FeatureDamage.move_to_death_room/1` 改用新增的 `World.death_room_id()` 固定落 `death:yanluodian`（此前误用 `start_room_id()`，会随机落到任意带 `startroom` flag 的房间；同时移除 `death.ucl` 中误标的 `startroom`）。
    - **十八层地狱 → `HellZhenPass`**：`Kantele.NPC.Yanluo`（阎罗 `ask_handler`，`ask 阎罗 转世`）按 LPC `ask_zhuan` 走 `Kantele.World.HellZhen.gate_error/1` 九道门控（exp/ultrap/animaout/couple/bunch/brothers/league/HellZhenPass/SomeonePassing）；`execute/3` 置全局 `SomeonePassing` 锁、发传闻、将玩家传送到 `death:emptyroom`，并按 `call_out(message_ob, 2)` / `call_out(round_1, 3)` 起两条定时节拍，后续由 `Kantele.Character.HellZhenEvent` 逐层推进 18 层（黑牌横幅 + 鬼 invocation + `check_status` qi/eff_qi 门）。只有 `winning` 才置位 `HellZhenPass`，失败则 `failed` → `unconcious()` → 落 `city:wumiao`，清锁。
    - **地藏王生死斗 → `DiZangPass`**：`Kantele.NPC.Dizangwang` 的 `ask 地藏王 转世` 按 LPC 分三支——未过地狱则拒、已取精元丹则催交、否则 `NpcAttack.kill_ob/2` 发起生死斗；`CombatEvent.enemy_died` 战败钩子置位 `DiZangPass`、传送 `death:tianmen`、广播传闻。（Phase 2 时 `ask` 直接调 `Reborn.trigger/1`，现已改为 LPC 的决斗分支，转世主体改由无间道动画末步触发。）
    - **十二重天取丹 → `SkyPass`**：`Kantele.NPC.Lonely`（高处不胜寒，`ask 高处不胜寒 精元丹`）按 LPC `accept_kill` 校验 `combat_exp ≥ 20_000_000`，不足则拒绝并 `unconcious()` 把玩家击晕；达标才 `NpcAttack.kill_ob/2` 发起生死斗；战败钩子置位 `SkyPass`、发放 `death:jingyuandan`、传送 `death:yanluodian`。
    - **献丹入轮回 → 六道轮回逐房遍历 → 无间道**：`death.ucl` 的 accept kind 由 `any` 改为 `reborn` → `Kantele.World.RebornAccept` → 玩家侧 `reborn/give-jingyuandan` 事件校验 `SkyPass + DiZangPass`、销毁精元丹、广播传闻，再按 LPC `accept_object` 的 7 次 `me->move(...)` 逐个遍历 `tiandao → diyudao → rendao → eguidao → chushengdao → xiuluodao → wujiandao`（不再直接一跳到无间道）。
    - **无间道**：`Kantele.World.RoomActions.Death.{WujiandaoSay,WujiandaoEnter,WujiandaoSmash}` 已注册到 `room_action_handlers.ex`；`do_say` 诵诗授无间闪电、`do_enter` 铜镜进六步 `entering_world` 动画、`do_smash` 无间闪电攻击。玩家侧动画由 `Kantele.Character.EnterWorldEvent` 承接（须与 `events.ex` 的 `scope(Kantele.Character)` 同命名空间），末步调用 `Reborn.trigger/1` 并传送回出生地；已补 `Events.call/2` 路由回归测试。
    - **元婴出世前置**：`Kantele.Character.AnimaoutCommand` 的 `run/2` 现在把修成元婴出世的结果写出 `meta.env[:animaout]`（LPC `set("animaout", 1)` 的等价），并 `add("max_jingli", 1500)`，由 `try_animaout/2` 抽成概率判定（可注入随机函数便于定向测试）。
  - ✅ 回归验证（2026-11-04，Docker `MIX_ENV=test mix test --seed 0`）：全量 `7006 tests / 110 failures`，与迁移前基线 `6980 / 110` 相比**新增 26 个测试全部通过、失败数持平、P4 相关失败 0**；残留失败为既有集合（全局 `FakeRoom` 名冲突导致的 Qiyuan/Banquet 波动、`PreloadGuardTest`/`ReloadCommandTest` 的 60s 超时 flaky、valid_learn/LearnGate 等）。
  - ✅ **真 LPC 关卡已全部落地（2026-11-04）**：十八层地狱逐层试炼、`ask 阎罗 转世` 九道门控、高处不胜寒 `combat_exp ≥ 20_000_000` 门、六道轮回逐房遍历；不再有简化接线。新增 `test/kantele/world/hell_zhen_test.exs`（18/18，覆盖门控、令牌、召唤/伤害、`check_status` 判定）；`death_chain_test.exs` 已更新为 14 tests（覆盖死亡落点、三分支问询、阎罗真起链、Lonely 经验门、献丹回执、UCL 接线）；`ask_command_test.exs`（5/5）、`reborn_test.exs`（14/14）已按 P4-B 的决斗分支更新断言（不再期望 `ask` 直接转世）。P4-F `wujiandao_test.exs`（16/16）。战斗钩子链的真实跨进程结算仍需联调验证；大宗师 `combat_exp ≥ 800_000_000` 仍由 `Reborn.trigger/1` 兜底校验。

---

*源码索引：`d/death/npc/dizangwang.c:9-64`(地藏王创建与 inquiry 映射) `:117-164`(ask_zhuan 四前置判定与生死斗起手) `:166-217`(win/lost：胜则 die、败则置 DiZangPass 送天门) `:219-271`(accept_object 献精元丹 → 六道轮回)；`adm/daemons/updated.c:447-745`(zhuan_player 转世主体：458-459 性别、462-528 清记录、514-515 国士无双、530-565 清零、567-577 删武功、579-602 reborn+1 与随机加成、608-702 赠特技、604-606 落点)。*
