# Workspace Memory — wuxia_mud_ex (Elixir/Phoenix LPC MUD port)

## Iron rules
- 无 git commit/push 除非用户明确要求（2026-11-10 已授权「提交推送，然后继续推进」）。
- 改动前 Grep lib/test/docs + LPC 源 `/c/files/git/mud` 确认真缺口，不臆造语义。
- 不要升级 nimble_parsec。

## 阅读约定
- `.workbuddy-ai/memory/YYYY-MM-DD.md` 是按日追加的流水账，中间状态可被本文件「已完成」章节推翻。
- 唯一状态入口 = 本文件「已完成 / 净增量归档」+ `docs/待办对照代码核查.zh-CN.md` §三 / §6.2。

## 验证路径
- Docker 不可用（Windows Git Bash）：`PATH=/c/Users/honggang/tools/erl-25.3.2.6/bin:/c/Users/honggang/tools/elixir-1.13.4-otp25/bin:$PATH`；`MIX_HOME=/c/Users/honggang/tools/mix-1.13`；`MIX_BUILD_PATH=_build_win13`；`ERL_LIBS=_build_win13/lib`；`MIX_ENV=test`。
- `mix compile` / `mix test --seed 831693`（全量约 9-10 min，建议后台重定向日志）。
- 基线：7830 tests / 27 failures / 575.6s（全为 `bcrypt_elixir` NIF 环境性，引擎/命令/技能/世界测试 0 失败）。

## 关键约定 / 坑
- 路由：`parse/2` 裸路由只产 `%{"command"=>...}`；带参命令需 `optional(spaces() |> text(:rest|:target|:category))`。
- CommandProbe：扫描占位标记；白名单 `@whitelist %{}`（0 占位）。新命令回执不得含占位标记。
- daemon：GenServer 持 public ETS，写入直接 `:ets.insert`；`ensure!/0` 补建表；`read_state/0` 表缺失返缺省。
- 人格：字段 `meta.character`（非 personality）；玩家 nil ≡ LPC 0。
- `@static` 白名单 733 唯一 id，与 `.ex` 模块一致（0 缺失 0 extra）。
- suicide：`meta.password` 明文校验 + `Characters.delete_by_name/1`（rescue 降级）。
- 两条死亡管线：正常战斗击杀走 `CombatEvent.die/3`；`smash`/房间 `break` 走 `Feature.Damage.die/2` → `process_death/2`。公共尸体逻辑在 `Kantele.World.Corpse.spawn/1`。
- 物品缓存 key 是 `<zone>:<key>`；动态生成的 `Item.Instance` 要用完整 key。
- UCL 不能有单独一行的 `#`（空注释）。
- `is_player?/1` 认 `"player:"` 前缀；`receive_damage` 别传 killer。
- `zone.items` 缺 `:items` key 时抛 KeyError；改用 `Map.get(zone, :items, %{})`。
- `IO.write` 在 Windows 下对中文抛 `:no_translation`；改用 `File.write!/2` 追加。
- `Path.join/3` 不存在，用 `Path.join([...])`；`File.rm/2` 不存在，用 `File.rm!/1`。
- `String.to_integer/1` 返回裸整数，用 `is_integer()` 保护；`List.to_atom/1` 不接受字符串。

## 已完成（免后续重复核查）
- A1/A2/A4：已清零；e/g/h 期：用户确认已完成。
- A3/B5 Diff-stop：`kickoff.ex` `cleanup_stale_processes/1` 已真化，`handle_continue(:load)` 走 `safely/1`。
- B1 命令桩（22 个）：全部真实实现，无占位标记。
- B2 W3 arch 命令：12 个已落地；`build` 保留 `not_modeled`。
- B3 prepare/scheme/uptime/special/suicide/clone：全部完整实现。
- C 跨角色同步/饥饿口渴/门派学徒/门容器/一次性场景/通信中继载具：全部落地。
- O2 留言板；O3 门 v1；O4 food/water；O5 gift 先天赋值。
- T1 LPC→UCL 转换器 + 189 `.ucl`；T2 柳溪镇 34 文件对拍；T4 e2e 夹具。
- F4 武功迁移：@static 白名单 733；70 空壳 + 202 无招式已核实；R5 92 真缺口已全部迁移；valid_learn 322/322 全量迁移。
- 拱猪子系统：pig_room/pig_game/pig_table 均实装。
- 死亡→地府→还阳：combat_event.die/3 + revive/2 + niutou AskHandler + death.ucl，4 例测试全绿。
- 尸体/NPC 掉落系统：corpse.ex + drop_a/b/c + power，19/19 quarry NPC 已移植，14 例测试全绿。
- 猎人 NPC 教 hunting：hunter.ex AskHandler + hunting.ex valid_learn/2 + eat_command.ex raw_meat 门控，50 例全绿。
- 三项遗留待办（2026-11-15）：Set Grant as wizard / 世界位置文档 / 位置加到 goto 命令 — 全部结案。
- LPC 式随机鬼魂名字（2026-11-16）：`random_ghost_name/1` + death.ucl 18 NPC `random_name_type = "ghost"`，全量回归 7830 tests / 27 failures，0 新增失败。
- ask 黎生 五丁开山 / 绝命一踢（sect_master_grant）：inquiry_handler 注册 + UCL 配置，99 例测试 0 失败。
- 随机 NPC 名字生成（2026-11-16 已提交推送，commit 1c017236 + fa11948a）：`NameGenerator` 新增 `random_ghost_name/1`、`random_biaoshi_name/1`、`random_biaotou_name/1`；`loader.ex` `parse_character/4` case 匹配 `"ghost"`/`"cn"`/`"biaoshi"`/`"biaotou"`；`death.ucl` 18 HellZhen NPC `ghost`；`gaibang.ucl` 7 丐帮弟子 `cn`；`changan.ucl` 镖师 `biaoshi`、镖头 `biaotou`，总镖头 `万青山` 保留不变。
- AskCommand.find_ask_npc/2 前缀匹配修复（commit 3afb4171）：测试 9/9 全绿，全量 7830 tests / 27 failures（基线一致，0 回归）。
- LPC→UCL 教学数据补全（Tasks #613–#618）：10 个 NPC 的 `teach_skills`/`apprentice` 已回填；`inquiries` 已转为绝招授予；`docs/新手拜师门派指南.zh-CN.md` 已重写（12 个师父条目）。
- 柳溪派 `wangshifu`：无 LPC source 可供 `apprentice` 块数据，保留缺失，非代码缺口，无待办。
- sects.ex 门派原型按 LPC 对齐（commit 1416f7b1）：补全 18 个缺失门派，总数从 21 扩至 39，与 LPC `class_generate_chinese.c` init_family 完全对齐。
- 门派原型详细配置章节（commit 67da804d）：`docs/新手拜师门派指南.zh-CN.md` 新增第6节，列出全部 39 个门派的详细配置（class/scale/skills/maps/preps/carry）。

## 净增量归档（全部已完结，无待办）
- `docs/` 下 78 份文档 + 根目录 md 已全量扫描，59 份含待办标记的历史文档已加「📌 归档声明 · 全库待办清零」。
- `docs/待对照代码核查.zh-CN.md` §6.2 净增量表、§二、§三已标记 ✅ 已完结。

## 待办（当前）
- 写入 LPC 拜师实现与 UCL 配置对比（Section 7）到 `docs/新手拜师门派指南.zh-CN.md`，并 commit/push。
- 已知差异：张三丰 LPC 额外 `int>=32`（UCL 缺 `min_int`）；陈家洛 LPC 额外 `max_neili>=2000`（UCL 缺 `min_neili`）；苗人凤 LPC 无 shen/exp/skill 门槛（UCL 加了 `miaojia_neigong>=50`）；宋远桥 LPC 有完整 `attempt_apprentice` 但 UCL 尚未配置 `apprentice` 块；柳溪派 王重九 无 LPC source；俞莲舟 LPC 未核查。
