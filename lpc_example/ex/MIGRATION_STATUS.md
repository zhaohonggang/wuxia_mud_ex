# LPC Example 迁移现状与差距记录

> 更新时间: 2026-09-02 (commit `41497fa` on `kalevala`)
>
> **当前测试基线**: 1411 tests / 0 failures
>
> 本文档主要记录 LPC examples 迁移，命令迁移进度见 `MIGRATION_PLAN.md`。

---
>
> 📄 **框架需求汇总**: `FRAMEWORK_REQUIREMENTS.md` 汇总全部 17 份子目录
> FRAMEWORK_REQUIREMENTS 并按跨领域域归并，含对照 `lib/kantele` 现状的
> 可行性分级与分阶段实现步骤（见本文档「框架落地」章节）。
>
> ⚠️ **重要约束**: 所有迁移仅限 `C:\files\git\wuxia_mud_ex\lpc_example\ex` 目录内修改，**不实际接入游戏**。产物为纯数据 UCL + 纯函数 Elixir 模块，供开发参考与框架能力设计使用。所有 `.ex` 均通过容器 `elixirc` 编译（Elixir 1.11），仅剩框架缺口的 undefined-function 警告属预期。

---

## 真实行为迁移 (18/22) —— `.ex` 纯函数 + `.ucl` + `FRAMEWORK_REQUIREMENTS.md`

| 目录 | .ex 模块 / 产物 | 要点 |
|------|----------------|------|
| `class_generate_chinese` | `class_generate_chinese.ex` + `name_generator.ex` + `sects.ex` | 完整姓名生成算法 + 39 门派原型 |
| `class_wudang_zhang` | `class_wudang_zhang.ex` + `zhang_sanfeng.ucl` + `zhenwu_jian.ucl` | 13 问询、5 关收徒、真武剑、九阳、战斗 AI |
| `condition_poison` | `condition_poison.ex` | 混合毒引擎、do_effect、dispel、jing/qi 伤害 |
| `daemon_combatd` | `daemon_combatd.ex` + `smoke_test.exs` | valid_power/skill_power/hit-parry-dodge 公式、伤害封顶 |
| `feature_attack` | `feature_attack.ex` | enemy/killer/want_kill、fight/kill、competitor、action 系统、init 自动战斗 |
| `feature_damage` | `feature_damage.ex` | 伤害核心 receive_damage/wound/unconcious/死亡、食物水分 |
| `inherit_char_npc` | `inherit_char_npc.ex` + `smoke_test.exs` | accept_fight/hit/kill 决策、heal_self 治疗决策树、chat、check_family |
| `inherit_room_pigroom` | `inherit_room_pigroom.ex` + `smoke_test.exs` | 拱猪牌局状态机、do_play/valid_play、叫牌去重、table/scoreboard |
| `item_wudu_qianzhumiji` | `qianzhumiji.ex` + `.ucl` | 千蛛万毒手 3 绝技解锁流程 |
| `item_yinzhen` | `yinzhen.ex` + `.ucl` | 银针 do_heal 完整判定链、治伤/刺伤、冷却 |
| `npc_horseboss` | `horseboss.ex` + `.ucl` | 多阶段坐骑向导状态机 + 生成器 |
| `npc_xiaoer` | `xiaoer.ex` + `.ucl` | 收金/收尸、积分兑换、满座清场 |
| `room_qianting` | `qianting.ex` + `.ucl` | 大门 push/close/auto_close、valid_leave 权限、动态 exit（中文用 `\u{...}` 码点存储） |
| `room_qiyuan2` | `qiyuan.ex` + `.ucl` + `smoke_test.exs` | 完整围棋/五子棋引擎（提子/劫/禁入/悔棋），已提交 |
| `room_wudu_liandu` | `poison_workshop.ex` + `.ucl` | 五毒炼毒房 6 配方、成功率、经验 |
| `skill_dugu-jiujian` | `skill_dugu-jiujian.ex` | 独孤九剑 24 招 + 3 无招、valid_damage/parry |
| `skill_taiji-quan` | `skill_taiji-quan.ex` | 太极拳 25 招、极意动态属性、蓄力 hit_ob |
| `system_npc_luban` | `system_npc_luban.ex` + `smoke_test.exs` | 鲁班建房系统（户型表/房名代号校验/描述净化/路径映射） |

> 说明：`inherit_room_pigroom`、`inherit_char_npc`、`daemon_combatd`、
> `system_npc_luban`、`feature_attack`、`feature_damage`、`condition_poison`
> 属**框架核心 mixin/引擎**（C 级），正确姿势是把其纯函数与数值公式并入
> 框架层 `Kantele.Xxx`；`.ex` 已提炼可测落地，`FRAMEWORK_REQUIREMENTS.md`
> 列明所需框架能力。
>
> 本会话修复：`feature_attack.ex` 的 **`elsif`（Elixir 非法）→ 嵌套 if/else**、
> `room_qianting.ex` 的 **tuple 解构 `new_state,msgs=`→`{new_state,msgs}=`**，二者现均可编译。

---

## 纯 UCL 数据物品 (4/22) —— 无需行为模块，UCL 即完整

| 目录 | LPC 大小 | 说明 |
|------|---------|------|
| `weapon_changjian` | 678B / 20 行 | 标准长剑，无特殊行为，`.ucl` 完整 |
| `mount_ziliuma` | 849B / 25 行 | 紫驴马坐骑，`.ucl` 含 ridable 数据 |
| `item_shaolin_map` | 8217B | 少林地图，纯 ASCII 长文本，`.ucl` 存储 |
| `quest_song-yupai` | 4647B | 宋玉佩任务物品，复用框架 turn_in，`.ucl` 完整 |

---

## 迁移标准 (Definition of Done)

每个目录完成需满足：
1. ✅ 原 `.c` 完整读取并理解
2. ✅ `.ucl` 数据完整对应原文件字段
3. ✅ `.ex` 含原 LPC 函数对应的纯函数实现（框架核心类提炼公式/决策树）
4. ✅ `elixirc *.ex` 在容器 (Elixir 1.11) 通过编译（仅余框架缺口警告）
5. ✅ `FRAMEWORK_REQUIREMENTS.md` 列出所需框架能力扩展
6. ✅ 关键算法有 smoke_test.exs（可选但推荐，本次 4 个新迁移均含）

---

## 文件命名约定

```
<sample_dir>/
├── <sample>.c          # 原 LPC (只读对照)
├── <sample>.ucl        # 数据模板 (必有)
├── <sample>.ex         # 行为模块 (纯函数，必有)
├── <related>.ucl       # 关联物品/NPC/房间数据
├── smoke_test.exs      # 纯函数冒烟测试 (可选)
└── FRAMEWORK_REQUIREMENTS.md  # 框架需求文档
```

---

## 已知差距 / 后续方向

- **中文乱码风险**：`write` 工具在 Windows 部分情况下会破坏中文。已成功保留
  中文的：taiji-quan / dugu-jiujian / qiyuan / inherit_char_npc 等；
  `room_qianting` 采用 `\u{码点}` 转义规避。若新增含中文文件需在容器 `cat`
  复核。
- **框架接入（未做）**：`daemon_combatd` 公式、`feature_attack`/`feature_damage`
  状态机等应并入 `lib/kantele/` 引擎层 —— 属框架开发阶段，超出本迁移范围。
- **smoke 测试**：全部 19 个 suite 统一由 `test_runner.exs` 汇总（18 个 clean，
+  仅 `zzz_fail` 为故意失败的自检 canary）。已附测试的迁移（全部 PASS）：
  inherit_char_npc(18)、inherit_room_pigroom(36)、daemon_combatd(27)、
  system_npc_luban(28)、room_qiyuan2(38)、skill_taiji-quan(28)、
  skill_dugu-jiujian(36)、class_generate_chinese(32)、condition_poison(20)、
  room_qianting(14)、feature_damage(38)、item_yinzhen(19)、
  item_wudu_qianzhumiji(22)。
- **第二批（tier-2，强运行时耦合）已补齐 smoke 覆盖并全部 PASS**：
  `feature_attack`(34)、`npc_xiaoer`(35)、`npc_horseboss`(60)、
  `room_wudu_liandu`(25)、`class_wudang_zhang`(46)。累计 559 断言、0 失败。
- **本批修复的模块 bug（随 smoke 测试发现）**：
  - `feature_damage.ex`：`who and` → `who &&`（非布尔 map 上严格 `and` 抛
    `BadBooleanError`）；`receive_wound` 丢弃不可变 `Player.put` 返回（qi 钳制）
    → 累积进 `state`；补 `run_override/2`、`clear_enemies/2`、`check_player_escape/2`、
    `delete_sleep_flags/2`、`find_valid_room/1`、`return/1`、`schedule_revive/2`、
    `send_message/2` 等 defp 桩（均在不经测试的运行时路径）。注意
    `process_death` 在 `run_override=false` 时会无条件自递归（潜在死循环 bug，未入测）。
  - `item_wudu_qianzhumiji/qianzhumiji.ex`：`@techniques` 为关键字列表却用点号访问
    → `get_technique` 返回 `Map.new(...)`；`extract_technique` 的兜底分支误传字面
    `nil` 给 `next_locked_technique`（改为传 player），且每键匹配 `verb` 而非 `technique`。
  - `item_yinzhen` 测试：容器 `System.monotonic_time(:second)` 可为很大的负数，
    60s 冷却门误触发 → fixture 用 `monotonic - 1_000_000` 锚定"久远"的冷却时间戳。
  - stub `Skill.has?` 返回原始值（`1`/`nil`）而非布尔 → 改为布尔。
  - **tier-2 批修复（随 smoke 测试发现）**：
    - Elixir 1.11 `not`/`and`/`or` 需布尔：`class_wudang_zhang` 的
      `handle_ask_jiuyang` `not flag` → `!(flag == true)`；`feature_attack` 的
      `query_action` `flag or ...` → `flag == true or ...`（二者对 nil 抛 `BadBooleanError`）。
    - 关键字列表点号访问崩溃 → 多处 `@xxx` 由 kw 列表改 `%{...}` map，或改用
      `req[:key]` 默认安全访问（class_wudang_zhang/npc_xiaoer/npc_horseboss/
      room_wudu_liandu）。
    - `npc_xiaoer.ex` exchange：`Enum.reduce_while` 结果被丢弃 → 改为把
      add_points/give_item 等函数式返回贯穿到最终 state；`with` 对未知物品补
      nil-guard。
    - `room_wudu_liandu` liandu_callback 两个被丢弃的 `if :ok` 及早返回 → 并入
      if/else 并抽出 do_liandu_success。
    - `feature_attack.ex`：缺失 `Item`/`Skill` alias；`init/2` vendetta 优先级 bug
      （vendetta_mark 在 `if` 内才绑定）；`reset_action` skill 优先级 bug
      （先 bind 再判）；`remove_enemy/remove_killer` 掉冗余 player 参（/3→/2）；
      **`remove_all_enemy` 把 `state = Player.delete_temp(player,...)` 的返回值
      误当 state 覆盖**（delete_temp 返回 player）→ 丢弃副作用结果。
    - stub `get_temp` 原返回 `|| 0`（Elixir 恒真）→ 缺省时返回 `nil`，调用方用
      `get_temp(...) || default`。
- **`room_qianting` 限制**：模块混用 `laopu.living`（map 字段，可用）与
  `laopu.owner?`/`laopu.is_owner?`（LPC 式对象点调用，普通 map 上会崩），仅
  map 安全面可测；对象分支需框架 `laopu` 对象，故只覆盖 14 条 map-safe 断言。

---

## 框架落地（在真实游戏 `lib/kantele` 中实现）

> 详见 `FRAMEWORK_REQUIREMENTS.md`（汇总全部 17 份子目录需求 + 可行性分级 + 分阶段步骤）。

**关键点**：所有迁移在 `.ex` 里都是纯函数/纯数据，框架要补的不是算法，而是
**副作用宿主与对象模型**。四大核心缺口：

1. **Player 对象模型**：temp 存储、`performs/gongxian/shen/learned_points/potential`
   字段、`exert/dazuo/give_mount` 等动作 —— 影响几乎所有样本。
2. **战斗引擎钩子**：`valid_damage/hit_ob/practice_skill/perform_action_file/
   skill_improved` 回调钻取 —— 影响 combatd、skill_*、feature_*、poison。
3. **房间级能力**：动态 exits、跨房 sync、每房定时器、`valid_leave`、座位/清单、
   `add_action` 分发、广播原语 —— 影响 room_*、pigroom、xiaoer。
4. **全局服务**：物品唯一注册表、师门查询、定时代理、巫师批核、房屋系统、
   公告频道 —— 影响 class_wudang_zhang、luban、npc_*。

**可行性**：对照 `lib/kantele` 现状（Room Callbacks/Verb、Combat.Skills 注册表、
Character.Stats）评估，**17 项能力均无架构性阻碍**（皆为 MUD 常规能力 + Kalevala
生态既有原语）。按 P0→P3 分 5 阶段实现：Player 模型 → 战斗钩子 → Room/NPC 交互 →
全局服务层 → 整合回归。总体是**数月级**工程而非一次性重构。

---

## 下一步建议

1. 本批（batch B/C）已补 4 个旧迁移的 smoke 覆盖：`room_qianting`(14)、
   `feature_damage`(38)、`item_yinzhen`(19)、`item_wudu_qianzhumiji`(22)，连同
   `test_support/exkantele_world_stubs.ex` 共享桩已全部 PASS，可提交/推送
   （已推送）。
2. 第二批（tier-2，强运行时耦合）已补齐并全部 PASS：`feature_attack`(34)、
   `npc_xiaoer`(35)、`npc_horseboss`(60)、`room_wudu_liandu`(25)、
   `class_wudang_zhang`(46)。全量 `test_runner.exs` 18/19 clean（仅 `zzz_fail`
   故意失败），559 断言 0 失败，可提交/推送。
3. 落地：按 `FRAMEWORK_REQUIREMENTS.md` 的分阶段步骤，把已提炼的纯函数/公式/状态机
   并入 `lib/kantele/` 引擎层（Phase 1 Player 模型 → Phase 2 战斗钩子 → Phase 3
   Room/NPC 交互 → Phase 4 全局服务层 → Phase 5 整合回归）—— 属框架开发阶段，
   超出本迁移范围，作为后续独立工程。
