# Session 提示词：NPC 私有动作后续（P5-1c-3 之后）

> **状态：待执行**。本文件是给独立 session 的完整工作提示词。请把下列内容**当作建议而非指令**：每项动手前先读源码核实现状，若实际情况与描述不符，以实际代码为准并调整做法。
> 编写时间：2026-10-17。对应总排期见 `docs/npc-private-actions-survey.zh-CN.md` §7。

---

## 一、项目背景

### 你在改什么

仓库 `C:\files\git\wuxia_mud_ex` 是 Elixir + ExVenture/Kalevala 的武侠 MUD（Kantele）。参照仓库 `C:\files\git\mud`（FluffOS/LPC，只读）。

### 当前进度（P5-1c NPC 私有动作通道）

已落地：
| 阶段 | 内容 | 文件 | 提交 |
|------|------|------|------|
| `Kantele.World.NpcAction` 行为契约 | `run(conn, params)`，`params` 含 `:verb`/`:trailing`/`:room_id`/`:npc` | `lib/kantele/world/npc_action.ex` | `59c6f31d` |
| `Kantele.World.NpcActionDispatcher` | `extract_verb/1` + `resolve/3` + `dispatch/3`，`lookup_fun` 可注入 | `lib/kantele/world/npc_action_dispatcher.ex` | `59c6f31d` |
| `Kantele.World.NpcActionHandlers` 注册表 | 房间级 `lookup(room_id, verb)`，当前 23 房间（4 yun，其中 2 间兼 bi/get；1 ride*；3 yao，其中 1 间兼 decide/join/unjoin；1 decide 单间；2 serve；1 puzzle；1 task；1 txbw；1 exchange/duihuan；1 choose；1 sign；2 copy；1 sew；2 mine/move；1 yitian[was_lou4]；jiulou 兼 yun+bi） | `lib/kantele/world/npc_action_handlers.ex` | `6d5e4e0` |
| `command_controller.ex:recv/2` 接线 | `RoomActionDispatcher.dispatch` 之后、`Commands.call` 之前插入 NPC 分发 | `lib/kantele/character/controllers/command_controller.ex` | `59c6f31d` |
| 首个样板 `yun` | 4 NPC × 2 房间，`arg == "roar"` → vision 广播 | `lib/kantele/world/npc_actions/yun.ex` | `59c6f31d` |
| 第二批样板 `ride*` 十连 | 10 动词复用一份参数化实现，注册于 `beijing:majuan`（八卦门专属） | `lib/kantele/world/npc_actions/ride.ex` | `6d5e4e0` |
| `yao` 三连（要物） | 黄真/田嫂/钱正伦发物，Counter 共享上限 | `lib/kantele/world/npc_actions/{yao,helpers,counters}.ex` | `aadb4a52` |
| `decide` 二连（引荐/商业协会） | 陆小凤/黄真，helper `delete_temp/put_env/take_item/respect` | `lib/kantele/world/npc_actions/decide.ex` | `d74086a6` |
| `bi`（屠龙闯关，full） | 常/元/麦/过四关，condition nishui/duyan + 过三拳三连击，倒下处决 + respawn | `lib/kantele/world/npc_actions/{bi,npc_attack,down,down_handlers}.ex` + `character/bi_event.ex` | `8db2abc9` |
| `serve` 二连（要吃的） | 梅庄/郭府厨师发饭+茶，两份 LPC 逐字相同复用 | `lib/kantele/world/npc_actions/serve.ex`（meizhuang:chufang / wuguan:guofu_fanting） | 2026-10-18 |
| `puzzle` 单连（猜灯谜） | 李瘦辞；外部 curl API 未部署 → 仅降级提示 | `lib/kantele/world/npc_actions/puzzle.ex`（beijing:wenmiao） | 2026-10-18 |
| `join`/`unjoin` 二连 | 黄真商业协会入/退入口标记，`decide` 消费 | `decide.ex` 扩展（xiangyang:qianzhuang；`join` 为死功能排除项的活例外） | 2026-10-18 |
| `task` 单连（覆命） | 耶律齐 `task ok` 四道守门守卫 | `lib/kantele/world/npc_actions/task.ex`（wuguan:guofu_dayuan2） | 2026-10-18 |
| `txbw` 单连（学技能） | 天下布武使者五级守卫（用法/经验/存款/清单/已掌握） | `lib/kantele/world/npc_actions/txbw.ex`（city:wuguan） | 2026-10-18 |
| `jobs` 守门族（`copy`×2 / `sew` / `mine`×2 / `move`） | 归云庄书童/朱熹抄书、曾柔缝补、关外监工挖矿搬运，五份同构 handler 一份实现 | `lib/kantele/world/npc_actions/jobs.ex`（guiyun:shufang / city:shuyuan / city:garments / guanwai:shichang / hangzhou:kuangshan） | 2026-10-18 |
| `exchange`/`duihuan` 二连（积分兑换） | 店小二 32 种礼品表、扣分 + 发物整链；14 种缺数据的礼品落 `!ob` 分支 | `lib/kantele/world/npc_actions/exchange.ex`（city:kedian） | 2026-10-18 |
| `choose` 单连（选宠物） | 宠物店老板：驭兽术 < 30 / 未付钱报价；定制链不可移植（原世界即不可达） | `lib/kantele/world/npc_actions/choose.ex`（city:zhujuan） | 2026-10-18 |
| `sign` 单连（PK 报名） | 乌老大：打招呼广播 + 经验 < 1 万拒绝；PK_D 未建模 → 无赛事态文案 | `lib/kantele/world/npc_actions/sign.ex`（pk:entry） | 2026-10-18 |
| `yitian` 倚天链（`bi`，何太冲→阿三→阿二→阿大） | `win_he`/`win_asan`/`win_aer` 标记串链 + 兵器/空手/剑类守卫 + 8~10 拍脚本结算；jiulou 阿大单挑 | `lib/kantele/world/npc_actions/yitian.ex` + `lib/kantele/character/yitian_event.ex`（tulong:was_lou4 / tulong:jiulou） | 2026-10-18 |
| `ItemAction` 物品通道（play / read） | `Item` 行为 + `ItemActionDispatcher`（背包优先、房间地上次之、`return 0` 继续下一个候选）+ `ItemActionHandlers`（按 LPC handler 名索引 `play_qin`/`play_xiao`/`play_zheng`→`Play`、`do_read`→`Read`）；loader 读 UCL 顶层 `actions`/`read_text`；`backfill_item_actions.py` 回填 24 件乐器 + 4 册书；`Play` 四道守卫（空曲名 / 未习得 / valid_enable / 忙乱）+ 7 档分级 `message_vision` + `start_busy(3+random(3))` 逐字对 `*-jifa.c`，`do_effect` 守卫钩子（未实现/未注册时为空操作，P9 迁移后自动接通）；`Read` 泛型命中 id 表即渲染 | `lib/kantele/world/{item_action,item_action_dispatcher,item_action_handlers}.ex` + `lib/kantele/world/item_actions/{play,read}.ex` + `lib/kantele/world/item.ex` + `lib/kantele/world/loader.ex` + `command_controller.ex` 接线 + `scripts/backfill_item_actions.py` | 2026-10-18 第十二批 |

测试：NPC 私有动作 + 注册表 **255/255 全通过**（`npc_actions_*_test.exs` + `npc_action_handlers_test.exs`，含 `peiyao` 12 条、`kneel` 16 条）；物品通道 **45/45 全通过**（dispatcher / play / read / play_effect）。全量 `mix test` 失败集不应扩大（**确定性失败基线 0**，共 3922 条用例；另有 0–4 条 `DBConnection` 沙箱池 `owner exited` 抖动，随 run 变化，不计入基线。清理历程：73 → 43（续做 48）→ 28（续做 49）→ 1（续做 50：bcrypt NIF 构建成功 26 条 + ecto preload 2 条）→ **0**（续做 51：perform 冒烟测试选择器修正 1 条）），零 NPC/物品动作回归。

### 必读文档

1. `docs/npc-private-actions-survey.zh-CN.md`——**核心文档**，§1 勘查数字、§6 分发层状态、§7 推荐执行顺序、§4 三档分类
2. `docs/kantele-remaining-work.zh-CN.md`——Kantele 总体待办，第〇节高危纪律、第八节八阶段排期
3. `docs/migration-prep-checklist.zh-CN.md`——第四节：属性/成长差异对照（`bi` 涉及任务状态）

### 关键架构事实

- **NPC 私有动作分发**：玩家敲动词 → `NpcActionDispatcher.dispatch/3` 找房间内第一个 `meta.init.add_actions` 含该动词的 NPC → `NpcActionHandlers.lookup/2` 按 `room_id`（UCL 房间 id，重启不变）解析 `{module, function}` → 执行 `run/2`。返回 `conn` 表示拦截（已处理），返回 `:not_handled` 放行全局命令。
- **注册表按 `room_id` 索引**，不使用 `Character.generate_id()`（重启后会变动）。同一房间多个 NPC 注册同一动词，取第一个命中者。
- **空注册表 → P7 dormant，对全局命令零行为影响**。仅当 handler 被真正移植并注册后，对应 NPC 动作才被激活。
- **`params` 字段**：`:verb`（玩家输入动词）、`:trailing`（剩余文本，对应 LPC `arg`）、`:room_id`（`conn.character.room_id`）、`:npc`（触发 NPC 的 `%Kalevala.Character{}`）。

### 铁律

- UTF-8 无 BOM、LF 行尾、末行留换行；Elixir 四空格缩进
- 游戏文本简体中文，风格对齐现有输出
- 每完成一项：`MIX_ENV=test mix test test/kantele/world/npc_action*` 全绿再做下一项；全量 `MIX_ENV=test mix test` 失败集不应扩大（**确定性失败基线 0**，共 3922 条；另有 0–4 条 `DBConnection` 池抖动不计入。73 → 43 见续做 48，43 → 28 见续做 49，28 → 1 见续做 50，1 → 0 见续做 51，`Map.keys` 抖动见续做 47）
- **不要碰红区/深水区**：eff_* 层、diff-stop、昏迷/毒、Skill behaviour 协议——留待 f 期
- 不执行 git commit，除非明确要求

---

## 二、后续执行顺序（按 `docs/npc-private-actions-survey.zh-CN.md` §7）

```
1. ~~钱庄动词别名~~ — ✅ 已完成（6944ffaf）
2. ~~纯输出型 yun + NPC 分发层~~ — ✅ 已完成（59c6f31d）
3. ~~ride* 十连~~ — ✅ 已完成（6d5e4e0）
4. ~~bi / compare / yao / decide（26 次）—— 比武、赌场、拍卖，有状态与随机性~~
   - `yao` ✅ 已完成（`aadb4a52`），`decide` ✅ 已完成（`d74086a6`），`bi` ✅ 已完成（`8db2abc9`，d 区；b 区倚天 4 次待任务状态）
   - `compare`：**不在 UCL**（来自并行 `b/` 树的 tulong NPC，无 room_id 可注册，视为不可移植，记 `@todo` 后搁置）
5. ~~serve×2 / puzzle / unjoin + 黄真 join 例外~~ — ✅ 已完成（2026-10-18）
   - `serve`：`serve.ex`，meizhuang:chufang + wuguan:guofu_fanting（发饭+茶）
   - `puzzle`：`puzzle.ex`，beijing:wenmiao；外部 curl API 未部署 → 仅降级提示
   - `join`/`unjoin`：并入 `decide.ex` 黄真分支（room_id: xiangyang:qianzhuang）；`join` 是死功能排除项的活例外
5b. ~~task / txbw 守门分支~~ — ✅ 已完成（2026-10-18）
   - `task`：`task.ex`，wuguan:guofu_dayuan2（耶律齐 `task ok` 覆命：未领工/没干完/太快/工具未还四道守卫；`arg != "ok"` → `:not_handled` 放行全局）
   - `txbw`：`txbw.ex`，city:wuguan（使者：用法/经验 80 万/存款 5000 gold/清单外/已掌握五级守卫，LPC 判定顺序原样保留）
   - 成功路径仍 @todo（P2/P9/银两 item；task 暂播「干得不错」台词不发奖，txbw 按 LPC 静默消费）
5c. ~~零散 verb 逐动作写~~ — ✅ 已完成（2026-10-18 第十批）
   - `copy`×2：`jobs.ex`，guiyun:shufang（书童）、city:shuyuan（朱熹）；`sew`：city:garments（曾柔）；`mine`×2 + `move`：guanwai:shichang、hangzhou:kuangshan（监工）——五份同构打工守门归一份实现
   - `exchange`：`exchange.ex`，city:kedian（店小二积分兑换整链）；`choose`：`choose.ex`，city:zhujuan（宠物店老板）；`sign`：`sign.ex`，pk:entry（乌老大 PK 报名降级态）
   - ❌ **待 UCL 补挂（已核实）**：`bian`（白驼山灵蛇/毒蛇）、`recopy`/`recover`（meng-zhu）——NPC 在 UCL 有定义但无 `room_characters` 引用，分发器读不到（**`kneel` 乾隆已在第十四批补挂落地**，**`peiyao` 平一指已在第十五批落地于 `kaifeng:yaopu`，无需改 UCL**，见 §七）；`zhanbu`——u/ 区无 `u.ucl`；`bihua`——`village:temple2` 已注册但 handler 是 `COMBAT_D->do_attack` 战斗模拟循环，超出 NPC 动作层
5d. ~~倚天链 `bi`（原「b 区 4 次」勘误）~~ — ✅ 已完成（2026-10-18 第十一批）
   - `yitian.ex`：tulong:was_lou4 何太冲→阿三→阿二→阿大四关 + tulong:jiulou 阿大单挑；`win_he`/`win_asan`/`win_aer` 击杀标记串链
   - b 树副本×2（`b/yitian/npc/{ada,aer}.c`）证伪：无 UCL，同 compare 类别不可实施
6. ~~剩余仅 `read`×1（物品通道，`items.shan_book`，随 item `actions` 入口做）~~ ✅ **已完成（第十二批，2026-10-18）**——NPC 通道 + 物品通道均无其它未落地 verb
7. adm/ 分区 42 次直接排除（巫师工具；专属 verb 31 个 / 34 次）
8. join 10 次直接排除（死功能；黄真 `join` 为活例外，已随第 5 项落地）
9. ~~物品侧 play / read 另开一条通道（item `actions` 入口）~~ ✅ **已完成（第十二批，2026-10-18）**：`ItemAction` 行为 + `ItemActionDispatcher` + `ItemActionHandlers` + loader `actions`/`read_text` 解析 + `backfill_item_actions.py` 回填 24 件乐器 + 4 册书 + `Play`/`Read` handler + 4 个测试文件 45 条用例（dispatcher / play / read / play_effect）
```

### 第 4 档：bi / compare / yao / decide（真新实现，逐动作写）

| verb | 次数 | 语义 |
|------|------|------|
| `bi` | 14 | 比武 / 比划（`do_bi` / `do_bihua` / `begin`）。**深度依赖任务状态**：倚天屠龙记的阿大/阿二/阿三要 `query_temp("win_aer")`、`present("shelf")`、倚天剑在手才肯打 | ✅ `d/tulong/tulong/npc/{chang,guo,mai,yuan}.c` 已完整移植（`8db2abc9`）|
| `compare` | 4 | 赌场比大小（`b/tulong`，`do_compare` 直接 `kill_ob` 开打） |
| `yao` | 3 | 摇（骰子 / 签） |
| `decide` | 5 | 拍卖 / 抽签决策（`do_decide` / `decide_withdraw`） |

**建议执行顺序**：`yao`（最简单，纯随机输出）→ `decide`（拍卖/抽签，有状态但范围小）→ `compare`（赌场，直接开战）→ `bi`（最贵，任务状态依赖深，最后做）。

每个动作的通用步骤：
1. 回源 LPC 源文件（`d/*/npc/*.c` + 对应 `.h`），确认 `do_*` 函数体语义、守门条件、返回值（`return 0` 放行 / `return 1` 拦截）
2. 新建 `lib/kantele/world/npc_actions/<verb>.ex`，`use Kantele.World.NpcAction`，实现 `run/2`
3. 在 `NpcActionHandlers.@registry` 按 `room_id` 注册该 verb → `{Kantele.World.NpcActions.<Verb>, :run}`
4. 新建 `test/kantele/world/npc_actions_<verb>_test.exs`，覆盖：守门分支 / 成功路径 / `:not_handled` 放行 / 防御性（nil room_id 等）
5. `MIX_ENV=test mix test test/kantele/world/npc_action*` 全绿

---

## 三、环境与运行命令

```powershell
# PowerShell（Windows）
$env:PATH = "C:\Program Files\Erlang OTP\bin;C:\Program Files\Elixir\bin;" + $env:PATH
cd C:\files\git\wuxia_mud_ex
$env:MIX_ENV = "test"
mix test test/kantele/world/npc_action*
mix test --seed 12345
```

```bash
# Git Bash / bash
export PATH="/c/Program Files/Erlang OTP/bin:/c/Program Files/Elixir/bin:$PATH"
cd C:/files/git/wuxia_mud_ex
MIX_ENV=test mix test test/kantele/world/npc_action*
MIX_ENV=test mix test --seed 12345
```

- Erlang/OTP 29 + Elixir 1.20.4（`C:\Program Files\Erlang OTP\`、`C:\Program Files\Elixir\`）
- PostgreSQL 12 在 Docker 容器 `wuxia_mud_dev-db-1`，端口 `localhost:15432`，测试库 `ex_venture_test` 已建并迁移
- `config/test.exs` 已临时指向 `localhost:15432`

---

## 四、已知的已完成项（本 session 不应重复做）

- `yun` 样板：`lib/kantele/world/npc_actions/yun.ex` + 测试 `test/kantele/world/npc_actions_yun_test.exs`
- `ride*` 十连：`lib/kantele/world/npc_actions/ride.ex` + 测试 `test/kantele/world/npc_actions_ride_test.exs`
- `yao`/`decide`/`bi`/counters：`lib/kantele/world/npc_actions/{yao,decide,bi,counters}.ex` + 对应测试文件
- `serve`/`puzzle`：`lib/kantele/world/npc_actions/{serve,puzzle}.ex` + 测试（2026-10-18）
- `task`/`txbw` 守门分支：`lib/kantele/world/npc_actions/{task,txbw}.ex` + 测试（2026-10-18；成功路径 @todo）
- `jobs`/`exchange`/`choose`/`sign` 第十批：`lib/kantele/world/npc_actions/{jobs,exchange,choose,sign}.ex` + 测试（2026-10-18）
- `yitian` 第十一批（倚天链）：`lib/kantele/world/npc_actions/yitian.ex` + `lib/kantele/character/yitian_event.ex` + 测试（2026-10-18）
- **第十四批 `kneel`（续做 44）**：`lib/kantele/world/npc_actions/kneel.ex`、`lib/kantele/character.ex`（`PlayerMeta.marks` + `mark/2`/`put_mark/3`）、`data/world/hangzhou.ucl`（`room_characters "liuhe9"` 引用 `characters.qianlong`）、`npc_action_handlers.ex`（`hangzhou:liuhe9`）+ 测试 `npc_actions_kneel_test.exs`（13）（2026-10-18；陈家洛 `kill_ob` 续做 46 补落地）
- **第十五批 `peiyao`（续做 45）**：`lib/kantele/world/npc_actions/peiyao.ex`（平一指配药）；世界数据已就绪**无需改 UCL**（`clone_lib.ucl` `characters "city_ping"` 已带 `add_actions = ["peiyao", ...]`，`kaifeng.ucl` `room_characters "yaopu"` 经 clone_lib 回退引用 `characters.city_ping.id`）；`npc_action_handlers.ex`（`kaifeng:yaopu`）+ 测试 `npc_actions_peiyao_test.exs`（12）（2026-10-18；`start_busy` 多轮退化为单轮 @todo，`ask_job` 合并进勒令）
- **物品通道 第十二批（play / read）**：`lib/kantele/world/{item_action,item_action_dispatcher,item_action_handlers}.ex`、`lib/kantele/world/item_actions/{play,read}.ex`、`lib/kantele/world/item.ex`（Meta.actions/read_text）、`lib/kantele/world/loader.ex`（parse_item 读 actions/read_text）、`command_controller.ex` 接线（NPC 分发之后、全局命令之前）、`scripts/backfill_item_actions.py`（回填 24 乐器 + 4 书）、测试 `test/kantele/world/{item_action_dispatcher_test,item_actions_play_test,item_actions_read_test,item_actions_play_effect_test}.exs`（2026-10-18；play_effect 为 `do_effect` 守卫钩子 3 条，续第十二批）
- 分发层：`npc_action.ex`、`npc_action_dispatcher.ex`、`npc_action_handlers.ex`、`command_controller.ex` 接线
- 注册表：25 个房间（4 yun，其中 2 间兼 bi/get；1 ride*；3 yao，其中 1 间兼 decide/join/unjoin；1 decide 单间；2 serve；1 puzzle；1 task；1 txbw；1 exchange/duihuan；1 choose；1 sign；2 copy；1 sew；2 mine/move；1 yitian[was_lou4]；jiulou 兼 yun+bi；hangzhou:liuhe9 乾隆 kneel；kaifeng:yaopu 平一指 peiyao）

---

## 五、边界约束

- **`adm/` 分区（42 次，巫师工具）直接排除**：鲁班、风、公平子等，不属玩家玩法
- **`join`（10 次，死功能）直接排除**：`tiandihui.h` 的 `do_join` 第一句 `return notify_fail(...)`，后面逻辑永不执行
- **物品侧 `play` / `read`（12 批已开通道）**：`d/*/npc/obj/` 是物品目录，其 `add_action` 走物品通道；第十二批已建 `ItemAction` 行为 + `ItemActionDispatcher` + `ItemActionHandlers`，loader 读 UCL 顶层 `actions`/`read_text`，`backfill_item_actions.py` 回填 24 件乐器（`play`：tanqin/chuixiao/guzheng）+ 4 册书（`read`）
- **不要新建全局命令**：NPC 私有动词走 `NpcActionDispatcher`，不走 `Commands.call`（除非 handler 返回 `:not_handled`）
- **红区 additive-only（已获批，bi 已按此落地）**：条件致倒 `condition/down` → `DownHandlers` → `Bi.on_mai_down/on_yuan_down`，以及 过三拳反震 `die()`，均为**新增扩展点**，未重写 `eff_*`/`Vitals`/毒/昏迷内部、`Feature.Damage` 或 `CombatEvent.die`；若未来要碰昏迷/毒内核，先回退到此文档的红区约束

## 六、提交规范（本 repo）

- 原生 Elixir 1.20.4 / OTP 29（`C:\Program Files\Elixir\` + `C:\Program Files\Erlang OTP\`），不在 PATH，test 前先把 PATH 补上
- PowerShell 不会展开 `*`，`mix test` 要写**显式测试文件路径**，不要 `mix test test/kantele/world/npc_action*`
- 只 `git add` 明确路径，**不 `git add -A`**（工作区有大量 CRLF/diff 噪声及本会话无关修改）；提交用 `git commit -F <UTF-8 无 BOM 临时文件> <显式路径>`；信息前缀 `P5-1c-` / `P5-1c-N:`
- 源文件用 LF、UTF-8 无 BOM；`.md`/`docs` 用 CRLF，不要混

---

## 七、完成后

在本文件末尾追加实际做法摘要：
- 每个 verb 对应的 LPC 源文件路径与 `do_*` 函数名
- 新建的 handler 模块与测试文件
- 注册表新增条目（room_id → verb → {module, function}）
- 测试通过数与全量测试失败集对比（是否保持 75 基线）
- 供后续 session 继续下一个 verb

### 本次 bi 完成摘要（8db2abc9，2026-10-18）

- LPC 源：`d/tulong/tulong/npc/{chang,guo,mai,yuan}.c` → `do_bi`/`do_get`/`begin`/`guo`/`die`/`unconcious`
- 新建模块：`Kantele.World.NpcActions.Bi`、`NpcAttack`、`DownHandlers`（已存在）、`Kantele.Character.BiEvent`
- 新建测试：`test/kantele/world/npc_actions_bi_test.exs`
- 注册表新增：`tulong:huichang` / `tulong:huichang_back` → `bi`、`get` → `{Bi, :run}`
- 测试：本次相关 116/116 全通过；全量失败集保持基线 75（combat/web/user 预先失败），零 NPC 回归
- 设计要点：玩家进程广播 `$N`=玩家文案 / NPC 进程落 `anti`+condition+call_out；死亡文案经 `bi/result` 下发玩家进程按 `$N` 渲染（绕过 `broadcast_vision/4` 只认 `$N` 的限制）

---
### 本次 serve/puzzle/join/unjoin 完成摘要（2026-10-18）

- LPC 源：
  - `d/meizhuang/npc/chushi.c` + `d/wuguan/npc/chushi.c` → `do_serve()`（两份逐字相同）
  - `u/mudren/npc/LiSouci.c` → `do_puzzle(arg)`（外部 curl API；无部署时 `notify_fail`）
  - `d/xiangyang/npc/huangzhen.c` → `do_join(arg)` / `do_unjoin(arg)`（落 `want_join` / `want_tuoli`，由同房间 `do_decide` 消费）
- 新建模块：`Kantele.World.NpcActions.Serve`（`lib/kantele/world/npc_actions/serve.ex`）、`Kantele.World.NpcActions.Puzzle`（`puzzle.ex`）；`Decide` 扩展 `join`/`unjoin` 分支（未新建模块）
- 新建测试：`test/kantele/world/npc_actions_serve_test.exs`、`test/kantele/world/npc_actions_puzzle_test.exs`；`npc_actions_decide_test.exs` +9 条（join/unjoin）；`npc_action_handlers_test.exs` 房间数 9→12
- 注册表新增：
  - `meizhuang:chufang` / `wuguan:guofu_fanting` → `serve` → `{Serve, :run}`
  - `beijing:wenmiao` → `puzzle` → `{Puzzle, :run}`
  - `xiangyang:qianzhuang` → `join` / `unjoin` → `{Decide, :run}`
- 测试：NPC 子集 **134/134 全通过**（10 文件）；全量 `mix test --seed 12345`：**3662/3736 通过，74 失败**（基线 75，未扩大），零 NPC 回归
- 房间定位方法（后续 verb 可复用）：UCL 里 NPC 定义是独立 `characters "key" {}` 库块，`room_characters "room" { room_id = rooms.X.id; characters = [ { id = characters.key.id } ] }` 引用；registry 的 `room_id` = `<zone 文件名>:<room_characters 键>`
- `join` 例外说明：survey 按 verb 粒度判 `join` 死功能（天地会 `tiandihui.h`），但黄真 `do_join` 是活的且是 `want_join` 唯一来源；按 room_id 房间级注册，仅 `xiangyang:qianzhuang` 命中，对其他房间零影响

---
### 本次 task/txbw 守门分支完成摘要（2026-10-18）

- LPC 源：
  - `d/wuguan/npc/yelvqi.c` → `do_task(arg)`（郭府工作覆命，`arg == "ok"` 才处理）
  - `d/city/npc/txbw.c` → `do_txbw(arg)`（天下布武 29 个入门武功，5000 gold 存款）
- 房间定位：`add_actions` 在 NPC 自己的 `characters` 块里（转换器生成），经引用该 NPC 的 `room_characters` 块反查房间——`characters.yelvqi` ← `room_characters "guofu_dayuan2"` → `wuguan:guofu_dayuan2`；`characters.txbw` ← `room_characters "wuguan"` → `city:wuguan`（注意：直接向上扫 `room_characters` 会扫到错误块，必须按 `characters.X.id` 引用反查）
- 新建模块：`Kantele.World.NpcActions.Task`（`task.ex`）、`Kantele.World.NpcActions.Txbw`（`txbw.ex`）
  - `task` 四道守卫：无 `job_name` →「我没给你工作」；六个完成 mark（`mark/劈完了` 等，含不在 names 数组的「挑完了」）全无 →「干完了吗」；session `conditions` 有 `wuguan_job` →「怎么这么快」；无 `mark/还了` →「先还工具」。`arg != "ok"` → `:not_handled` 放行全局（LPC `return 0` 原样语义）
  - `txbw` 五级守卫：无 arg → 用法提示；exp < 800,000 →「实战经验不足」；存款 < 5000 gold（`Money` gold = 10,000 coin，与 LPC `5000*100*100` 同口径）→「存款不足」；不在 29 个清单 →「看清楚了」；`stats.skills` 已有等级 →「不要浪费金钱」。守卫顺序与 LPC 一致（低经验打错技能名先撞经验守卫）
- 新建测试：`npc_actions_task_test.exs`（17 条）、`npc_actions_txbw_test.exs`（15 条）；`npc_action_handlers_test.exs` 房间数 12→14 + task/txbw lookup
- 测试：NPC 子集 **168/168 全通过**（12 文件）；全量 `mix test --seed 12345`：**3695/3770 通过，75 失败**（均为预存的 combat/web/user/LPCConverter 转换器失败，零 NPC 动作子系统回归；其中 `LPCConverterNpcFunctionsTest` 的 1 个失败与本次改动无关——测试文件对 NpcAction 零引用，单独运行同样失败）
- 踩坑记录：
  - `Stats.skill/2` 对 `skills: nil` 的裸 struct 会 `Map.get(nil, …)` 崩（库自身边界），txbw 里先归一化 `skills || %{}` 再读
  - LPC `query_temp` 未设置返回 0（假）；task 的 blank_temp? 显式覆盖 `nil/false/0/""`，mark 计数为 0 按未完成
  - `command("hmm/smile")` 社交动作：emoted.c 无定义、handler 无先例，跳过并在 moduledoc 记录
- 成功路径 @todo：`task` 的银两/经验/潜能（P2/P9 + 无 money item）暂只播一句 LPC 原版 say 台词、不改状态；`txbw` 按 LPC 成功无输出的原样静默消费（`improve_skill` 直升 1,500,000 与 Kantele `+1` 语义不匹配，属 P9 学习系统）

### 本次零散 verb 第十批完成摘要（2026-10-18）

- LPC 源：
  - `d/guiyun/npc/shutong.c` → `do_copy(arg)`；`d/city/npc/zhu.c` → 同构（`do_copy`）
  - `d/city/npc/zeng.c` → `do_sew(arg)`；`d/guanwai/npc/jiangong.c` → `do_mine`/`do_move`；`d/hangzhou/npc/jiangong.c` → 同构
  - `d/city/npc/xiaoer.c` → `do_exchange(arg)`（注册 `exchange` + `duihuan` 两个动词）
  - `d/city/npc/horseboss.c` → `do_selete()`
  - `d/pk/npc/wu.c` → `do_sign()`
- 房间定位（同一方法：`add_actions` 在 NPC 的 `characters` 块 → 反查引用该块的 `room_characters`）：`characters.shutong` → `guiyun:shufang`；朱熹 → `city:shuyuan`；曾柔 → `city:garments`；`characters.jiangong` ×2 → `guanwai:shichang`、`hangzhou:kuangshan`；店小二 → `city:kedian`；`characters.horseboss` → `city:zhujuan`；`characters.wu` → `pk:entry`
- 新建模块：
  - `Kantele.World.NpcActions.Jobs`（`jobs.ex`）：LPC 五份同构 handler（`is_busy` → `job/*` temp → 拒绝 / 多轮干活）一份实现；拒绝文案按 NPC 配置（抄书系 `message_vision` 广播、监工系 `notify_fail` 渲染）；领活后的 `start_busy` 多轮干活 @todo（`ask_job` 未移植，该分支不可达）
  - `Kantele.World.NpcActions.Exchange`（`exchange.ex`）：整链落地——积分 ≤0 / 无 arg / 表外 / 不够分四级守卫 → `Items.get` 查 32 种礼品表（18 种存在于 `clone_lib.ucl`）→ 扣 `PlayerMeta.jifen` + `give_item` + say；14 种世界数据缺失的礼品落 LPC `!ob` 分支文案（不扣分，数据补齐后自动可兑）；**rumor 频道已接（续做 43）：兑换成功分支经 `Communication.announce("rumor", ...)` 广播「听说<玩家>在店小二处兑换了一<unit><物品>」，`rumor` 频道在 `communication.ex` 的 `initial_channels` 已注册、`announce/2` 异常已吞，量词取物品 `meta.unit`、缺失回落「个」**
  - `Kantele.World.NpcActions.Choose`（`choose.ex`）：`training < 30` 守卫 + 未付 `pet/money` 时 say 报价（`Helpers.respect` →「大侠」）；宠物定制链（`input_to` 四步 + 模板落盘）不可移植且原世界即不可达（无任何文件写 `pet/money`）→ 静默 @todo
  - `Kantele.World.NpcActions.Sign`（`sign.ex`）：无条件打招呼广播 → exp < 1 万拒绝广播；PK_D 未建模 → 落 `reject_join` 的「无赛事」态文案（从 `adm/daemons/pkd.c` 提取），赛事流程 @todo
- 新建测试：`npc_actions_jobs_test.exs`（14）、`npc_actions_exchange_test.exs`（17，含续做 43 新增 rumor 3 条）、`npc_actions_choose_test.exs`（10）、`npc_actions_sign_test.exs`（6）；`npc_action_handlers_test.exs` 房间数 14→22 + jobs/exchange+duihuan/choose/sign lookup
- 测试：NPC 子集 **217/217 全通过**（16 文件；续做 43 后 exchange 15→17，+2）；全量 `mix test --seed 12345`：**3743/3817 通过，74 失败**（对比上批 3695/3770 / 75 失败：失败集合未扩大，其中 1 个差额是记录过的 `LPCConverterNpcFunctionsTest` 抖动未复现），零 NPC 动作子系统回归
- 踩坑记录：
  - `duihuan` 与第 1 档钱庄全局别名同形：NPC 分发先于 `Commands.call`，`city:kedian` 内 `duihuan` 被店小二兑换覆盖、其他房间仍走钱庄——与 LPC `add_action` 房间级覆盖语义一致
  - 测试环境 `Kantele.World.Items` 是空 Cache（`mix test` 不加载世界）：exchange 成功路径测试用 `Items.put` 注入 `clone_lib:puti1`（cache 无 delete API，注入项仅被本测试文件使用，无害；yao 测试同样因此规避）
  - `put_character` 写 `conn.private.update_character`（非 `conn.character`）：断言扣分/发物状态一律读 `private.update_character`（或 `conn.private.update_character || conn.character`）
- **不可实施核实（本批核心勘查结论）**：`bian`/`kneel`/`peiyao`/`recopy`/`recover` 的 NPC 在 UCL 有定义但无 `room_characters` 引用（分发器只读房间角色，读不到 → 无 room_id 可注册）；`zhanbu` 属 u/ 区而 `data/world` 无 `u.ucl`；`bihua` 虽在 `village:temple2` 注册，handler 是 `COMBAT_D->do_attack` 比武模拟循环，属战斗系统域——均留待 UCL 接线 / 战斗层移植

### 本次倚天链第十一批完成摘要（2026-10-18）

- LPC 源：`d/tulong/yitian/npc/{he,asan,aer,ada}.c` → `begin()`（各 `add_action("begin","bi")`）+ `die()`/`unconcious()`（阿大为 `unconcious()`，`hebiweng`/`luzhangke` 动态 spawn + 清三个 win 标记）
- **勘误**：原勘查把倚天 trio 记为「`bi` b 区 4 次（深任务状态依赖）待做」——路径误标。可达实现在 **`d/tulong/yitian/`（d 树）**，已转 UCL：`characters.{he,asan,aer,ada}` 挂 `room_characters "was_lou4"`（+`zhao`/`walker`/`items.shelf`），`characters.ada` 另挂 `room_characters "jiulou"`；`b/yitian/npc/{ada,aer}.c` 只是并行树副本（2 次、无 UCL），同 `compare` 证伪
- 新建模块：`Kantele.World.NpcActions.Yitian`（`yitian.ex`）+ `Kantele.Character.YitianEvent`（`yitian_event.ex`，事件桥接）；events.ex 两条路由（`Events` 玩家侧 `yitian/result`、`NonPlayerEvents` NPC 侧 `yitian/begin`）
- 链条设计（LPC 等价）：
  - 尝试顺序 he → asan → aer → ada；**跳过已倒下 NPC**（`dead?` = status 含「尸体」或 `StatusTracker` ETS——房间快照不随 NPC 自身 put_character 更新，与 room.ex 四处 `dead?/1` 同构）
  - 守卫：he 需剑类兵器；asan 需 `win_he` + 空手；aer 需 `win_asan` + 空手；ada 需 `win_aer` + 兵器；拒绝 = say 广播 + notify_fail 私聊（LPC 双输出原样）
  - 开打：广播 LPC 开场文案（`$N`=玩家，broadcast_vision 归一化为 `{npc}`）+ `bi` temp + `NpcAttack.kill_ob` + `yitian/begin`
  - 胜负：NPC 侧 `on_begin` 记 anti、按关出 2~3 击（`NpcAttack.strike`）、`CallOut` 8~10 拍后 `resolve`——玩家仍在敌人列表才 `Down.mark_dead` + 通知玩家（LPC 中玩家先倒则 NPC `die()` 不执行）；玩家侧 `client_result` 落 `win_*`（ada 关清三个前置标记，LPC `unconcious()` 原样）、清 `bi`、广播死亡文案
- 注册表新增：`tulong:was_lou4` → `bi`；`tulong:jiulou` → `bi`（与既有 yun 并存）；房间数 22 → 23
- 测试：`npc_actions_yitian_test.exs` 23 条（假房间 GenServer 挂 `:global` 同名 + `:sys.get_state` 注入 characters/item_instances；NPC/玩家 pid 用测试进程，`assert_receive` 收 combat/start、combat/incoming、yitian/begin、yitian/result）；handlers_test 22→23 + yitian lookup；NPC 子集 **239/239 全通过**（17 文件）；全量 **3766/3841 通过、75 失败**（74→75 为记录过的 LPCConverterNpcFunctionsTest 抖动复现，集合未扩大）
- @todo：倚天剑 `move`/`wield`/`do_unwield`（物品态 API 缺 + UCL 未把剑放进红木剑架——containment 未转换，数据补齐后剑分支自动生效）、阿大倒后鹤笔翁/鹿杖客 spawn 与赵敏 destruct（动态 NPC 生成未建模）、窗口内真实击杀无 `win_*`（combat_event 死亡钩子属红区）、heng/grin/nod/shake/@@（emoted.c 无定义，原世界即静默）

### 本次物品通道第十二批完成摘要（play / read，2026-10-18）

- LPC 源：
  - 乐器：`inherit/misc/_qin.c` → `play_qin`、`_xiao.c` → `play_xiao`、`_zheng.c` → `play_zheng`（三者逐字同构，委托 `SKILL_D("<jifa>")->play()`）；`kungfu/skill/{tanqin,chuixiao,guzheng}-jifa.c` → `play()`（四道守卫 + 7 档 `message_vision` 阈值 15/30/60/90/150/225/300 + `start_busy(3+random(3))` + `do_effect`）
  - 书册：`d/city/npc/shanzi/shan-book.c` + `d/hengyang/yueqi/{huxian,yueqi,yuepu}-book.c` → `do_read(arg)`（命中 id 表即 `notify_fail` 长文案）
- 回填 `scripts/backfill_item_actions.py` 从 LPC 抽取：`add_action(fn, verb)` → UCL 顶层 `actions = [{ verb handler }]`（24 件乐器：play_qin×19 / play_xiao×5 / play_zheng×2）；`do_read` 长文案反转义 + 换行折空格 → `read_text`（4 册书：city:shan_book、hengyang:{huxian_book,yueqi_book,yuepu_book}），并补 shan_book 的 `aliases`（LPC `set_name` 的 id 数组）
- 新建模块：
  - `Kantele.World.ItemAction`（`item_action.ex`）：行为契约，`run/2` 返回 `conn` 或 `:not_handled`（LPC `return 0` → 分发器继续下一个候选物品）
  - `Kantele.World.ItemActionDispatcher`（`item_action_dispatcher.ex`）：`extract_verb/1` + `resolve/4` + `dispatch/4`（背包优先、房间地上次之；候选 `return 0` 继续下一个 → 等价 LPC 逐个对象语义）；默认取数读 `conn.character.inventory` + 房间进程 `Room.item_instances_by_id`，定义缺失物品（占位）自然落空
  - `Kantele.World.ItemActions.Play`（`item_actions/play.ex`）：按 handler 名分派 tanqin/chuixiao/guzheng jifa；`split_with` 处理 `<song> with <id>`（`id` 不匹配本乐器 → `:not_handled`）；四道守卫（空曲名 / `query_skill==0` / `valid_enable` / `busy`）+ `lvl = song + jifa/2` 7 档分级 + `start_busy(3+random(3))`；`@song_names`/`@song_enables` 从 LPC 源逐字录入（`to_chinese` 编译态不可读，按 e2c 词典源文件文案）
  - `Kantele.World.ItemActions.Read`（`item_actions/read.ex`）：泛型，命中物品 `meta.read_text` 且 `arg` 命中 id 表（`Item.matches?`，即 UCL `aliases`）即渲染
- 接线：`command_controller.ex:recv/2` 在 `NpcActionDispatcher` 之后、`Commands.call` 之前插入 `ItemActionDispatcher.dispatch`（物品动词优先级高于全局命令，与 LPC `add_action` 同语义；重名 verb 仅 `play`/`read` 且无全局命令，无冲突）
- loader：`parse_item/4` 读 UCL 顶层 `actions`（`%{verb, handler}` 逐条解析、畸形条目丢弃）+ `read_text`（空串归一 nil）——非 map 一律丢弃，行为不变（P7）
- 测试：`test/kantele/world/{item_action_dispatcher_test,item_actions_play_test,item_actions_read_test,item_actions_play_effect_test}.exs` 共 **45 条全通过**（动词提取 / resolve / 背包优先 / return 0 续试 / handler 注册表 / 四守卫 / 7 档分级 / `$n`·`$N` 替换 / start_busy / with-id 匹配 / read 命中与落空 / `do_effect` 守卫双分支：未登记·未导出 do_effect → 空操作，已登记且导出 → 被调用）
- 全量 `mix test --seed 12345`：**3810/3886 通过，76 失败**（失败均为预存 combat/web/user/LPCConverter/Output 类别、**无 item-action 失败**；通过 +44、总数 +45 与新增用例吻合，失败 +1 落在记录过的 `LPCConverterNpcFunctionsTest` 抖动区间 74↔75↔76，非回归），物品动作子系统零回归
- 踩坑记录：
  - `Kalevala.Character.Conn.put_character/2` 写 `conn.private.update_character`（非 `conn.character`）：busy 断言读 `private.update_character || conn.character`
  - `RoomActions.Helpers.broadcast_vision/3` 把 `$N` 归一为 `{npc}`、`$n` 由 Play 在调用前替换为物品名（同 wield_command 的 `{name}`）
  - `parse_item` 必须先于 `Item.Meta` 字段新增（actions/read_text），否则 loader 不读 → 数据回填后不生效
  - 测试环境 `Kantele.World.Items` 为空 Cache：`candidate_items/1` 默认走房间进程查询，单测经 `items_fun` 注入候选，无需起房间进程（定义缺失物品走占位自然落空）
- `do_effect`（曲目技能效果）已接守卫钩子（本回合补，续第十二批）：`Play.maybe_do_effect/3` 经 `Skills.get(arg)` + `:erlang.function_exported(module, :do_effect, 2)` 守卫——歌谱技能未登记（当前全部如此）/ 未导出 `do_effect/2` 时为空操作（只播分级文案 + `start_busy`，与 LPC 技能缺省时一致）；同时在 `Kantele.Combat.Skill` 行为新增 **optional callback** `do_effect(conn, character)`，P9 把 bihai-chaosheng 等迁移为真实实现后自动接通，本通道无需改动。无真正的「@todo」遗留——效果层工作全部落在 P9 歌谱技能迁移本身（属独立任务，非 NPC/物品动作层）

### 下一批候选（NPC 通道已全部落地/证伪）

- @todo 成功路径（依赖外部系统）：task（P2/P9 + 银两 item）、txbw（P9 学习系统）、jobs 多轮打工（`ask_job` 领活）、PK_D（sign 赛事流程）、yitian 鹤笔翁/鹿杖客与倚天剑物品态、真实击杀 win 标记（战斗死亡钩子）、kneel 陈家洛在场 `kill_ob` 已补（续做 46，无需新系统）；play 的 `do_effect` 守卫钩子已就位、exchange rumor 已接（均无物品/NPC 层 @todo 遗留）
- UCL 补挂后可达：`bian`/`recopy`/`recover`（给 NPC 补 `room_characters` 引用）/ `zhanbu`（补 `u.ucl`）/ `bihua`（战斗层移植）；**`kneel` 已补挂落地（第十四批，2026-10-18）**；**`peiyao` 平一指已落地（第十五批，2026-10-18，`kaifeng:yaopu`，无需改 UCL）**

---

### 本次 exchange rumor 传闻广播 第十三批（续做 43，2026-10-18）

- LPC 源：`d/city/npc/xiaoer.c:376` `CHANNEL_D->do_channel(this_object(), "rumor", sprintf("听说%s在店小二处兑换了一%s%s。", me->name(), ob->query("unit"), ob->name()))`
- 核对 Kantele：`vendor/kalevala/lib/kalevala/communication.ex:20` `initial_channels()` 已注册 `"rumor"`；`Communication.announce/2` 内部 try/rescue/catch（缺频道/进程仅少一条传闻，不崩）；`Kalevala.Communication.publish` 走 `:ets.lookup` + 同步 `GenServer.call`，测试安全不挂起 → `mix test` 启动 Kantele app 后 rumor 频道真实存在，可直接 announce
- 修改模块：`Kantele.World.NpcActions.Exchange`（`lib/kantele/world/npc_actions/exchange.ex`）：成功分支末尾接 `announce_rumor/3`（经 `Items.get` 取物品、`announce("rumor", rumor_text(...))`，取不到则不广播）+ `rumor_text/3`（量词取 `unit`、缺失/空回落「个」）+ `item_name/1`/`item_unit/1`（优先顶层 `unit` 字段、回落 `meta.unit`）；新增 `alias Kantele.Communication`；moduledoc「未建模依赖 @todo」→「已建模依赖」
- **关键事实**：`Kalevala.World.Item` struct 无顶层 `unit` 字段，量词落 `meta.unit`（`loader.ex` 读 `Map.get(meta, :unit)`）；故 `item_unit/1` 读 `meta[:unit]` 回落，与 `Items.put` 注入写法一致
- 测试：`npc_actions_exchange_test.exs` 改 `async: false`（订阅 rumor 全服频道，串行避免串扰）+ 新增 `rumor 传闻广播` describe 3 条（① `rumor_text/3` 纯函数 4 形态：颗/本/nil/空；② 集成：注入 `meta: %{unit: "颗"}` 的 `clone_lib:puti1` 后 `Exchange.run`，`assert_receive` 收 `Kalevala.Event.Message` 含「听说玩家在店小二处兑换了一颗血菩提。」；③ 失败分支 `refute_receive` rumor 事件）→ 累计 **17 条**
- 验证：`mix compile`（736 文件全过）+ `mix test test/kantele/world/npc_actions_exchange_test.exs` → 17/17 全通过；NPC 子集 218/218（16 文件）；全量失败集保持基线（未扩大）
- 踩坑：测试注入的 `Kalevala.World.Item` 字面量原写 `unit: "颗"`（顶层字段）→ 编译期 `KeyError: key :unit not found`（struct 无该字段），改 `meta: %{unit: "颗"}` 修复（handler 逻辑已读 `meta[:unit]`，无需改）

### 本次 kneel 第十四批（续做 44，2026-10-18）

- LPC 源：`d/hangzhou/npc/qianlong.c` 的 `do_kneel()`（乾隆 `add_action("kneel", "do_kneel")`）
- 结论修正：此前判为「UCL 未挂房、不可实施」——回源发现 `characters "qianlong"` 与 `rooms "liuhe9"/"liuheta"` **均已由转换器生成**，只缺 `room_characters "liuhe9"` 的挂载引用。补挂 + 补 handler 即可，无需新建世界数据
- 修改模块：
  - `lib/kantele/world/npc_actions/kneel.ex`（新）：`run/2` 守卫 `hangzhou:liuhe9`；`do_kneel` 三支——① `combat_exp < 150000` → `Damage.receive_wound(:qi, 20)` + 扣 1% 经验 + 落 `hangzhou:liuheta` + 广播「被一脚踢下六和塔」+ 私聊受伤；② `PlayerMeta.mark(meta, "qianlong")` 已置 → 「哼了一声，没理你」；③ 否则 → 置 `marks.qianlong = 1` + `combat_exp + 10000` + 封赏 say。陈家洛在场 `kill_ob` 分支已补（续做 46：`Room.npc_characters_by_id` + `NpcAttack.kill_ob`）
  - `lib/kantele/character.ex`：`PlayerMeta` 新增 `marks: %{}` + `mark/2`（读，缺省 nil）+ `put_mark/3`（写），落盘 `metadata.marks`（与 dugu_jiujian 读 `character.meta.marks` 同源；`Helpers.add_mark/3` 是会话级 `temp`，不适用持久剧情标记）
  - `lib/kantele/character/records.ex` + `priv/repo/migrations/20261018000000_add_marks_to_character_metadata.exs`：`marks` 真正落盘——schema `field(:marks, :map, default: %{})`、changeset cast `:marks`、`save/1` 写 `marks: meta.marks || %{}`、`apply_to_character/3` 读回；迁移加 `marks` 列。**`Records.save/1` 是显式白名单，新增 `PlayerMeta` 字段必须同步四处**；kneel 的 reward/kick 末尾调 `persist/1`（仅 `player:` 前缀落盘，单测 fixture 跳过）
  - `lib/kantele/world/npc_action_handlers.ex`：`@registry` 增 `"hangzhou:liuhe9" => %{"kneel" => {Kneel, :run}}`（23→24 房间）
  - `data/world/hangzhou.ucl`：新增 `room_characters "liuhe9" { room_id = rooms.liuhe9.id; characters = [{ id = characters.qianlong.id }] }`
- 测试：`test/kantele/world/npc_actions_kneel_test.exs`（新，13 条，`async: true`）：分派 2（nil/他房 → `:not_handled`）、弱玩家 5（落点/扣经验/受创/广播/不封赏）、已封赏 3（不加经验/广播+私聊/不封赏）、首次封赏 3（标记/加经验/三文案）
- 验证：`mix compile` 通过；`npc_actions_kneel_test.exs` 13/13；`npc_action_handlers_test.exs` + 全部 `npc_actions_*_test.exs` 255/255；`loader_meta_test` + 上述子集 274/274（UCL 补挂无 loader 回归）
- 踩坑：
  - `Damage.receive_wound/3` 返回 **`{:ok, character}`**（不是裸 character），且 vitals 已在返回的 character 上更新——原 pipeline 直接把 tuple 当 struct 改 `room_id` 会崩，且会用旧 `meta` 丢掉创伤后的 vitals；改为解包 `{:ok, wounded}` 后用 `wounded.meta`
  - `Helpers.broadcast` 返回新 conn（channel_changes 在其上），若紧接着用**原 conn** `Helpers.render`，广播会被丢弃——分支内必须 pipeline 串起来
  - `@doc` 双引号字符串里嵌 `"qianlong"` 未转义 → 语法错误；`@moduledoc` 结束 `"""` 缩进必须 ≤ 正文缩进（4 空格收尾 vs 2 空格正文 → "indented too little"）
  - 注册表房间数断言（`npc_action_handlers_test.exs`）需随新增房间从 23 改 24

---
### 本次 peiyao 第十五批（续做 45，2026-10-18）

- LPC 源：`d/city/npc/ping.c` 的 `ask_job()` + `do_peiyao()` + `working()`（平一指配药）。Kantele 尚未建模 inquiry/ask_job 层，故把 `ask_job` 合并进 `peiyao` 勒令——首次输入 `peiyao` 视为领活，第二次输入才执行配药并结算（`start_busy` 多轮回调缺失退化为单轮，@todo 见 `Combat` `busy` 字段）。
- 世界数据：**无需改 UCL**——`clone_lib.ucl` 的 `characters "city_ping"` 已带 `add_actions = ["peiyao", ...]`，`kaifeng.ucl` 的 `room_characters "yaopu"` 经 clone_lib 回退引用 `characters.city_ping.id`（分发器读 `room_characters`，故可直接命中）。
- 新建模块：`Kantele.World.NpcActions.Peiyao`（`lib/kantele/world/npc_actions/peiyao.ex`）
  - 守门：`combat_exp < 5000` 拒绝；`combat_exp > 20000 且 mark/job_peiyao > 1000` 拒绝；`qi < 5` 拒绝；忙乱（`meta.combat && Combat.busy?`）拒绝
  - 结算：`receive_damage(:qi, 1)` + 经验/潜能 `30 + :rand.uniform(20) - 1`（30~49）+ `mark/job_peiyao + 1`（持久 `meta.marks`）+ 清 `temp job/peiyao`；`mark > 50 且 random(50) == 1` 文案赠「丹玉磨」（item 缺，@todo）
  - `persist/1`：`put_character/2` 仅改内存，此处仅对 `player:` 前缀真实角色落盘 `combat_exp`/`potential`/`marks`
- 新建测试：`test/kantele/world/npc_actions_peiyao_test.exs`（12 条：分派/守门/领活/结算/不重复结算）
- 注册表新增：`kaifeng:yaopu` → `peiyao` → `{Peiyao, :run}`（房间数 24→25）
- 踩坑：`PlayerMeta.temp` 可能为 nil，需先 `temp = meta.temp || %{}` 归一为 map，再取值；`Damage.receive_damage/3` 返回 `{:ok, character}`，需解包后再用 `wounded.meta`。
- 测试：peiyao 12/12、handlers 41/41、kneel 13/13（无回归）；NPC 私有动作 + 注册表 252/252 全通过；物品通道 45/45 全通过。

---
### 本次 kneel 陈家洛分支（续做 46，2026-10-18）

- LPC 源：`d/hangzhou/npc/qianlong.c` 的 `do_kneel()` 首个 `if (objectp(chen = present("chen jialuo", environment(me))))` 分支——陈家洛在场时广播「被拦住」+ `chen->kill_ob(me)`，**不 return**，后续跪拜/判弱/封赏照常。
- 实现：`kneel.ex` 在 `do_kneel/3` 进 cond 前调 `chen_attacks/2`——`Room.npc_characters_by_id(@room_id)` 取房间角色快照，按 `meta.aliases` 命中 `"chen jialuo"` 找陈家洛、按 `:id == character.id` 找玩家快照；两者都在则 `Helpers.broadcast` 拦住文案 + `NpcAttack.kill_ob(chen, player)`（发 `combat/start` 双方）。房间无进程时返回 `[]` 安全落空。
- 可达性说明：`characters "chen"` 静态挂 city/fuzhou/quanzhou/kaifeng，`room_characters "liuhe9"` 只含乾隆（LPC 房间 `liuhe9.c` 也不 clone 陈家洛）→ 本分支常态不触发；但 LPC 代码有它，实现后世界数据/游荡 NPC 补入即生效。
- 测试：`npc_actions_kneel_test.exs` 改 `async: false`（`:global.register_name` 假房间），新增 3 条（广播「被陈家洛一把拦住」/ 玩家收 `combat/start`（type kill）/ 不阻断封赏 +10000）→ 13→16 条；NPC 私有动作 + 注册表 **255/255 全通过**。
- 踩坑：`NpcAttack.kill_ob/2` 要求双方快照带 `:pid`（`alive?/1` 只认 `is_pid`）；假房间需 `state.private.characters` + `:global` 同名注册，与 yitian 测试同法。

---
### 本次修复 `LPCConverterNpcFunctionsTest` 抖动（续做 47，2026-10-18）

- 根因：`assert Map.keys(ast.engage) == [:fight, :hit, :kill]` 依赖 `Map.keys/1` 的返回顺序（Elixir 不保证 map 键序），实际偶发 `[:kill, :fight, :hit]`。转换器抽取正确，是**测试断言**写死顺序。
- 修法：`test/kantele/world/lpc_converter_npc_functions_test.exs:190` 改为 `Enum.sort(Map.keys(ast.engage)) == [:fight, :hit, :kill]`。
- 验证：`--seed 0/1/42/12345/999` 五连跑均 28/28（修前 27/28）；全量 **3847/3920 通过、73 失败**（LPCConverter 失败消失，余 73 均预存 combat/web/user），基线由抖动 74↔75↔76 收敛为稳定 73。

---
### 本次修复全量失败集清理（续做 48，2026-10-18）

基线 **73 → 43 确定性失败**，30 条转绿，其中 5 处是实现真 bug（非夹具）：

- **`escape_attribute/1` 被 `clean` 提交回退**（`vendor/kalevala/lib/kalevala/output.ex`）：`e56b4bf0 clean`（纯 moduledoc 重排）把 `String.replace("\"", "\\\"")` 误改成 `String.replace("\\\"", "\\\\\"")`——只匹配「已转义」的 `\"`，裸双引号不再转义，`parse_tag_attributes/1` 正则遇裸引号截断 → 整行回退成原始标签文本，`53b98609` 修的「房间 look 显示标签源码」复活。同时补 `escape_attribute(nil) -> ""`（`:description` 无默认值，UCL 可省略 → 崩 `String.replace/4`）。转绿 12 条。
- **`Kantele.World.room_flags/1` 对 map 形状 `zone.rooms` 崩 `BadMapError`**（`lib/kantele/world.ex`）：运行时契约是列表（`loader.ex` 的 `zone_rooms_to_list/1` 归一后才进 ZoneCache），`Enum.find(&(&1.id == room_id))` 遇 map 产出 `{key, value}` 元组即崩；`start_room_from_flags/0` 同病且在**登录**路径。新增私有 `zone_rooms/1`（map → `Map.values`，list 原样）两处共用。根因是 `quest_daemon_test` 把未归一的 map 形状区写进全局 ZoneCache 且不清理，已改为列表。转绿 8 条。
- **`stats.ex` 4 处 `%__MODULE_{}` 拼写错误**：字节实为 `__MODULE_`（尾部单下划线），是**动态结构体模式**，绑定变量后匹配**任意** struct 而非 `%Stats{}`；功能上碰巧能跑故长期未发现。四处统一为 `%__MODULE__{}`。
- **`Kalevala.Cache` 缺 `delete/2`**：ETS 表 `:protected`，只有 cache 进程能写，API 有 put/get/keys 却无 delete，导致写全局缓存的测试无法清理（`drink_test` 塞 `global:potion` → `ItemResolveTest` 随顺序时红时绿）。新增 `delete/2` + `handle_call({:delete, key})` + 宏 `delete/1`；两个测试各自清理。转绿 2 条。
- **夹具漂移**（实现按 LPC 严格对齐后夹具没跟上）：`chousui_zhang_test` 补 `prepared`（LPC `dan.c:40` 与 `mapped` 是两道独立门）+ 毒药缺 meta 改断言「不是毒药」（LPC `dan.c:53`）→ 4 条；`zz_promoter_env_test` 新增 `xian_character/2`（对手+暗器+mapped+prepared）与 `hmg_dzjm` buff（LPC `hui.c:97`）→ 3 条；`flow_test` 谓词加 `is_binary(ch.status)` 防 `nil =~` → 1 条。

**未修需决策**：`zz_promoter_env_test:97` `assert length(mods) > 500` 实测 292。带 `由 translate_perform.py 生成` 标记的文件只剩 292/728（`faea7186` 设阈值时该目录 936 个文件），手写重写会让文件丢标记，故计数下降是「严格对齐 LPC」的正常副作用，**不是生成器回归**；下调阈值会削弱守卫，故未擅改。

**下一批**：`t2_self_buffs_test.exs` 的 `build_character/1` 只 `Keyword.take(opts, [:skills, :mapped, :performs])`——**不支持 `prepared`**，且多数用例连 `mapped` 都没给，于是先撞「你没有激发X」而非用例想测的等级/成功分支。修法：加 `:prepared` + 逐技能按 LPC 门序（mapped → prepared → level → neili）补夹具并核对期望文案。**必须逐技能核 LPC 门序，不可批量猜**，否则会写出断言错误文案的假绿。

---
### 本次修复 T2SelfBuffs 批次（续做 49，2026-10-18）

基线 **43 → 28 确定性失败**，15 条转绿（`T2SelfBuffsTest` 12 + `T2SelfBuffs2Test` 2 + `RiyueBianTest` 1）。逐技能回源 LPC 后发现**只有 1 个技能是真 bug**，其余是夹具漂移与「断言写的是非 LPC 文案」。

**真 bug（硬崩溃 + 功能缺失）** `lib/kantele/combat/skills/performs/longxing_jian/xian.ex`：
- 调用了**不存在的** `Performs.consume_neili/2` → 玩家一用「神龙再现」必崩。全仓仅此一处引用（臆造辅助函数），既有惯例是内联 `%{vitals | neili: vitals.neili - N}`。
- 注释声称 attack+2 / dodge+1 / parry+1 / xian+1，但代码**只做了 `xian`**，三个属性加成从未落地（LPC `xian.c:32-35` 四处 `add_temp`）。
- 广播漏 `$N`（LPC 用两次）。修法：内联扣 100 内力 + `start_busy(combat,1)` + 四个 `Map.update` + `Broadcast.publish(..., n1:)`；删 4 个死 alias。LPC 原文「神龙从天而**将**」是错字（应为「降」），按逐字对齐保留。

**判定「实现对、测试错」的 8 条**（均逐字比对 `C:\files\git\mud`）：
- 华山 lian：「不够纯熟」→「还不到家」(`lian.c:39`)；「剑掌齐发」→「$N使出华山派绝技「剑掌五连环」，身法陡然加快！」(`lian.c:60`)；目标 `busy==1` → `random(3)==1` 才忙乱、rng→1 不触发故 `busy==0`；「左闪右避」→ 目标侧文案由引擎生成、本模块不补。
- 狂风 sao：「火候不够」→「还不到家」(`sao.c:39`)（夹具另缺 `mapped`）；「横扫」→「犹如狂风疾电一般劈刺向」(`sao.c:47`)（夹具另缺 `dodge`）；`attack_bonus` 用真实 `:rand.uniform` 不可注入 → 改断言区间。
- 反两仪：「还没有加入任何队伍」→「反两仪刀共需两人…」(`makearray.c:21`，LPC 无前者文案)；「你必须使用」→「必须使用」（LPC 带 `ob->name()` 前缀）。
- 凌波微步：LPC 文案按**性别**分两支、**无修为分档**（`ling.c:35-38`），测试角色无 gender → else 支「只见$N意态飘逸，影子乱飞…」。

**夹具漂移**：`team_two()` 与「未激发反两仪刀」内联 team 的成员快照缺 `room_id` → `makearray.ex:128 same_room/2` 的 `partner.room_id` 直接 `KeyError`（3 条）；sao「6 击命中」按文档化 `level/3` 重算（120/3×6=240），目标气血提到 500 避免被钳到 0。

**另**：`riyue_bian_test.exs:388` 伤字诀 `ap` 660 → **480**（LPC `shang.c:44` `ap = query_skill("whip") + query_skill("force")`，不含 `riyue-bian` 本身；实现正确）。

**验证**：`t2_self_buffs*` 双文件 `--seed 0/42/12345` 均 **78/78**；全量 **3891/3921**，失败 30 = 27 bcrypt + 1 阈值 + 2 条 DBConnection 池抖动。

**遗留待决策（2 项）**：
1. `zz_promoter_env_test:97` `length(mods) > 500` 实测 292（续做 48 已记录）。
2. **伤害近似不一致**：`huashan_jian/lian` 用 `level/10`、`kuangfeng_jian/sao` 用 `level/3`，但两者 LPC 都是同一个 `COMBAT_D->do_attack` 循环，理应共用同一近似。sao 的 `level/3` 已写进其 moduledoc（说明是有意改动而非笔误），故本批按「测试对齐实现」处理、**未擅自改战斗数值**；若判定应统一为 `level/10`，需另开一批同时改 sao 实现 + moduledoc + 测试。

---

## 续做 50：清掉 bcrypt NIF（26 条）+ ecto preload（2 条），基线 28 → 1

### 一、bcrypt：之前「本机无 C 编译器」的结论是错的

上一轮结论写的是「27 条 bcrypt 失败 = 环境限制，不可修」。复核后**推翻**：

- PATH 上确实没有 `cl/gcc/nmake`，但 `C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe` 在。
  `vswhere -all -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64` 报出两套安装：
  `2022\BuildTools`（MSVC **14.44.35207**）与 `18\Community`；Windows SDK **10.0.26100.0** 的 UCRT 头与库齐全。
- 真正的两个拦路虎都不是「缺编译器」：
  1. **`vcvars64.bat` 依赖 reg.exe**，被本机安全策略拦截 → SDK 的 `INCLUDE/LIB` 没注入，
     表现为 `cl` 能跑但 `bcrypt_nif.c(52): fatal error C1083: 无法打开包括文件: "stdio.h"`。
  2. **elixir_make 0.6.2 走 `nmake /F Makefile.win`**，而 nmake 横幅是 CP936 中文字节，
     Elixir 1.20 的 `System.cmd` 按 UTF-8 解码直接崩：
     `** (ArgumentError) argument error` → `System.do_port_byte/3` → `elixir_make compile.make.ex:223`。
     设 `VSLANG=1033` / `chcp 65001` 都压不住。
- 解法：**绕开 vcvars + 绕开 elixir_make**，在 cmd 里手工设 `PATH/INCLUDE/LIB/ERTS_INCLUDE_PATH`
  后直接 `nmake`，再把 `bcrypt_nif.dll` 拷进 `_build/{dev,test}/lib/bcrypt_elixir/priv/`
  （`:code.priv_dir/1` 指向 `_build`，不是 `deps`）。
- 已固化为 `scripts/build_bcrypt_nif.bat`（含上面两条成因的注释与版本号更新方法）。
  `deps/`、`_build/` 均在 `.gitignore`，产物不入库，**换机器需重跑该脚本**。
- 验证：`Bcrypt.verify_pass("hunter2", Bcrypt.hash_pwd_salt("hunter2")) == true`。

### 二、bcrypt 修好后**暴露**的真 bug：`Zones.get/1` / `Rooms.get/1` 必崩

- 之前 4 条 `ZoneControllerTest` 全挂在 `Bcrypt.Base.gensalt_nif/3`（`create_admin` 建管理员时哈希密码），
  bcrypt 一好，其中 2 条立刻推进到下一个错误：
  ```
  ** (UndefinedFunctionError) function Ecto.Adapters.Postgres.checked_out?/1 is undefined or private,
     but the behaviour Ecto.Adapter expects it to be present
  ```
- 根因是**依赖版本对不上**，不是本项目代码：
  - `deps/ecto` **3.6.2** 在 `lib/ecto/adapter.ex:66` 声明 `@callback checked_out?(adapter_meta)`（非 optional），
    并在 `lib/ecto/repo/preloader.ex:124` 的 `maybe_pmap/3` 里调用它——**仅当顶层 preload 条目 ≥ 2** 时。
  - `deps/ecto_sql` **3.6.1** 的 `Ecto.Adapters.Postgres` / `Ecto.Adapters.SQL` 里**完全没有** `checked_out?`
    （`grep -rn checked_out deps/ecto_sql/` 零命中）。该实现是 **ecto_sql 3.6.2** 才加的
    （`lib/ecto/adapters/sql.ex:645`）。即 ecto 3.6.2 + ecto_sql 3.6.1 是**允许解析但不兼容**的组合。
  - `Zones.get/1` 的 `Repo.preload([:staged_changes, rooms: [:staged_changes]])` 正好 2 条 → 必踩。
    `Rooms.get/1` 同理（`[:staged_changes, zone: [:staged_changes]]`）。
- **为什么不直接升 ecto_sql**：试过，`mix deps.update ecto_sql` 会把 ecto 拖到 3.14 / decimal 3.0（major）/
  postgrex 0.22，一次不可控的大升级；而**只把 ecto_sql 钉到 3.6.2 也走不通**——
  `deps/ecto` 3.6.2 的 `lib/ecto/query.ex:428` 有 `@opaque dynamic :: %DynamicExpr{}`，
  与 Elixir 1.20 新增的内建类型 `dynamic/0` 冲突，编译期直接
  `** (Kernel.TypespecError) type dynamic/0 is a built-in type and it cannot be redefined`。
  也就是说本机 `_build` 是**旧 Elixir 编译的缓存**，ecto 在当前工具链下**无法重新编译**，
  任何触发 ecto 重编译的操作都会把构建打坏。
- 故采用**应用层规避**：把两次 preload 拆成两次单条调用，走 `maybe_pmap/3` 的串行分支，
  完全不触达 `checked_out?/1`。两处各加了注释说明成因与「ecto_sql >= 3.6.2 后可合并回一条」。
  ```elixir
  # lib/ex_venture/zones.ex
  |> Repo.preload(:staged_changes)
  |> Repo.preload(rooms: [:staged_changes])
  # lib/ex_venture/rooms.ex
  |> Repo.preload(:staged_changes)
  |> Repo.preload(zone: [:staged_changes])
  ```
  注意 `in_parallel: false` **不管用**：`maybe_pmap/3` 的条件是
  `match?([_,_|_], preloaders) and not checked_out?(repo_name) and Keyword.get(opts, :in_parallel, true)`，
  `checked_out?` 排在 `in_parallel` **之前**，短路不到。

### 三、构建缓存抢救记录（踩过的坑，别再踩）

`mix deps.update` 一旦动了 ecto，`_build/test/lib/ecto` 会被 Mix 清空并尝试重编译 → 失败 → ebin 归零。
恢复办法（`_build/dev` 未受影响，是干净的同版本产物）：

1. `git checkout -- mix.lock`；`mix deps.get` 把 `deps/ecto_sql` 退回 3.6.1；
2. `rm -rf _build/test/lib/ecto _build/test/lib/ecto_sql`，
   再从 `_build/dev/lib/{ecto,ecto_sql}` 整目录拷回（连 `.mix/compile.elixir` 一起）；
3. **补写 `_build/test/lib/ecto/.mix/compile.elixir_scm`**：Mix 的 `Mix.Dep.Loader.validate_manifest/1`
   在 manifest 缺失且 SCM 可 fetch 时会把 dep 标成 `:compile`（`loader.ex:431-432`），于是又去重编译 ecto。
   格式（见 `Mix.Dep.ElixirSCM`）是 `{2, {System.version(), :erlang.system_info(:otp_release)}, Hex.SCM, lock}`，
   `lock` 取 `mix.lock` 里该 dep 的元组：
   ```elixir
   {lm, _} = Code.eval_file("mix.lock")
   data = {2, {System.version(), :erlang.system_info(:otp_release)}, Hex.SCM, lm[:ecto]} |> :erlang.term_to_binary()
   File.write!("_build/test/lib/ecto/.mix/compile.elixir_scm", data)
   ```
4. `mix deps` 仍会打印「the dependency build is outdated」，但 `mix test` 已能正常跑——这条提示是
   历史遗留（19 个 dep 都没有/对不上 manifest），**不影响运行**，不要再去「修」它。

### 四、验证

- `test/web/controllers/admin/zone_controller_test.exs`：4/4。
- 全量 run #1（`/tmp/full_test9.log`）：**3918/3921**，失败 3 = 1 阈值 + 2 条 `DBConnection`
  `owner #PID<...> exited`（`EatTest`、`CopyskillCommandTest`）；两条单独跑 **12/12** 全过，确认为抖动。
- 全量 run #2（`/tmp/full_test10.log`）：**3916/3921**，失败 5 = 1 阈值 + **4 条**池抖动
  （`DrinkTest`、`CutCommandTest`、`QuestFamilyTest`、`TrapEventTest`）——
  与 run #1 命中的测试**完全不同**，进一步确认是随机抖动而非确定性缺陷。
  `grep -c 'shutdown: "owner #PID'` = 4，逐条核对后仅 `PromoterEnvTest` 是断言失败（`Assertion with > failed`）。
- **结论：确定性失败基线 = 1（仅 `zz_promoter_env_test` 阈值），另有 0–4 条池抖动随 run 变化。**
  总用例 3921，最好成绩 3920/3921。

### 六、`scripts/build_bcrypt_nif.bat` 两个踩坑点（写脚本时踩的）

- **批处理里的中文注释会被 cmd 误当命令执行**（UTF-8 多字节被按 CP936 切分，`rem` 行被截断）。
  最终版脚本**全 ASCII**，中文说明只留在本文件里。
- **文件必须是 CRLF 行尾**。LF 行尾 + 括号块（`for ... ( ... )`）会让 cmd 在词中间断行，
  报 `'riv' 不是内部或外部命令` 这类怪错。
- `_build/test/lib/bcrypt_elixir/priv` 在本机是指向 `deps/bcrypt_elixir/priv` 的**目录联接**，
  所以：`cp` 会报 "are the same file"，`copy /Y` 会报 "being used by another process"，
  而 `del` 会**把 deps 里的真文件一起删掉**。脚本因此只做 copy、并以「copy 后文件是否存在」判定成功，
  绝不对该路径执行 del。


### 五、遗留待决策（3 项，已于续做 51 全部拍板）

1. `zz_promoter_env_test` 模块数阈值 —— **已定 1C**：改选择器 + 已知崩溃快照（见续做 51）。
2. `level/3` vs `level/10` 统一 —— **已定 2C**：保持现状，仅补 moduledoc 说明。
3. `ecto` / `ecto_sql` 版本对不上 —— **已定 3A+D**：保留应用层规避 + 加护栏测试；
   正式升级仍未排期（需降 Elixir 到 1.18，或升 ecto 到 3.10+ 并接受 decimal 3.0 连带升级）。

---

## 续做 51：三项拍板落地，确定性失败 1 → 0

按「1C → 2C → 3A+D」执行。

### 一、1C：perform 冒烟测试的选择器修好了，覆盖面 292 → 715

**问题**：`zz_promoter_env_test` 靠一句注释 `由 translate_perform.py 生成` 认文件，
而 728 个 perform 里只剩 292 个还带这句（手工重写会覆盖掉），于是 436 个招式
**从来没进过冒烟测试**——`@known_broken` 里那 20 个崩溃正因如此一直没人发现。

**改动**（`test/kantele/combat/zz_promoter_env_test.exs`）：
- 选择器 `@marker` → `@behaviour_marker "@behaviour Kantele.Combat.Perform"`，命中 **715** 个；
  `generated_modules/0` 改名 `perform_modules/0`，返回的路径改为相对 `@root`。
- 测试名改为「所有 perform 模块在游戏环境中的崩溃集合与已知名单一致（默认角色）」，
  断言从 `failures == []` 换成 **`actual == expected`**，其中 `expected` 是 `@known_broken`。
  这不是 skip 名单，而是**当前真实状态的精确快照**：
  - 修好任何一个 → `expected -- actual` 非空 → 测试失败并提示「请从 @known_broken 删掉」；
  - 出现新崩溃 → `actual -- expected` 非空 → 同样失败。
  名单因此不会悄悄腐烂。
- `@known_broken` 登记 20 条（相对路径），成因分四类：

| 数量 | 症状 | 文件 |
|---|---|---|
| 7 | 缺 `alias Kantele.Character.Combat` → `Combat.weapon/1 is undefined` | `sanwu_shou/{kong,zhi}`、`shangqing_jian/{qing,zhuo}`、`shedao_qigong/{cui,fei,xian}` |
| 2 | 缺 `alias Kantele.Character.Stats` → `Stats.skill/2 is undefined` | `yinyang_shiertian/powerup`、`yunlong_shengong/powerup` |
| 1 | 缺 `alias Kantele.Combat.Engine` → `Engine.rand/2 is undefined` | `sanyin_wugongzhao/zhua` |
| 9 | `BadMapError: expected a map, got nil`（**执行顺序 bug**，见下） | `luohan_fumogong/powerup`、`qianzhu_wandushou/{wan,zhugu}`、`tanzhi_shentong/po`、`xuedao_dafa/{chi,shi,xue}`、`zigai_jian/hui`、`zijinbagua_dao/bagua` |
| 1 | `ArgumentError: not a nonempty list` | `xianglong_zhang/qu` |

**那 9 个 BadMapError 值得单独记**（以 `xuedao_dafa/chi.ex` 为例）：

```elixir
weapon = Combat.weapon(combat)        # 32 行：空手时返回 nil
wn = Map.get(weapon, :name, "")       # 33 行：对 nil 取 map → 崩

with :ok <- check_perform_known(character),   # 35 行：守卫在这之后！
     :ok <- check_gates(character),
```

即「先取武器、后做守卫」。LPC 原文是先 `objectp(weapon)` 挡掉、回「你使用的武器不对！」。
所以这 9 个正确行为应是**礼貌拒绝**而不是崩——后续修的时候要把 `Combat.weapon/1`
挪到 `with` 里或加 nil 守卫，不是简单加个 `|| %{}`。

### 二、2C：`level/3` 与 `level/10` 保持不统一，补文档

在 `huashan_jian/lian.ex` 与 `kuangfeng_jian/sao.ex` 的 moduledoc 各加一段「差异（TODO(migrate)）」，
写明：
- 每击伤害公式是对 LPC `COMBAT_D->do_attack` 的**近似**，不是 LPC 数值；
- 同类「循环 do_attack」的招式各写各的（`/10` vs `/3`，差 3.3 倍）；
- 两者**故意不统一**——没有依据的改动会直接影响平衡；
- 将来若在战斗层抽出共享的 do_attack 近似实现，应把两者一起切过去。

### 三、3A+D：保留规避 + 新增护栏测试

新增 `test/ex_venture/preload_guard_test.exs`：扫描 `lib/**/*.ex`，用 `Code.string_to_quoted`
解析 AST，找出所有 `Repo.preload` 调用并统计其 preload 规格的顶层条目数，> 1 即失败。

关键设计：
- **用 AST 而不是正则**——注释里写 `Repo.preload([:a, b])` 不会误报（注释不进 AST）；
- **区分规格参数与 opts**：管道形式 `x |> Repo.preload(spec, opts)` 的 spec 在第 0 位，
  直接调用 `Repo.preload(q, spec, opts)` 的 spec 在第 1 位；用「第 0 个参数是否为字面量列表」判别，
  避免把 `[force: true]` 当成规格；
- **不覆盖 query builder 版** `Ecto.Query.preload/3`（`Model |> preload([a, b]) |> Repo.all()`）——
  它走查询内 join，不经过 `maybe_pmap/3`，多条目是安全的。`rooms.ex:119/133` 正属此类。

已用临时探针文件验证护栏的判定精度（验证后已删除）：

| 写法 | 期望 | 实测 |
|---|---|---|
| `Repo.preload(%{}, [:a, :b])` | 命中 | 2 条 ✓ |
| `x \|> Repo.preload([:a, b: [:c]])` | 命中 | 2 条 ✓ |
| `Repo.preload(x, [rooms: [:a, :b]])` | 放行 | 1 条 ✓ |
| `Repo.preload(x, [:a], force: true)` | 放行 | 1 条 ✓ |
| `x \|> Repo.preload([:a], force: true)` | 放行 | 1 条 ✓ |

### 四、验证

- `zz_promoter_env_test.exs`：**5/5**（崩溃集合与 `@known_broken` 精确相等）。
- `preload_guard_test` + `zones_test` + `rooms_test`：**14/14**。
- 全量（`/tmp/full_test11.log`）：**3920/3922**，失败 2 = 2 条 `DBConnection` 池抖动
  （`CopyskillCommandTest`、`NpcActions.ExchangeTest`），逐条核对确认非逻辑缺陷。
  用例总数从 3921 增至 3922（新增护栏测试）。
- **确定性失败基线 = 0。**

### 五、一个**先前就存在**的环境问题（本次未动）

`MIX_ENV=dev` 的 `mix compile` 会失败：`_build/dev` 有 **16 个依赖缺 `compile.elixir_scm` 清单**，
Mix 因此判定它们未编译（`loader.ex:431-432`）→ 尝试重编译 → 第一个撞上 `ecto` → 失败。
其中 **12 个是本次会话从未碰过的依赖**（bamboo、bamboo_phoenix、credo、ex_aws、ex_aws_s3、
logster、phoenix、phoenix_ecto、phoenix_live_reload、stein、stein_storage、vapor），
故这是**本会话之前就存在的状态**，不是本次改动引入。
`MIX_ENV=test` 的 59 个依赖清单齐全，`mix test` 不受影响。
若要修 dev，需按续做 50 §三 的办法为 16 个依赖补写清单（建议先整目录备份 `_build/dev`）。



