# UCL 注释还原：待做项清单

> 基线：`mix test --seed 12345` → **3072 tests, 0 failures**；可达性 4190/4470 房。
> 本文档记录「把 `data/world` 里代表缺失功能的注释变成真实实现」这件事**尚未完成**的部分。
> 已完成的部分见文末「已完成」与 `docs/ucl-comment-implementation-plan.zh-CN.md`。

所有数字来自对当前 `data/world` 的实测扫描，不是估算。复现命令在各节「怎么查」里给出。

---

## 一、总览

| # | 待做项 | 规模 | 类型 | 优先级 |
|---|--------|------|------|--------|
| ~~A~~ | ~~补回 42 条条件丢失的外层方向守卫~~ | **已完成**（`71e5338`/`e5b14b1`） | 数据还原（机械） | — |
| B | `guarded_exit` 守卫拦截机制 | 16 个房间 | 新功能 | 中 |
| C | `check_dirs` / `check_out` / `ob->refuse` | 18 条条件 | 新功能（需副作用） | 中 |
| D | 玩家性别数据缺失 | 11 条条件 | 补数据链路 | 需决策 |
| E | `xiangyang` 铁匠 inquiry 6 条 | 6 条 | 新功能 | 低 |
| F | `city:mudren` 的 `enter` 传送门 | 1 条 | **建议正式免除** | 低 |
| G | 更新计划文档（进度已严重滞后） | 1 份文档 | 文档 | 中 |

另有 **1 处已知行为近似**与 **3 处踩坑约束**记在文末第五节。

剩余待做 **B / C / D / E / F / G**，其中 B、C、D 依赖同一个前置：
**副作用通道**（见 C）与**性别数据链路**（见 D）。

---

## 二、A：外层方向守卫（✅ 已完成）

### 结果

提交：`71e5338`（用 `all_dirs` 区分「故意拦所有方向」与「丢了外层守卫」）、
`e5b14b1`（合并 24 条条件的外层守卫 + 补齐心法书）、
`3778496`（通配方向 veto 也能取到提示语）。

166 条 `valid_leave` 条件的当前状态（按 `Room.apply_vetoes/5` 的**真实判定顺序**
统计，见 `scripts/recount_veto_status.exs`）：

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

## 三、B：`guarded_exit` 守卫拦截机制（16 个房间，当前完全未实现）

### 现状

数据里有 16 个房间声明了房间级行为：

```elias
    rooms "damen" {
      behavior = "guarded_exit"
      behavior_config = {
        guard_npc = "men wei"
        direction = "north"
        permit_module = "Kantele.Npc.Guarder"
        permit_function = "permit_pass"
      }
```

但 **`Kantele.World.Loader` 根本不读 `behavior` / `behavior_config`**，
`Kantele.World.Room` 结构里也没有这两个字段 —— 数据在加载时被静默丢弃。

| 区 | 房间 | guard_npc | 方向 |
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

> 注：`baituo:ximen` 的 valid_leave 里已有一条会执行的条件
> （`dir == 'west' && (int)me->query('combat_exp') < 600 && guarder`），
> 但它带 `guarder` 裸标识符 —— 求值器不支持裸变量，实际按 `guarder` 为假处理，
> 不会误拦。这条与 B 相关联，可一并处理。

### 做法

1. `Room` 结构加 `behavior` / `behavior_config`，`Loader.parse_room/4` 读进来
2. 在 `movement_request` 里按 `behavior_config.direction` 找到守门 NPC，
   调 `permit_module.permit_function(npc, mover, opts)`
3. `permit_pass/3` 需要的信息（家族、通行标记）目前只能从玩家 meta 拿，
   参照 `check_guarders/3` + `build_guarder_opts/3` 的做法

### 验收 / 风险

- 验收：线上 `goto baituo:damen`（门卫 me wei 守 north）应被盘查
- 风险：这是**新增拦截**，会影响所有经过这 16 个房间的玩家。必须先确认
  `Kantele.Npc.Guarder.permit_pass/3` 在真实 meta 下判定正确，否则会出现
  「守门 NPC 拦死所有人」。建议同样走「灰度开关 + 默认关」

---

## 四、C：三种自定义函数（18 条条件）

### 现状

| 函数 | 条数 | 场景 | 是否带副作用 |
|---|---:|---|---|
| `check_dirs(me, dir)` | 8 | 少林八卦阵（踩错卦序掉精 50、扣内力、改 `bagua/count`） | **是** |
| `check_out(me)` | 5 | 少林五行迷宫出口判定 | 是（计数器） |
| `ob->refuse(me)` | 5 | 城市擂台上擂主拒绝挑战 | 否（NPC 自身逻辑） |

这 18 条目前被 `LpcCondition.enforceable?/1` 判为不可执行，条件原文保留、不拦。

### 影响

- **八卦阵现在能走但没有陷阱**（P3a 已恢复 64 条出口，见已完成部分）
- 五行迷宫 5 个出口房间的出口判定缺失
- 擂台上「不是擂主不能上」类判定缺失

### 做法

- `ob->refuse(me)`：最简单。给 `ExitVetoContext` 的 resolver 加 `refuse` 方法，
  转到该 NPC 自身的进程里询问（需要一个跨进程查询通道，
  参考角色侧已有的事件/`Communication` 用法）
- `check_dirs` / `check_out`：需要给 veto 加**副作用通道**（现在 `check/2` 是纯判定）。
  建议单独设计一个「带副作用的 hook」入口：判定成立时把
  `receive_damage("jing",50)` / `add("neili",-50)` / `set_temp` / `delete_temp`
  作为事件发给移动者，而不是在房间进程里直接改 meta

### 风险

副作用通道是新的执行路径，容易出「扣了血但没拦住」或「拦住了但状态没改」这类
不一致。建议一次只接一个函数（从 `ob->refuse` 开始），验证后再做下一个。

---

## 五、D：玩家性别数据缺失（11 条条件）

### 现状

`me->query("gender")` 恒为 `nil`：

- `accounts` / `characters` 表**没有 gender 列**
- 登录流程不写 `meta.env`，所以 `query("gender")` 读不到

后果是这 11 条会**恒真或恒假**：

```
me->query('gender') != '男性'   ->  "" != "男性"  ->  恒真（会误拦）
me->query('gender') == '女性'   ->  恒假（放行）
```

涉及房间：`guiyun:huating`、`heimuya:tian1`、`luoyang:yuchi`、`mingjiao:mjtianmen1`、
`quanzhou:xijie`、`xiangyang:juyihuayuan`。

**已用 `LpcCondition.supported?/1` 挡下**（与「方向未限定」同一机制），
所以线上不会被误拦。

按判定顺序实际拦在 `supported?` 这道门的是 **9 条**；另有 2 条
（`changan:qunyulou`、`xiyu:xxh6`）因为也没限定方向，先一步被
`direction_scoped?` 拦下了 —— 补性别数据后它们仍需先补守卫才会生效。

### 需要决策

- **补数据**：加列 + 建号流程采集 + `meta.env["gender"]` 写入 + 11 条放行。
  代价：数据库迁移 + 前端表单，且老角色没有该数据（回填默认值？）
- **正式关闭**：承认这批条件永久不生效，文档记明

在决策之前，守卫保持关闭是安全的。

---

## 六、E：`xiangyang` 铁匠 inquiry 6 条（新功能）

### 现状

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

### 做法

`ask_me_N` 是该 NPC 内的函数（按图样判定材料/费用、扣除材料、给成品）。
还原需要：读 `d/xiangyang/*.c` 里 `ask_me_N` 的完整逻辑 → 为每个图样注册一个
行为 handler（材料检查 + 扣料 + 产出物品）→ 把 `inquiries` 的值改成 UCL 可表达的句柄
（如 `value = {kind = "smith", pattern = "huwan"}`）→ `ask` 命令侧按句柄分发。

**这是新功能，不是数据转换**，工作量与 A/B/C 同量级，建议独立排期。

---

## 七、F：`city:mudren` 的 `enter` —— 建议正式免除

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

### 建议

**正式免除**：把它当作「语料缺失的站外彩蛋」记录下来，不要实现传送门。
若将来引入 `world.c` 语料，再单独做门户支持。

对应的 valid_leave 条件 `dir == 'enter' && !userp(me)`（NPC 不许进）是会执行的，
保留即可。

---

## 八、G：更新计划文档

`docs/ucl-comment-implementation-plan.zh-CN.md` 的验收清单（§8）与执行顺序仍停在计划阶段，
与实际差很多：P0a / P0b / P0c / P1 / P2 / P3a / P3b / P3d 已完成，
且过程中发现了计划未预见的缺陷（见下）。**下一个人接手会被误导**，应更新。

建议把该文档改成「计划 + 实际结果对照」，本文件作为待做项入口。

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

`skipped` 注释：**299 → 7**（剩 F 的 1 条建议免除 + E 的 6 条）。

`vendor_goods` 注释：**清零**；`valid_leave` 生效：**133 / 166**。
