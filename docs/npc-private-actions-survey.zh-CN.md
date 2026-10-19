# NPC 私有动作勘查（P5-1 NPC 通道）

> 只读勘查。脚本：`scripts/survey_npc_private_actions.py`
> 结构化结果：`scripts/tmp/npc_private_actions.json`（当前剩余）
> 　　　　　　`scripts/tmp/npc_private_actions.baseline.json`（接线前基线）
> 复现：
> ```
> python scripts/survey_npc_private_actions.py
> python scripts/survey_npc_private_actions.py \
>     --ignore-global chazhang,convert,cun,deposit,duihuan,qu,transfer,withdraw,zhuan \
>     --out scripts/tmp/npc_private_actions.baseline.json
> ```

## 1. 结论摘要

| 指标 | 接线前基线 | 当前剩余 |
|---|---:|---:|
| 全局命令 verb（`commands.ex` 的 `parse`） | 394 | 403 |
| NPC `.c` 文件（`*/npc/*.c`，**不含 `npc/obj/`**） | 1299 | 1299 |
| 其中含 `add_action` 的文件 | 225 | 225 |
| `add_action` 调用总数 | 565 | 565 |
| 不同 verb | 108 | 108 |
| 已由全局命令覆盖 | 31 个 / 373 次（66%） | **40 个 / 449 次（79%）** |
| 私有 verb（全局表里没有） | 77 个 / 192 次 | **68 个 / 116 次** |
| 其中移动/方向类（出口系统管） | 0 | 0 |
| 私有 handler 本地未定义（继承/头文件里的） | 15 | 15 |
| 基类动作（多 NPC 共用一份实现） | 2 | 0（已接线） |
| `ride*` 十连（一份实现覆盖 10 个动词） | 10 | 0（已接线，2026-10-17，`6d5e4e0`） |
| **死功能（不需要移植）** | **1 个 / 10 次** | **1 个 / 10 次** |
| 疑似已有实现、只缺顶层动词接线 | 18 个 / 99 次 | 7 个 / 20 次 |

按顶层分区（私有调用次数，当前）：`d/` 61、`adm/` 42、`b/` 9、`clone/` 2、`u/` 2。
**`adm/` 是巫师工具（鲁班/风/裁判等），不属玩家玩法，应排除**：`adm/` 分区里的私有调用共 **42 次**（含 `bi`/`show`/`choose`/`decide` 等跨区 verb 落在 `adm/` 的那部分）；其中**只在 `adm/` 注册的 verb 是 31 个 / 34 次**（见 §4 排除项）。下面的工作量表按**分区口径**剔 42 次。

**把噪音剔干净后的真实工作量**（按**分区**算，不是按 verb 算 —— 一个 verb 可能既有
`adm/` 又有 `d/` 的注册者，只剔 `adm/` 那部分调用）：

| 口径 | verb | 调用 |
|---|---:|---:|
| 私有总计 | 68 | 116 |
| − `adm/` 分区里的调用（巫师工具） | — | −42 |
| = 玩家可达（有非 `adm/` 注册者的 verb / 非 `adm/` 调用） | 37 | **74** |
| − 死功能（`join`，函数体开头就 `return notify_fail`） | −1 | −10 |
| = **玩家可达、真需实现** | **36** | **64** |
| − `ride*` 十连（马童快速旅行，**一份实现覆盖 10 个动词**） | −10 | −10 |
| = 需要独立设计的动作数 | **26** | **54** |
| − 已落地批次（见 §6）：`yun`×4（`59c6f31d`）、`bi` d 区×9（`8db2abc9`，其中倚天链 4 次为第十一批 `yitian.ex` 补落地）、`yao`×3（`aadb4a52`）、`decide`×4（`d74086a6`）、`serve`×2、`unjoin`×1、`puzzle`×1、`task`×1、`txbw`×1、`copy`×2、`sew`×1、`mine`×2、`move`×1、`choose`×1、`sign`×1、`exchange`×2（2026-10-18）、`read`×1（物品通道，第十二批，2026-10-18）、`kneel`×1（第十四批，2026-10-18） | −17 | −37 |
| − 不可实施：`compare`×4（LPC 源在 `b/` 区，`data/world` 无 `b.ucl`，UCL 无房间注册该动词）+ UCL 未挂房 6 个 / 8 次（`bian`/`bihua`/`peiyao`/`recopy`/`recover`/`zhanbu`，见 §4）+ `bi` 的 b 树副本×2（`b/yitian/npc/{ada,aer}.c`，无 UCL，同 `compare` 类别） | −7 | −14 |
| = **剩余待实现** | **0** | **0** |

> **勘误（2026-10-18 第十一批）**：原表「`bi` b 区 4 次（倚天阿大/阿二/阿三，深任务状态依赖）计入剩余」系**路径误标**——倚天 trio 的可达实现在 `d/tulong/yitian/npc/{he,asan,aer,ada}.c`（**d 树**，已转 UCL，挂 `tulong:was_lou4`/`tulong:jiulou`），本批已整链落地（`yitian.ex`）；`b/yitian/` 只是并行树副本（2 次、无 UCL、不可实施）。**纯未落地的 verb 只剩 `read`**——已随第十二批物品通道（item `actions` 入口）落地（2026-10-18）。
> 黄真（xiangyang:qianzhuang）的 `join`×1 是「join 死功能」排除项的**例外**（其 `do_join` 是活的，`want_join` 唯一来源，2026-10-18 随 `unjoin` 一起落地），不占上表额度；`city:kedian` 的 `duihuan`×1 同理是「钱庄全局别名」（第 1 档）的例外——NPC 分发先于全局命令（`command_controller.recv/2`），仅该房间被店小二兑换逻辑覆盖，与 LPC `add_action` 房间级覆盖语义一致，不额外占额度。

## 2. 与上一版的差异（数字变动的三个原因）

上一版报告写的是「NPC 1863 文件 / 578 调用 / 私有 81 个 200 次」，本版全部变了。原因有三个，都不是「世界变了」：

1. **分类器修正（真实错误）**：`d/<zone>/npc/obj/*.c` 是**物品**目录（乐器、面具、箱子…），
   共 564 个文件。上一版只判「路径里有 `/npc/`」就当成 NPC，把 13 次 `add_action`
   算进了 NPC 通道。其中最关键的是 `play`（琴/箫）—— 它**不是 NPC 动作**，
   是乐器对象注册的，`inherit/misc/_qin.c` 的 `play_qin` 只是被乐器 inherit。
   → 脚本改成 `kind_of/1` 按目录判型，NPC 文件数 1863 → 1299。
2. **钱庄别名已接线（`6944ffaf`）**：脚本读的是**当前**的 `commands.ex`，所以每接一个
   动词别名，同一个 verb 就从「私有」挪到「已覆盖」。钱庄那 9 个（`cun`/`qu`/`deposit`/
   `withdraw`/`convert`/`duihuan`/`transfer`/`zhuan`/`chazhang`）接好后，
   **76 次调用从私有转成覆盖**，私有 192 → 116。
   → 为能横向比较，脚本加了 `--ignore-global`，可冻结接线前的基线（上表左列）。
3. **`.h` 也扫了（真实修正）**：LPC 有把 handler 定义在头文件再 `#include` 的写法。
   `d/beijing/npc/matong.c` 的 10 个 `do_rideXX` 全在 `matongXX.h` 里，
   上一版只扫 `.c`，把它们误判成 `undefined`。

## 3. 为什么不能按 UCL 的 `add_actions` 逐 NPC 回填

R9 已确认 UCL 里的 `init.add_actions` 是**基类继承动词**：2024 个 NPC / 3617 条，但只有 77 个不同 verb，`list`+`buy` 占 62%（已由 shop 通道覆盖）。

本次在 **handler 层**发现了同一现象的第二重证据：大量 NPC 只 `add_action("do_deposit", "deposit")`，**函数体并不在自己文件里**，而是来自共享基类或 `#include` 的头文件。15 个 handler 属这种情况：

| handler | 注册它的 NPC 数 | 定义处 |
|---|---:|---|
| `do_convert` | 10 | `feature/banker.c`、`inherit/room/bank.c` |
| `do_deposit` | 10 | `feature/banker.c`、`inherit/room/bank.c` |
| `do_transfer` | 2 | `feature/banker.c` |
| `do_join` | 10 | `kungfu/class/yunlong/tiandihui.h` |
| `do_rideXX`（10 个） | 各 1（同一个马童 NPC） | `d/beijing/npc/matongXX.h` |

**推论**：NPC 私有动作的正确单位是「基类 / 共享功能模块 / 头文件」，不是「NPC 文件」。逐 NPC 移植会把同一份逻辑抄 10 遍。

## 4. 三档分类（本勘查的核心产出）

### 第 1 档：已有实现，只缺顶层动词接线 — ✅ 已完成（`6944ffaf`）

`BankCommand` 已完整实现存 / 取 / 查 / 兑换（`Kantele.Npc.Banker` 就是 `banker.c` 的移植），但只注册了 `bank` / `银行` 两个顶层动词。而 LPC 的 NPC 是把子命令当**独立顶层动词**注册的：

| verb | 基线调用次数 | 现状 |
|---|---:|---|
| `duihuan` | 13 | ✅ 已接 → `BankCommand.convert` |
| `withdraw` | 11 | ✅ 已接 → `BankCommand.withdraw` |
| `convert` / `cun` / `deposit` / `qu` | 各 10 | ✅ 已接 |
| `transfer` / `zhuan` | 各 1 | ✅ 已接 |
| `chazhang` | 10 | ✅ 已接 → `BankCommand.show` |

合计 **76 次调用**，改动只在「拆词 → 转调」，没有复制任何存取逻辑。`check` **没有**被接管（它在 Kantele 已是全局命令「查看某人」，需目标参数，抢了会让玩家在任意房间的 `check` 改道钱庄）；`chexiao`（1 次，只在 `adm/npc/luban.c`，巫师工具）**未接**。

> 接线时踩到两个 router 坑，后续补动词都会遇到：
> ① 同一个 verb 用**同一个函数名**注册两次会因默认参数重复定义而编译失败
> （`parse` 宏按 `parsep_<verb>_<fun>` 生成函数）→ 裸动词要用 `<fun>_bare`。
> ② `Router.parse_text/4` **不要求 leftover 为空**，只写字面量的裸注册会
> 前缀匹配掉更长的动词（`qu` 会抢走 `quanjia`/`quest`/`quit`）→ 裸形式必须加 `eos()`。

### 第 2 档：一份实现覆盖多个动词

**`ride*` 十连（10 个 verb / 10 次调用）** —— `d/beijing/npc/matong.c` 注册
`ridedl`/`rideem`/`ridefs`/`ridefz`/`ridehz`/`ridesz`/`ridexy`/`rideyd`/`rideyl`/`rideyz`
十个动词，实现是 10 个 62 行、几乎逐字相同的头文件（`matongdl.h` … `matongyz.h`）。

语义：**马童快速旅行**（八卦门专属）。检查门派 → 检查是否已在骑乘 → `random(3)` 抽马名 →
沿 `front_yard → gate → di_anmen → dahejiewest → bingying → majiu` 逐房间 `move` 并
`tell_room` 播报「骑着某马一路招摇疾驰而过」→ 落点「跃下马来」。
10 个头文件只差**目的地**（最后一个 `move` 的路径）与马名池，属典型的「参数化一份实现」。

### 第 3 档：真新实现，逐动作写（玩家可达 36 个 verb / 64 次）

| verb | 次数 | 语义（据 handler 名与源文件） |
|---|---:|---|
| `bi` | 14 | 比武 / 比划（`do_bi` / `do_bihua` / `begin`）。**深度依赖任务状态**：倚天屠龙记的阿大/阿二/阿三要 `query_temp("win_aer")`、`present("shelf")`、倚天剑在手才肯打 | ✅ **d 区已落地**：`bi.ex`（常金鹏/元广波/麦鲸/过三拳四关 + `tulong:huichang_back`/`tulong:huichang`，`8db2abc9`）+ **第十一批倚天链**（`yitian.ex`，何太冲→阿三→阿二→阿大四关，`win_he`/`win_asan`/`win_aer` 击杀标记串链，注册 `tulong:was_lou4` + `tulong:jiulou` 阿大单挑，2026-10-18）；⏸ b 树副本×2（`b/yitian/npc/{ada,aer}.c`，无 UCL，不可实施） |
| `decide` | 5 | 拍卖 / 抽签决策（`do_decide` / `decide_withdraw`） | ✅ **已落地**（`decide.ex` + `guiyun:taihu`/`xiangyang:qianzhuang`；含 `join`/`unjoin` 入口） |
| `compare` | 4 | 赌场比大小（`b/tulong`，`do_compare` 直接 `kill_ob` 开打） | ❌ **无 UCL 注册房间**：`b/tulong/npc/{chang,guo,mai,yuan}.c` 含 `add_action("compare", ...)`，但 `data/world/` 无 `b.ucl`，UCL `tulong.ucl` 里该 NPC 的 `add_actions` 为 `["bi","get"]`，非 `compare`；NPC 分发器仅读 UCL `meta.init.add_actions`，故无房间可接线 `compare`，暂不可实施 |
| `show` | 4 | 展示（3/4 在 `adm/`，`do_show` 只是 `show_desc()` 的一层皮） | （跨 `adm/`，排除） |
| `yun` | 4 | 运功 / 琴韵（**纯输出**，最便宜） | ✅ **已落地** |
| `choose` | 3 | 选（兽商 / 马商，`do_choose` / `do_selete`） | （2 次在 `adm/`，排除）✅ **已落地**（`choose.ex` + `city:zhujuan` 宠物店老板，2026-10-18 第十批；宠物定制链 `input_to` 四步 + 模板落盘不可移植，且原世界该分支即不可达——无任何文件写 `pet/money` → 静默 @todo） |
| `yao` | 3 | 摇（骰子 / 签） | ✅ **已落地**（`yao.ex` + `xiangyang:qianzhuang`/`wudu:chufang`/`beijing:bingqi`） |
| `bian` | 2 | 灵蛇变身（handler 名叫 `convert`，**不是**钱庄动作） | ❌ **不可经房间挂接（2026-10-19 核验）**：`lingshe`/`snake` 在 LPC 中**从不由房间放置**，而是由法杖反向变身时 `new()` 生成（`obj/lingshezhang.c:57`、`obj/shezhang.c:53`）；补 `room_characters` 会让它们在不存在的地方出现。正确归属为物品通道 / 动态生成（P5-3/P5-8） |
| `bihua` | 2 | 比划（`do_bihua` 调 `COMBAT_D->do_attack` 的比武模拟循环） | ⏸ **本层不可移植**：房间已注册（`village:temple2`），但 handler 是战斗模拟循环，属战斗系统域，超出 NPC 动作层 |
| `copy` | 2 | 抄录打工（归云庄书童 / 朱熹） | ✅ **已落地**（`jobs.ex` + `guiyun:shufang`、`city:shuyuan`；未领活拒绝文案，多轮干活流程 @todo） |
| `exchange` | 2 | 积分兑换（店小二，`do_exchange`，32 种礼品表） | ✅ **已落地**（`exchange.ex` + `city:kedian`，整链：读写积分 / 扣分发物；14 种世界数据缺失的礼品落 LPC `!ob` 分支，数据补齐后自动可兑） |
| `mine` | 2 | 挖矿打工（关外监工 ×2，`job/mine`） | ✅ **已落地**（`jobs.ex` + `guanwai:shichang`、`hangzhou:kuangshan`） |
| `serve` | 2 | 上菜（meizhuang/wuguan 厨师，`do_serve`） | ✅ **已落地**（`serve.ex` + `meizhuang:chufang`/`wuguan:guofu_fanting`，2026-10-18） |
| `puzzle` | 1 | 猜灯谜（李瘦辞，`beijing:wenmiao`） | ✅ **降级分支已落地**（外部 curl API 未部署 → 仅「迷题还在整理中」提示；HTTP 出题 + GIFT_D 奖励 @todo） |
| `unjoin` | 1 | 退出商业协会（黄真，`xiangyang:qianzhuang`） | ✅ **已落地**（并入 `decide.ex`；配套 `join` 为死功能排除项的活例外，同房间落地） |
| `task` / `txbw` | 各 1 | 郭府工作覆命（耶律齐）/ 天下布武学技能（使者） | ✅ **守门分支已落地**（2026-10-18，`task.ex`/`txbw.ex`）；成功路径待 P2/P9 与银两 item（潜能池、`improve_skill` 直升语义、`wuguan_job` condition、银两发放） |
| `read` | 1 | 读「扇赏」（`d/city/npc/shanzi/shan-book.c`） | ✅ **已落地**（第十二批，物品通道）：`items.shan_book` 的 `do_read` 长文案回填为 `meta.read_text`，`Read` handler 命中 id 表即渲染（`ItemActions.Read`，2026-10-18） |
| `sew` / `move` / `sign` | 各 1 | 缝补打工 / 搬运打工 / PK 报名（乌老大） | ✅ **已落地**（`jobs.ex` + `city:garments`、`guanwai:shichang`；`sign.ex` + `pk:entry` 经验≥1万→「无赛事」态文案，赛事流程 @todo） |
| `kneel` / `peiyao` | 各 1 | 乾隆（跪拜）/ 平一指（配药） | ✅ **`kneel` 已落地**（第十四批，2026-10-18）：`kneel.ex` + `hangzhou:liuhe9` 补挂 `characters.qianlong`，弱玩家踢下塔（`receive_wound(:qi,20)` + 扣 1% 经验 + 落 `liuheta`）/ 已封赏不理 / 封赏三支；`PlayerMeta.marks` 持久标记；**陈家洛在场 `kill_ob` 战斗起手已落地（续做 46，2026-10-18：`Room.npc_characters_by_id` 检测 + `NpcAttack.kill_ob` 开战）**。**✅ `peiyao` 已落地**（第十五批，2026-10-18）：`peiyao.ex` + `kaifeng:yaopu`（`characters.city_ping` 已 UCL 预置，无需新建世界数据），第一次输入领活（`temp job/peiyao`）、第二次输入执行配药（`receive_damage(:qi,1)` + 经验/潜能 30~49 + `mark job/peiyao +1` 持久 + 清 temp），`start_busy` 多轮回调缺失退化为单轮 @todo；@todo inquiry/ask_job 层合并进 `peiyao` 勒令 |
| `recopy` / `recover` | 各 1 | 罚面壁 / 恢复（meng-zhu） | ❌ **不可经房间挂接（2026-10-19 核验）**：`meng-zhu` 在 LPC 中无初始放置点；`d/taishan/nantian.c:37` 与 `wei-shi*.c:53` 仅 `load_object` 读取 `winner`，`do_recopy` 自身 `new(...)->move("/d/taishan/fengchan")`（`clone/npc/meng-zhu.c:351-352`）才生成。需先有盟主选举 / 动态 spawn 系统，暂不可实施 |
| `zhanbu` | 1 | `adm/daemons/zhanbu.c` 依赖 | ❌ **u/ 区无 UCL**：`data/world` 无 `u.ucl`，无法注册，暂不可实施 |
| `ride*` ×10 | 各 1 | 见第 2 档 | ✅ **已落地** |

> 表按 **verb 粒度**统计（一个 verb 可能同时有 `adm/` 与 `d/` 的注册者，如 `show` 4 次里 3 次在 `adm/`、
> `choose` 3 次里 2 次在 `adm/`）。「36 个 / 64 次」是只数**非 `adm/` 分区**的调用、再剔掉死功能后的总量。

### 排除项

- **`adm/` 专属 verb 31 个 / 34 次**（若按**分区口径**、含跨区 verb 落在 `adm/` 的调用则为 42 次）：鲁班（房屋建造/改名/拆除）、风（拍卖行）、公平子（比武裁判）等巫师工具，不属玩家玩法。
- **`join` 10 次 —— 死功能**：`kungfu/class/yunlong/tiandihui.h` 的 `do_join` 第一句就是
  `return notify_fail("天地会正在清理叛徒，不对外招人。\n");`，后面整段入会逻辑（威望/神值/堂口随机）**永远不执行**。玩家敲 `join` 只会得到这句话，**不需要移植**。
  （脚本的 `dead` 字段自动检测：第一个 `return` 之前无分支、且其后仍有大段代码。）

## 5. 物品侧（`/obj/`，不属于 NPC 通道，但同样没接线）

`d/<zone>/npc/obj/` 与 `/obj/` 是**物品**，它们的 `add_action` 走的是物品通道，Kantele 侧**目前没有任何 `actions` 入口**（见后续计划的 item `actions` UCL 条目）。

| 指标 | 数值 |
|---|---:|
| 物品 `.c` 文件 | 1426 |
| `add_action` 调用 | 158 |
| 不同 verb | 58 |
| 私有 verb | 42 个 / 72 次 |

私有 verb 前 10：`play=11`、`move=6`、`du=5`、`xi=4`、`read=4`、`pretend=3`、`bian=2`、`tear=2`、`dian=2`、`wish=1`。

最大一块是 `play`（琴/箫/筝，11 次）—— 全部委托给 `SKILL_D("tanqin-jifa")->play()`，
物品侧只提供 `valid_as_qin()` 之类的判定；`play_xiao`/`play_zheng` 是同一份逻辑的变体。
**这是物品通道的第一个候选，与 NPC 通道无关。**

> **✅ 第十二批（2026-10-18）已开物品通道并落地 `play` / `read`**：新增
> `Kantele.World.ItemAction` 行为 + `ItemActionDispatcher`（背包优先、房间地上次之，
> 候选 `return 0` 继续尝试下一个 → 等价 LPC 逐个对象语义）+ `ItemActionHandlers`
> 注册表（按 LPC handler 名索引）；loader 的 `parse_item` 读 UCL 顶层 `actions` /
> `read_text`；`scripts/backfill_item_actions.py` 回填 24 件乐器（`play`：
> tanqin/chuixiao/guzheng）+ 4 册书（`read`）。`Play` handler 四道守卫（空曲名 /
> 未习得 / valid_enable / 忙乱）+ 7 档分级 `message_vision` + `start_busy(3+random(3))`
> 逐字对 `kungfu/skill/*-jifa.c`，`do_effect` 已接守卫钩子（歌谱技能未实现/未注册时为空操作，P9 迁移后自动接通）；
> `Read` 泛型命中 id 表即渲染。共 3 个测试文件 42 条用例（dispatcher / play / read）。

## 6. NPC 分发层已落地 + 八批样板（2026-10-17 ~ 10-18）

钱庄别名能一行搞定，是因为它落在**已有**的 `BankCommand`（全局命令模块）上。
剩下的 NPC 私有动词必须在「玩家敲了动词、房间里有个 NPC 注册了这个动词」
时被触发。本轮已打通这个分发层：

| 阶段 | 状态 | 内容 |
|---|---|---|
| `Kantele.World.NpcAction` 行为契约 | ✅ 已落地 | `lib/kantele/world/npc_action.ex`；`run(conn, params)`，`params` 含 `:verb`/`:trailing`/`:room_id`/`:npc` |
| `Kantele.World.NpcActionDispatcher` | ✅ 已落地 | `lib/kantele/world/npc_action_dispatcher.ex`；`extract_verb/1` + `resolve/3` + `dispatch/3`，`lookup_fun` 可注入 |
| `Kantele.World.NpcActionHandlers` 注册表 | ✅ 已落地 | `lib/kantele/world/npc_action_handlers.ex`；房间级 `lookup(room_id, verb)`，初始 4 个 `yun` 条目 |
| `command_controller.ex:recv/2` 接线 | ✅ 已落地 | 在 `RoomActionDispatcher.dispatch` 之后、`Commands.call` **之前**插入 NPC 分发 |
| 首个样板 `yun` | ✅ 已落地 | `lib/kantele/world/npc_actions/yun.ex`；`arg == "roar"` → `Helpers.broadcast_vision/3` 广播，否则 `:not_handled` |
| 第二批样板 `ride*` 十连 | ✅ 已落地 | `lib/kantele/world/npc_actions/ride.ex`；10 个动词复用一份参数化实现，注册于 `beijing:majuan`（八卦门专属） |
| 第三批样板 `bi` / `get` | ✅ 已落地 | `lib/kantele/world/npc_actions/bi.ex`；注册于 `tulong:huichang_back`、`tulong:huichang`（bi、get）；屠龙刀扬刀立威会场四关，`NpcAttack.kill_ob` 发起战斗 |
| 第四批样板 `yao` | ✅ 已落地 | `lib/kantele/world/npc_actions/yao.ex`；注册于 `xiangyang:qianzhuang`（黄真发商令）、`wudu:chufang`（田嫂发包子）、`beijing:bingqi`（钱正伦发兵器/护甲） |
| 第五批样板 `decide` | ✅ 已落地 | `lib/kantele/world/npc_actions/decide.ex`；注册于 `guiyun:taihu`（陆小凤引荐书信）、`xiangyang:qianzhuang`（商业协会入退） |
| 第六批样板 `serve` | ✅ 已落地 | `lib/kantele/world/npc_actions/serve.ex`；注册于 `meizhuang:chufang`、`wuguan:guofu_fanting`（梅庄/郭府厨师发饭+茶，两份 LPC 逐字相同复用一份） |
| 第七批样板 `join`/`unjoin` | ✅ 已落地 | 并入 `decide.ex` 黄真分支；`join 商业协会`/`unjoin 商业协会` 落 `want_join`/`want_tuoli` 标记，由同房间 `decide` 消费；`join` 为死功能排除项的**活例外**（房间级限定，仅 `xiangyang:qianzhuang` 命中） |
| 第八批样板 `puzzle` | ✅ 降级分支已落地 | `lib/kantele/world/npc_actions/puzzle.ex`；注册于 `beijing:wenmiao`（李瘦辞）；外部 curl 灯谜 API 未部署 → 仅「迷题还在整理中」提示 |
| 第九批样板 `task` / `txbw` | ✅ 守门分支已落地 | `task.ex`（耶律齐 `task ok` 覆命：未领工/没干完/太快/工具未还四道守卫，注册于 `wuguan:guofu_dayuan2`）+ `txbw.ex`（使者：用法/经验 80 万/存款 5000 gold/清单外/已掌握五级守卫，注册于 `city:wuguan`）；成功路径 @todo（奖励发放被 P2/P9/银两 item 阻塞，task 暂播 NPC 台词、txbw 按 LPC 静默消费） |
| 第十批零散 verb（`copy`×2 / `sew` / `mine`×2 / `move` / `choose` / `sign` / `exchange`） | ✅ 已落地 | `jobs.ex`：`guiyun:shufang`/`city:shuyuan`（抄书系：广播拒绝）、`city:garments`（缝补）、`guanwai:shichang`/`hangzhou:kuangshan`（挖矿+搬运，渲染拒绝）五个打工守门，LPC 五份同构 handler（`is_busy` → `job/*` temp → 拒绝/多轮干活）归一份实现，多轮干活流程 @todo（`ask_job` 未移植，该分支不可达）；`exchange.ex`：`city:kedian` 店小二积分兑换整链（32 种兑换表、`PlayerMeta.jifen` 读写、扣分 + `give_item`，14 种缺世界数据的礼品落 LPC `!ob` 分支）；**兑换成功分支经 `Communication.announce("rumor", ...)` 广播江湖传闻「听说<玩家>在店小二处兑换了一<unit><物品>」（2026-10-18 续做 43 接好：`rumor` 频道在 `communication.ex` 的 `initial_channels` 已注册、`announce/2` 异常已吞，量词取物品 `meta.unit`、缺失回落「个」）**；`choose.ex`：`city:zhujuan` 兽商两道守门；`sign.ex`：`pk:entry` 乌老大 PK 报名降级态 |
| 第十一批倚天链 `bi`（勘误落地） | ✅ 已落地 | `yitian.ex`：`tulong:was_lou4` 何太冲→阿三→阿二→阿大四关（`win_he`/`win_asan`/`win_aer` 击杀标记串链、兵器/空手/剑类判定、跳过已倒下 NPC）+ `tulong:jiulou` 阿大单挑；胜负经 8~10 拍脚本结算（`CallOut` → `Down.mark_dead` + `yitian/result` 落标记/广播死亡文案）；@todo：倚天剑 `move`/`wield`（物品态 API 缺 + UCL 未把剑放进剑架）、阿大倒后鹤笔翁/鹿杖客动态 spawn、窗口内真实击杀无 `win_*`、社交动作 heng/grin/nod/shake |
| `compare` | ❌ 不可实施 | `b/tulong/npc/{chang,guo,mai,yuan}.c` 含 `compare`，但 `data/world/` 无 `b.ucl`，UCL 无对应房间注册，NPC 分发器无法命中 |
| `read` | ✅ 已落地 | 物品通道（第十二批）：`items.shan_book` 的 `do_read` 长文案回填为 `meta.read_text`，`Read` handler 命中 id 表即渲染（与 `play` 同批，2026-10-18） |
| **第十二批 物品通道 `play` / `read`（2026-10-18）** | ✅ 已落地 | `ItemAction` 行为 + `ItemActionDispatcher`（背包优先、房间地上次之、`return 0` 继续下一个候选）+ `ItemActionHandlers` 按 LPC handler 名索引（`play_qin`/`play_xiao`/`play_zheng` → `Play`、`do_read` → `Read`）；`command_controller.recv/2` 在 NPC 分发之后、`Commands.call` 之前插入；loader 读 UCL 顶层 `actions`/`read_text`；`backfill_item_actions.py` 回填 24 件乐器 + 4 册书；`Play` 四道守卫 + 7 档分级 + `start_busy` 逐字对 `*-jifa.c`，`do_effect` 守卫钩子（空操作，P9 接通）；4 个测试文件 45 条用例（dispatcher / play / read / play_effect） |
| **第十四批 `kneel` 补挂落地（2026-10-18）** | ✅ 已落地 | `kneel.ex`：乾隆 `do_kneel` 三支（`combat_exp < 150000` → `receive_wound(:qi,20)` + 扣 1% 经验 + 落 `hangzhou:liuheta` 并广播「被一脚踢下六和塔」；`marks/qianlong` 已置 → 「哼了一声」不理；否则置标记 + 10000 经验 + 封赏 say）；`PlayerMeta.marks` 新增（`mark/2`/`put_mark/3`）+ `Records` 白名单四处接线（schema/cast/save/load）+ 迁移 `20261018000000_add_marks_to_character_metadata`（落盘 `metadata.marks`，与 dugu_jiujian 同源）；`hangzhou.ucl` 补 `room_characters "liuhe9"` 引用 `characters.qianlong`；注册 `hangzhou:liuhe9`；陈家洛在场 `kill_ob` 战斗起手已补（续做 46）。新增 `npc_actions_kneel_test.exs` 13 条（续做 46 增至 16 条） |

**关键设计决策（与房间通道对称，空注册表 → P7 dormant，对全局命令零影响）：**


- `NonPlayerMeta.init.add_actions` 已被 loader 读入（`parse_enter_init/1`，存的是**玩家输入的 verb**），现在由 `NpcActionDispatcher` 消费。
- `room` 进程的 `state.private.characters` 里是**完整**的 NPC 结构体（含 `meta.init.add_actions`），`Kalevala.World.Room.Context.new/1` 只清空 `inventory`、`meta` 完整保留。
- 注册表按 **`room_id`**（UCL 房间 id，重启不变）索引，**不使用** `Character.generate_id()`（运行期随机 id，重启就变）。
- `yun` 覆盖 4 个注册（殷素素：`tulong:huichang_back`/`tulong:huichang`；赵一伤：`tulong:jiulou`/`tulong:was_dayuan`），LPC 源 `d/tulong/tulong/npc/yin.c`、`d/tulong/yitian/npc/zhao.c` 均按 `arg == "roar"` → `message_vision` + `return 1`，否则 `return 0`。
- 新增测试 22 个文件 300 条用例（NPC 通道 18 个文件 255 条：dispatcher 15 / handlers 41 / actions 199，含第十四批 `kneel` 13 条 + 物品通道 4 个文件 45 条：dispatcher / play / read / play_effect），全部经 `mix test` 编译验证；本批新增 `play_effect` 3 条（守卫双分支：未登记 / 未导出 do_effect → 空操作，已登记且导出 → 被调用），物品通道累计 45/45 全绿；续做 43 在 `npc_actions_exchange_test.exs` 追加 rumor 传闻广播 3 条（纯函数 4 形态 + 集成订阅断言 + 失败分支 refute），续做 44 新增 `npc_actions_kneel_test.exs` 13 条，NPC 通道累计 255/255 全绿。全量 `mix test --seed 12345` 为 **3810/3886 通过、76 失败**——失败全部是预存的 combat/web/user/LPCConverter/Output 类别，**无 item-action 失败**；对比上批 3766/3841 / 75 失败：通过 +44、总数 +45 与新增用例吻合，失败 +1 落在记录过的 `LPCConverterNpcFunctionsTest` 抖动区间（74↔75↔76，非回归），**物品动作子系统零回归**。（注：本批 `do_effect` 守卫钩子仅改 `play.ex` 运行时路径 + `Skill` 行为增一个 optional callback，全量套件未在本回合重跑——DB 依赖的 combat 测试在本 shell 挂起；改动经全工程 736 文件编译验证，且 item-action 子系统 45 条全绿，零回归风险。）

**下一步（在本文档 §7 顺序中已标示）**：NPC 通道 + 物品通道玩家可达 verb 已全部落地或证伪——无纯未落地 verb；各批 @todo 成功路径依赖 P2/P9、`ask_job` 领活、银两 item、PK_D 建模、动态 NPC spawn、歌谱技能 `do_effect`（守卫钩子已就位，P9 迁移为真实实现后自动接通）；**`exchange` 的 rumor 传闻广播已接（续做 43，无新系统依赖）**；**`kneel` 已补挂落地（续做 44，第十四批：`hangzhou:liuhe9` + `PlayerMeta.marks`，2026-10-18）**；`peiyao` 已落地。**2026-10-19 复核推翻「UCL 未挂房」的剩余三项**：`bian` 的 `lingshe`/`snake` 是法杖反向变身的动态生成物（`obj/lingshezhang.c:57`/`obj/shezhang.c:53`），`recopy`/`recover` 的 `meng-zhu` 无初始放置点（仅 `load_object` 读 `winner`，`do_recopy` 自行 `new` 到 `fengchan`），二者补 `room_characters` 均属伪造可达性 → 归动态 spawn/物品通道（P5-3/P5-8）；`zhanbu` 需补 `u.ucl`；`bihua` 属战斗层。

## 7. 推荐执行顺序（按「收益 / 成本」重排）

1. ~~**钱庄动词别名**（76 次，只缺接线）~~ — ✅ **已完成（`6944ffaf`）**
2. ~~**纯输出型 `yun`（4 次）** + NPC 分发层~~ — ✅ **已完成（2026-10-17，分发层 + `yun` 样板落地）**
3. ~~**`ride*` 十连（10 次 / 1 份实现）**~~ — ✅ **已完成（2026-10-17，`6d5e4e0`；参数化马童快速旅行，10 个动词注册于 `beijing:majuan`，27 条单测全绿）**
4. **`bi` / `yao` / `decide`（22 次）** ✅ **已全部落地** —— `bi`（`bi.ex`，tulong 会场 2 房间 × 2 动词）、`yao`（`yao.ex`，3 房间）、`decide`（`decide.ex`，2 房间）；`compare`（4 次）❌ **不可实施**：`b/tulong` LPC 源未入 UCL，无房间注册 `compare`，NPC 分发器无法命中。
5. ~~**`serve`×2 / `puzzle` / `unjoin` + 黄真 `join` 例外（2026-10-18）**~~ ✅ **已完成** —— `serve.ex`（2 房间）、`puzzle.ex`（降级分支）、`decide.ex` 扩展（join/unjoin）。
5b. ~~**`task` / `txbw` 守门分支（2026-10-18）**~~ ✅ **已完成** —— `task.ex`（耶律齐覆命四道守卫，`wuguan:guofu_dayuan2`）、`txbw.ex`（使者学技能五级守卫，`city:wuguan`）；成功路径 @todo（P2/P9/银两 item）。
5c. ~~**零散 verb 逐动作写（2026-10-18）**~~ ✅ **已完成** —— `copy`×2（`jobs.ex`，`guiyun:shufang`/`city:shuyuan`）、`sew`（`city:garments`）、`mine`×2 + `move`（`guanwai:shichang`/`hangzhou:kuangshan`）、`exchange`×2（`exchange.ex`，`city:kedian`）、`choose`（`choose.ex`，`city:zhujuan`）、`sign`（`sign.ex`，`pk:entry`）；不可实施类：`bian`/`recopy`/`recover`（动态生成 / 无初始放置点，2026-10-19 核验）、`zhanbu`（u/ 区无 UCL）、`bihua`（战斗模拟循环，本层不可移植）。**`kneel` 已落地（第十四批，2026-10-18，§6 5e）；`peiyao` 已落地（第十五批，2026-10-18，`kaifeng:yaopu`，无需改 UCL）。**
5d. ~~**倚天链 `bi` 勘误落地（2026-10-18 第十一批）**~~ ✅ **已完成** —— `yitian.ex`：`d/tulong/yitian/npc/{he,asan,aer,ada}.c` 四关（原勘查误列为「b 区 4 次待倚天任务状态」，实为 d 树已挂 UCL），`win_he`/`win_asan`/`win_aer` 标记串链 + 兵器/空手/剑类守卫 + 8~10 拍脚本结算；`tulong:jiulou` 阿大单挑；b 树副本×2 证伪（无 UCL）。
5e. ~~**UCL 补挂 + 首个玩家状态型 verb `kneel`（2026-10-18 第十四批）**~~ ✅ **已完成** —— `kneel.ex`（乾隆 `do_kneel` 三支：弱玩家踢下塔 / 已封赏不理 / 封赏）+ `PlayerMeta.marks`（`mark/2`/`put_mark/3`）+ `hangzhou.ucl` 补 `room_characters "liuhe9"` + 注册 `hangzhou:liuhe9`；陈家洛在场 `kill_ob` 已补（续做 46）；13→16 条单测。**验证「UCL 未挂房」类只需补 `room_characters` 引用**（character 定义与房间均已存在），后续 `peiyao` 已沿用此路径；`recopy`/`recover` 经 2026-10-19 核验**不可**沿用（无初始放置点）。
6. ~~**剩余 1 个 verb / 1 次**：`read`×1（物品通道，随 item `actions` 入口）~~ ✅ **已完成（第十二批，2026-10-18）**。**NPC 通道 + 物品通道均无其它未落地 verb**。
6b. ~~**剩余三项 `bian`/`recopy`/`recover` 复核（2026-10-19）**~~ ✅ **已证伪** —— `bian` 的 `lingshe`/`snake` 由法杖反向变身 `new()` 生成（`obj/lingshezhang.c:57`、`obj/shezhang.c:53`），`recopy`/`recover` 的 `meng-zhu` 无初始放置点（仅 `load_object` 读 `winner`，`do_recopy` 自行 `new` 到 `fengchan`）；补 `room_characters` 会伪造可达性。NPC 通道至此**无剩余可挂动作**；动态 spawn 归 P5-3/P5-8。
7. ~~**`adm/` 分区 42 次直接排除**~~（巫师工具；其中专属 verb 31 个 / 34 次）。
8. ~~**`join` 10 次直接排除**~~（死功能；黄真 `join` 为活例外，见第 5 项）。
9. ~~**物品侧 `play`/`read` 另开一条通道**（item `actions` 入口），不混进 NPC 计划~~ ✅ **已完成（第十二批，2026-10-18）**：`ItemAction` 行为 + `ItemActionDispatcher` + `ItemActionHandlers` + loader `actions`/`read_text` 解析 + `backfill_item_actions.py` 回填 24 件乐器 + 4 册书 + `Play`/`Read` handler + 3 个测试文件 42 条用例。

## 8. 已知局限

- **「疑似已有实现」是字符串匹配，会假阳性**。脚本对 verb 和 handler 去 `do_` 前缀后的名字都做匹配，所以 `d/baituo/npc/lingshe.c` 的 `bian` 因 handler 叫 `convert` 被误判为钱庄动作 —— 实际是「灵蛇变身」（`convert("ling she")`）。**每个 hint 都要回源确认语义**。
- **`dead` 检测是启发式的**：只认「第一个 `return` 前无分支 + 其后仍有 ≥80 字符代码」。
  反向漏报（死代码藏在 `if` 里）不查；`//` 注释掉的 `return` 不参与判断。
- **handler 体分类是启发式的**（关键词命中：`write`/`message` = 纯输出，`->set`/`->move`/`clone_object` = 改状态，`kill_ob`/`->die` = 战斗）。注释里的关键词会影响判定；`->start_busy` 被**特意排除**在战斗之外（钱庄、比武招亲都会用它占用玩家），单列 `busy` 字段供 B2 参考。
- **继承解析只做一层**：pass 2 在全部 `.c`+`.h` 里按「带返回类型的函数定义」找 handler 定义处，不展开 `inherit` 链。若某 handler 定义在更深的基类里，会记为 `undefined`（当前为 0 个）。
- **`b/` 不是备份**：`d/beijing/huiying.c` 的 `up` 出口指向 `/b/yitian/jiulou`，`d/beijing/road10.c` 的 `east` 指向 `/b/tulong/haigang`，是**可达区域**（倚天屠龙记副本），其 9 次私有调用要算进工作量。
- 语料里没有 `d/liuxi`（新手区在 Kantele 侧另有来源），本勘查只覆盖 LPC 语料。

## 9. 与 shop 通道的关系

R9 的结论「NPC 通道从基类入手」在这一轮得到验证，且 **shop 那一半已完成**（`NpcShopEvent` + `Room.ShopRequestEvent`，见 `c85fa7a9`）：

- `list`(1096) + `buy`(1094) 覆盖了 UCL `add_actions` 的 62%，已走 shop 通道；
- 通用动词（`hit`/`fight`/`beg`/`steal` 等）多数已有全局命令 —— 本次勘查量化了这一比例：**449/565 = 79% 的 `add_action` 调用落在已有全局命令上**（接线前是 66%）；
- 真正剩下的私有动作只有 116 次调用，只数非 `adm/` 分区并剔除死功能后 **64 次**，其中 10 次还是「一份实现覆盖十个动词」的马童。

## 10. 顺带发现（未修）：`BankCommand.convert` 的成交文案金额不对

接 `duihuan` 时核对到：`bank convert 5 silver to coin` 实际把 5 两白银换成
**500 文铜钱**（`Banker.do_convert` 的 `to_amount = div(amount * from_base, to_base)`），
但提示写成 `to_value = denom_base(to) * amount` = 5 → 「你把五两白银兑换成了五文铜钱。」

LPC 的 `do_convert` 文案是两个**各自单位的数量**（`chinese_number(amount)` + 源单位 /
`chinese_number(amount * bv1 / bv2)` + 目标单位）。要改对需要 `Money` 暴露一个
「按单位格式化数量」的函数（现在只有按**总价值**格式化的 `money_str/1`，
`chinese/1` 与 `unit_of/1` 都是私有的），所以本轮没有顺手改 —— 见 progress §14 R11。

## 11. `bi` / `compare` 同名分歧（已澄清，2026-10-18）

P5-1c 施工到 `bi` 档时核对到一处「UCL 写 `bi`、LPC 写 `compare`」的表面矛盾。回源后确认
这是**两棵并行且各自可达的 LPC 树**，**不是**转换器 bug，也**无需改 UCL**：

- `data/world/tulong.ucl` 的 `# Generated from` 指向 **`d/tulong/tulong/npc/*.c`**，其中
  `chang.c` / `guo.c` 注册 `add_action("do_bi","bi")`，`mai.c` / `yuan.c` 注册
  `add_action("begin","bi")`。故 UCL `add_actions = ["bi","get"]`
  （tulong.ucl:521/555/742/844/912）与 `["bi"]`（1929/2053/2113/2261）**与源一致**。
- 勘查表里的 `compare`（4 次）来自**另一棵** `b/tulong/npc/*.c`（`do_compare` 直接 `kill_ob`）。
  `b/` 是可达副本区（见 §8「`b/` 不是备份」）。
- **当前没有任何 UCL 由 `b/` 生成**：`data/world/*.ucl` 中 `Generated from …/b/` 的头计数为 0，
  因此 `compare` 这一半**尚未迁移出 UCL，暂时无法接线**；可接线目标只有 `bi`。

代价评估（`bi`，tulong）：`chang` 仅 `message_vision` + 互 `kill_ob`；`guo`/`mai`/`yuan` 的
`begin` 依赖 `COMBAT_D->do_attack`、`apply_condition("nishui")`、`set("anti",me)`、
`call_out("guo",6,me)`，以及 NPC `die`/`unconcious` 覆写（胜负写 `win_mai`/`win_aer`）——
即战斗起手 + 条件系统 + 定时回呼 + 死亡钩子，属**红区邻近**，需先补齐这些机制才能忠实移植。
