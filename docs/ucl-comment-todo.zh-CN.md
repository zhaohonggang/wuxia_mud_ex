# UCL 注释还原：待做项清单

> **状态（2026-10-24 更新）**：B / C / D / E 均已完成并通过测试；F 已正式免除；
> G（两份文档的同步）本次一并完结。**待做项清空。**
>
> 基线：`mix test --seed 12345` → **3072 tests, 0 failures**；可达性 4190/4470 房。
> 当前（2026-10-24）：full `mix test` **4606 / 0**；可达性 **4190/4409（95.0%）**
> （房间总数随新区接入变化，可达数未降）。
> 本文档记录「把 `data/world` 里代表缺失功能的注释变成真实实现」这件事**尚未完成**的部分。
> 已完成的部分见文末「已完成」与 `docs/ucl-comment-implementation-plan.zh-CN.md`。

所有数字来自对当前 `data/world` 的实测扫描，不是估算。复现命令在各节「怎么查」里给出。

---

## 一、总览

| # | 待做项 | 规模 | 类型 | 优先级 |
|---|--------|------|------|--------|
| ~~A~~ | ~~补回 42 条条件丢失的外层方向守卫~~ | **已完成**（`71e5338`/`e5b14b1`） | 数据还原（机械） | — |
| ~~B~~ | ~~`guarded_exit` 守卫拦截机制~~ | **已完成**（loader 读 `behavior_config` + `check_guarders`；16 房） | 新功能 | — |
| ~~C~~ | ~~`check_dirs` / `check_out` / `ob->refuse`~~ | **已完成**（`Kantele.World.Trap` 副作用通道；18 条） | 新功能（需副作用） | — |
| ~~D~~ | ~~玩家性别数据缺失~~ | **已完成**（补数据路线：migration + 默认值 + `meta.env`） | 补数据链路 | — |
| ~~E~~ | ~~`xiangyang` inquiry 6 条~~ | **已完成**（P5-4a `give_item`；smith 工作链 P5-9） | 新功能 | — |
| ~~F~~ | ~~`city:mudren` 的 `enter` 传送门~~ | **已正式免除**（语料缺失的站外彩蛋，2026-10-24 决定） | — | — |
| ~~G~~ | ~~更新计划文档~~ | **已完成**（2026-10-24，两份文档同步） | 文档 | — |

另有 **1 处已知行为近似**与 **3 处踩坑约束**记在文末第九节。

**剩余待做：无**（2026-10-24）。B、C、D 原本依赖的两个前置——**副作用通道**（C）
与**性别数据链路**（D）——均已落地，各项随之完成。

---

## 二、A：外层方向守卫（✅ 已完成）

### 结果

提交：`71e5338`（用 `all_dirs` 区分「故意拦所有方向」与「丢了外层守卫」）、
`e5b14b1`（合并 24 条条件的外层守卫 + 补齐心法书）、
`3778496`（通配方向 veto 也能取到提示语）。

166 条 `valid_leave` 条件的当前状态（按 `Room.apply_vetoes/5` 的**真实判定顺序**
统计，见 `scripts/recount_veto_status.exs`）：

> **2026-10-24 注**：下表是 A 阶段完成时的快照。后续数据补齐（性别链路、
> 外层守卫合并）使条件总数变 177、生效数变 155（另有 18 条走 Trap 通道），
> 最新数字以文末第十节汇总为准。

| 判定 | 条数 |
|---|---:|
| **生效** | **133** |
| 跳过：条件未限定方向（疑似丢外层守卫） | 16 |
| 跳过：依赖运行时缺失数据（性别） | 9 |
| 跳过：含未实现的函数 | 8 |

> 这三行「跳过」是**互斥**的：条件在第一道拦不住的门上就被丢弃，
> 所以 16 条里其实有 10 条同时缺自定义函数、2 条同时缺性别数据。
> 若按条件内容做交叉统计，则是「18 条调用自定义函数」「11 条引用 gender」
> —— 见 C、D 两节。

### 关键教训：`all_dirs` 标记

原先 `direction_scoped?/1` 只看条件文本是否提到 `dir`，会把**原 LPC 本来就拦所有方向**
的条件（如端着汤不许离开厨房、嫖客不许离开妓院）误判成「丢了守卫」而全部跳过。
现在数据侧用 `all_dirs = true` 显式标注这类房间，判定顺序为：

```
applies?(方向匹配) → condition 缺失 → all_dirs? → direction_scoped?
→ supported? → enforceable? → 求值
```

### 线上抽查

- `goto death:qiao1` 向北：内力 120（force 20 < 500）、未喝孟婆汤、孟婆在场 → **被拦** ✅
- `goto death:qiao2` 向北：牛头在场 → 被拦 ✅
- `goto shaolin:dmyuan2`：携带心法书 → 正常进出 ✅

> `death:qiao1` 曾一度**修好又失效**，根因见第五节新增的第 4 条踩坑
> （`get_in/2` 读结构体 meta 抛异常）。

---

## 三、B：`guarded_exit` 守卫拦截机制（16 个房间，✅ 已完成）

### 现状（已完成时的样子）

数据里 16 个房间声明房间级行为（下表与数据一致，未变）：

```elias
    rooms "damen" {
      behavior = "guarded_exit"
      behavior_config = {
        guard_directions = ["north"]
        exempt_directions = []
        guarder = "men wei"
      }
```

> 注：`behavior_config` 的键名与本文档旧述不同——实际落地用的是
> `guard_directions` / `exempt_directions` / `guarder`（转换器从 LPC 的
> `set("behavior_config", ...)` 回填），没有 `guard_npc` / `direction` /
> `permit_module` / `permit_function` 这些计划中的键。

| 区 | 房间 | 守卫 | 方向 |
|---|---|---|---|
| baituo | `damen` / `ximen` | men wei | north / east |
| dali | `wangfugate` | chu wanli | in |
| guanwai | `xiaoyuan` | ping si | north |
| hengyang | `zhurongdian` | mi weiyi | northdown |
| huashan | `buwei1` / `laojun` / `square` / `xiaowu` | lu dayou / lao denuo / gao genming / feng buping | south / southup / northeast / east |
| shenlong | `dating` / `zoulang` | wugen daozhang / zhang danyue | south / west |
| taohua | `dating` | huang yaoshi | south |
| xiyu | `xxh2` / `xxroad5` | xingxiu dizi / chuchen zi | north / in |
| xuedao | `shandong2` / `sroad9` | bao xiang / sheng di | west / east |

### 实现（已落地）

1. **Loader**：`parse_behavior_config/1` 读 `behavior` / `behavior_config`，
   归一成 `guard_directions` / `exempt_directions`（Loader 侧注释记录了
   转换器的单键 `direction` 不可信，故以这两名单为准）。
2. **Room**：`movement_request/4` → `check_guarders/3` →
   `guard_direction/2` 按方向规则决定是否盘查（无方向信息的老数据保守不拦），
   找到守门 NPC 后调 `Kantele.Npc.Guarder.permit_pass/1`（opts 由
   `build_guarder_opts/3` 构造）。
3. **判定信息**：门派比对走 `meta.family` / `meta.born_family`；
   「背着他派的人上门」走 `mover.meta.carrying`（LPC `deep_inventory(ob)`），
   已按 `PlayerMeta` 无 `:carrying` 字段的现实用 `Map.get` 链取值。
4. **灰度**：没有单独开关——守卫链 fail-open：守卫 NPC 不在房、
   或已倒下（`meta.combat.dead`）一律放行，不会锁死玩家。

### 测试与审计

- `test/kantele/world/guarded_exit_runtime_test.exs`：loader 读取、
  守卫 NPC 门派、`baituo:damen` 只守 north、`huashan:buwei1` 除 south 外全守、
  `huashan:square` 守三向、同门放行、携带别派弟子被拦、
  `PlayerMeta` 无 `carrying` 不崩等，全绿。
- `scripts/audit_guarded_exit.exs`：16 房数据审计脚本。

> 遗留（无害）：`baituo:ximen` 的 valid_leave 里那条
> （`dir == 'west' && (int)me->query('combat_exp') < 600 && guarder`）
> 带 `guarder` 裸标识符，求值器按假值处理，不会误拦；B 的守卫链已覆盖该房。

---

## 四、C：三种自定义函数（18 条条件，✅ 已完成）

### 现状（函数表，未变）

| 函数 | 条数 | 场景 | 是否带副作用 |
|---|---:|---|---|
| `check_dirs(me, dir)` | 8 | 少林八卦阵（踩错卦序掉精 50、扣内力、改 `bagua/count`） | **是** |
| `check_out(me)` | 5 | 少林五行迷宫出口判定 | 是（计数器） |
| `ob->refuse(me)` | 5 | 城市擂台上擂主拒绝挑战 | 否（NPC 自身逻辑） |

这 18 条仍被 `LpcCondition.enforceable?/1` 判为不可执行（纯判定路径不拦），
但已由**独立的 Trap 通道**执行——`Kantele.World.Trap.dispatch/3` 按条件原文
识别陷阱类型，在 `movement_request` 里排在守卫盘查之后、纯条件 veto 之前。

### 实现（已落地）

- **判定与副作用分离**：`Trap.Wuxing.evaluate/3` / `Trap.Bagua.evaluate/3`
  是纯函数（只读 `meta.temp`），返回 `{:allow, effects}` / `{:block, msg, effects}`；
  effects 是**数据**，由房间进程发 `"trap/effect"` 事件给角色进程执行
  （`Kantele.Character.TrapEvent`），落盘走 `Records.save/1`。
  房间进程不写玩家 meta——只有角色进程能安全地改并落盘。
- **三个陷阱分支**：
  - `Trap.Wuxing`：五行迷宫。移植的是**整个 valid_leave**——转换器只留下
    `check_out(me)` 谓词，north 计数 / west 掉僧监都由这里补
  - `Trap.Bagua`：八卦阵。踩错卦序掉精 50、扣内力、改 `bagua/count`
  - `Trap` 的 `:arena` 分支：`ob->refuse(me)` →
    `Arena.refuse(dest_room_id, wizard?)`。与原计划不同的是**没有**做
    跨进程询问——LPC 里 refuse 读的是目标房间自己的 `close_by` 状态，
    `Kantele.World.Arena`（ETS 直读、fail-safe）已覆盖，且不硬编码房间 id
- **`wizard?` 判定**：走 `Kantele.Admin.Access.wizardp/1`（读
  `character.attributes["wiz_level"]`），所以 `movement_request` 必须传完整角色

### 测试

- `trap_wuxing_test.exs` + `trap_wuxing_runtime_test.exs`：纯逻辑 + 真实
  `movement_request` 链路（含「副作用真的下发到角色进程」与 abort reason 带正文）
- `trap_bagua_test.exs` + `trap_bagua_runtime_test.exs`：同上
- `arena_runtime_test.exs`：擂台关闭时非巫师被拦（LPC 原文）、巫师放行、
  只有 leitai 方向被拦、wudao1~4 共用一份状态、状态驱动无硬编码、
  underlt 无擂台出口故条件天然不触发

---

## 五、D：玩家性别数据缺失（11 条条件，✅ 已完成 · 补数据路线）

### 当时的现状

`me->query("gender")` 恒为 `nil`：表没有 gender 列、登录流程不写 `meta.env`，
11 条条件恒真或恒假，曾用 `LpcCondition.supported?/1` 整批挡下防误拦。

### 实现（已落地）

- **数据**：`priv/repo/migrations/20261003000000_add_gender_to_character_metadata.exs`
  给 character_metadata 加 `gender` 列，默认「男性」——老角色无需回填。
- **链路**：`Kantele.Character.Records.apply_to_character/3` 把 gender 写进
  `meta.env`（key 用原子 `:gender`，`query_prop/2` 走 `TreeMap` 路径读取），
  `ExitVetoContext.query("gender")` 于是拿得到。`@unsupported_fields`
  已清空，`supported?` 不再拦性别条件。
- **建号/修改**：目前只有默认值「男性」（与 LPC 新建角色一致），
  游戏内暂无修改性别的命令——`== '女性'` 类条件对所有人恒假（放行），
  与原版默认行为相同；要差异化需另做入口，不影响本项判定成立的事实。

### 现状核对（2026-10-24）

11 条性别条件**均已带方向守卫**（A 阶段补齐），随纯条件路径生效；
`present` 引用在场与否另说，见 `veto_effectiveness_test.exs` 的分类。
文档旧述「2 条同时缺守卫」已过时：`changan:qunyulou` 的性别条件现有
`dir == 'south'` 守卫；`xiyu:xxh6` 卡在 `direction_scoped?` 的是另一条
`this_player()` 条件（`marks/花`），与性别无关。

---

## 六、E：`xiangyang:wuxiuwen` inquiry 6 条（已完成 · P5-4a）

> **标题纠正（2026-10-19）**：本节旧标题写作「铁匠」，实际源文件是
> `d/xiangyang/npc/wuxiuwen.c`（武修文，郭靖二弟子，负责后勤）。`smith` 的
> `(: ask_me :)` 工作链是另一件事，归 P5-9 一次性场景，已于 2026-10-24 完成，
> 见文末「剩余」。

### 原状

数据里是 LPC 闭包，elias 无法解析：

```
# skipped inquiry "铁护腕": value "(: ask_me_1, 'huwan' :)" is unparseable by elias ...
```

| 图样 | 函数 | 产出 |
|---|---|---|
| 铁护腕 | `ask_me_1` | `huwan` |
| 铁护腰 | `ask_me_1` | `huyao` |
| 皮手套 | `ask_me_1` | `shoutao` |
| 皮围脖 | `ask_me_1` | `weibo` |
| 铁指套 | `ask_me_1` | `zhitao` |
| 铁背心 | `ask_me_2` | `beixin` |

### 回源结论

`ask_me_1/2` **不是铁匠图纸**（没有材料检查、扣料、打造），只是：

1. 门派门控（仅 `dao-xiang.c`；`wuxiuwen.c` 无）；
2. `present(name, me)` 限一件（仅 `ask_me_1`；`ask_me_2` 没有）；
3. 共享库存 `huju_count` / `beixin_count` 小于 1 → 耗尽文案；
4. `new("/d/shaolin/obj/" + name)` → `move(this_player())` → `message_vision` → 返回成功文案。

因此按通用 `kind = "give_item"` 落地，而不是建 `smith` 行为。

### 已完成（2026-10-19）

- **数据**：`xiangyang:wuxiuwen` 6 条（`huju_count=20` / `beixin_count=2`、无门派门控）；
  `clone_lib:shaolin_dao_xiang` 7 条（`huju_count=50` / `beixin_count=5`、限「少林派」、
  `vision_name="道相"`）。逐字保留 LPC 文案，包括铁背心耗尽的「武器已经发完了」原文。
- **代码**：`Kantele.World.InquiryHandlers`（kind 注册表）+ `...GiveItem`
  （玩家侧发放/去重/库存/门派/广播/回执）；NPC 侧 `NpcAskEvent` 按 `kind` 发
  `npc/inquiry`，玩家侧 `NpcScriptEvent.inquiry_result` 落库后回发
  `npc/inquiry_consume`，NPC 侧自减 `NonPlayerMeta.inquiry_state`；loader 新增
  `parse_inquiry_state/1`（elias 的 `"true"/"false"` 字符串归一）。
- **测试**：`npc_script_event_test.exs`（23）+ `loader_inquiry_state_test.exs`（2），
  子集 **25/0**；相关 loader/NPC 子集 **64/0**。

### 剩余

无（2026-10-24 清零）。`smith` 的 `(: ask_me :)` 工作链已于 **P5-9** 完成：

- 回源修正：文档旧述「job/working/halt_working 与材料/费用」与 LPC 源
  （`/inherit/char/smith.c`）不符，真实链条是 `ask_me` 随机派活 →
  `gu`/`dapi`/`cuihuo` 干活 → `reward` 结算，另有 `repair`/`xiuli`
  两段确认修理。以本地源码为准实现。
- **代码**：`lib/kantele/world/npc_actions/smith.ex`（注册于
  `xiangyang:tiejiangpu`；派活门控、干活结算、修理报价两段确认）+
  `lib/kantele/world/inquiry_handlers/smith_job.ex`（kind="smith_job"）。
- **测试**：`npc_actions_smith_test.exs`（23）+ `inquiry_handlers_smith_job_test.exs`（12），
  合计 **39/0**；含注册表 **81/0**。

---

## 七、F：`city:mudren` 的 `enter` —— ✅ 已正式免除（2026-10-24）

### 查证结论

LPC 源（`d/city/mudren.c`）：

```c
set("exits", ([
        "south" : __DIR__"zuixianlou",
        "enter" : ([ "filename" : _DIR_AREA_"world.c",
                     "x_axis" : 75,
                     "y_axis" : 69
                ]),
    ]));
```

这是一个指向 **标准 Mud outdoors 大地图**（`world.c` 的 75,69）的门户映射。
而 **`world.c` 不在我们的语料里**（`C:\files\git\mud` 与 `mud\d` 下均无此文件）。

另外这间房本身是站点外的玩笑地点（房间名「武林外传」，描述是 mud 管理员的 BBS 办公室，
`item_desc` 里写着 `欢迎访问--bbs.mud.ren`）。

### 决定（2026-10-24）

**正式免除**：把它当作「语料缺失的站外彩蛋」记录下来，不实现传送门。
`skipped` 注释里对应的这 1 条标记为「已决议免除」，不再是待办。
若将来引入 `world.c` 语料，再单独做门户支持。

对应的 valid_leave 条件 `dir == 'enter' && !userp(me)`（NPC 不许进）是会执行的，
保留即可。

---

## 八、G：更新计划文档（✅ 已完成 · 2026-10-24）

本次已把 `docs/ucl-comment-implementation-plan.zh-CN.md` 改成「计划 + 实际结果对照」：
§8 验收清单逐条核对（含 §3.4 inquiry 从「未做」改为已完成），
§10「仍然待做」改为指向本文件。本文件作为待做项入口，状态横幅记录
2026-10-24 快照数字（full `mix test` 4606/0；可达性 4190/4409 = 95.0%）。

---

## 九、已知行为近似与踩坑约束

### 1. 藏经阁随机书是「加载时随机一次」

原 LPC 靠 `no_clean_up = 0` 的房间重置来重随；loader 的运行时候选机制是在
**世界加载时**取一次（见 `Kantele.World.Loader.parse_items/2`）。
这是既有机制的限制，不是本次引入。

### 2. 两条硬约束（踩过多次，改数据前务必确认）

- **进 `Meta.Trim` 保留清单的字段必须能 JSON 编码**。
  裁剪后的角色副本会发给 web 客户端（`Kalevala.Websocket.Handler`），
  加了 `Kantele.Character.Stats` 却没给它 `Jason.Encoder` 就导致 websocket 进程崩溃。
- **Elias 词法器对转义/空格很挑**，写 UCL 字符串时：
  - 嵌套 `\"` 会**提前截断字符串** → 条件/描述里的字面量一律用单引号
  - 字符串内「逗号后带空格」或「逗号后紧跟数字」会**提前截断**
  - `\` 转义不要原样保留（`\t` 会变成 `\\t` 而语法错误）

### 3. 条件求值异常会被静默放行 —— 别再依赖它「保险」

`LpcCondition.evaluate/2` 的 `rescue` 会把求值异常转成「放行」。
这是防止求值器缺陷**锁死玩家**的刻意设计，但副作用是：
**任何求值器缺陷都会永久隐身**（条件恒假 = 拦截形同虚设，且没有任何报错）。

线上已因此踩过一次：`ExitVetoContext.skill_level/2` 用了
`get_in(meta, [:stats, :skills])`，而 `get_in/2` 走 `Access` 协议 ——
线上的 meta 是**结构体**（`%PlayerMeta{}` / `%NonPlayerMeta{}`），没有实现
`Access`，于是抛
`Kalevala.Meta.Trimmed.fetch/2 is undefined`，被 rescue 吞掉。
后果是**所有含 `me->query_skill()` 的条件恒假**（孟婆桥、阎罗殿等
「内力不足不许走」的门槛全部失效）。修在 `cc0eead`。

已做的加固：

- `rescue` 分支现在会 `Logger.warning`，异常不再无声消失
- 根因是**测试用普通 map 模拟 meta**，而线上是结构体 ——
  已补 3 条用真结构体的回归测试（`cc0eead`）

> 写涉及角色 meta 的代码时：**结构体不支持 `get_in/2`，用 `Map.get` 链。**

### 4. `player.ex` 的 temp 契约变更

`test/kantele/character/player_meta_temp_test.exs` 原本断言「temp 不随 trim 进入房间视图」，
现改为**保留**（valid_leave 的 `query_temp` 需要它）。原因与代价写在该测试里。

---

## 十、已完成（勿重复）

| 项 | 提交 | 结果 |
|---|---|---|
| P0a 商人商品引用落地 + loader 跨区解引用 | `0818ace` | 168 条引用生效 |
| 转换区物品 meta 回填（set_weight/init_*/food 等） | `c7c5fd9` | 685 个物品；武器有伤害、食物可食 |
| P0b 补建缺失物品 + `/clone` 药材入 `clone_lib` | `9e83dea` | 227 个物品 |
| P0c `/clone` 标准库 + 漏建物品 | `74f41a0` | 108 个物品；`vendor_goods` 注释清零 |
| P1 `d/` 之外的目标接通 | `f7d3d92` | 17 条出口；含 2 处 `/b` 与 `/d` 重复房间识别 |
| P2 valid_leave 拦截 + 提示语 | `1cdd66a`、`8558a2f` | 首批 95 条生效 |
| `Meta.Trim` 保留清单修正 | `f8ea452` | 修掉守卫/护主/条件恒真三处静默失效 |
| 性别条件守卫 | `e5e243a` | 避免 6 条误拦 |
| P3a 八卦阵 64 条出口 | `6d157ba` | **顺带修掉 `bagua0` 死锁** |
| P3b 华山六扇石门 | `6d157ba` | `hole_a..hole_f` |
| P3d 藏经阁随机书 | `6d157ba` | 7 本书 + 2 条随机候选 |
| A1 `all_dirs` 标记 | `71e5338` | 12 个「本就拦所有方向」的房间恢复执行 |
| A2 合并外层方向守卫 | `e5b14b1` | 24 条守卫合并；生效条件 **95 → 133** |
| A3 通配方向提示语 | `3778496` | `direction = "*"` 也能取到提示原文 |
| `query_skill` 读结构体抛异常 | `cc0eead` | 孟婆桥等技能门槛全部恢复；rescue 加日志 |
| 移除临时 `debug_skill/2` | `b6feb5f` | 清理误入提交的探针函数 |
| B `guarded_exit` 守卫链 | — | 16 房；loader 读 `behavior_config` + `check_guarders`；`guarded_exit_runtime_test.exs` 全绿 |
| C 自定义函数陷阱通道 | — | `Kantele.World.Trap`（wuxing / bagua / arena）；18 条条件经 `"trap/effect"` 事件执行副作用 |
| D 性别数据链路 | `20261003000000` | character_metadata.gender 默认「男性」+ 写 `meta.env`；`@unsupported_fields` 清空 |
| P5-9 铁匠打工链 | — | `npc_actions/smith.ex` + `inquiry_handlers/smith_job.ex`（ask_me 派活→干活结算→repair）；39/0 |
| F `city:mudren` enter | — | 正式免除（语料缺失的站外彩蛋，2026-10-24 决议） |
| G 文档同步 | — | 本文件 + implementation-plan 改为「计划 vs 实际结果」 |

`skipped` 注释：**299 → 1**（仅剩 F 的 1 条，已正式免除）。

`vendor_goods` 注释：**清零**。`valid_leave` 条件（`scripts/recount_veto_status.exs`，
2026-10-24）：**177 条**中纯条件路径生效 **155**、跳过 22
（8 条「未实现的函数」= 少林八卦阵 `check_dirs`；14 条「未限定方向」，
含五行迷宫 `check_out` ×5 与擂台 `ob->refuse` ×5）——这 18 条自定义函数条件
实际由 Trap 通道执行（见 C 节），合计 **173/177 生效**。
剩下 4 条是转换器 artifact、均无害：`beijing:kediandayuan`（技能条件丢外层守卫）、
`huashan:bingqifang`（裸变量 `j > 1`）、`taishan:nantian`（缺外层守卫）、
`xiyu:xxh6`（`this_player()` 条件缺外层守卫）。
Full `mix test`：**4606 / 0**；可达性 **4190/4409（95.0%）**。
